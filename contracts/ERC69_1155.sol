// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/ERC69Errors.sol";

/// @notice ERC69_1155
///         An innovative token standard that extends ERC1155 for enhanced flexibility,
///         incorporating unique mechanisms for wrapping and unwrapping ERC20 tokens.
///         This approach enables a unified management of fungible and non-fungible tokens (NFTs),
///         with provisions for asset liquidity and innovative token interactions.
///
///         This standard is crafted to support a wide range of use cases, including but not limited to,
///         digital assets, gaming items, and collectibles, facilitating seamless exchanges between
///         ERC20 and ERC1155 tokens.
///
/// @dev    The contract introduces a novel approach to token wrapping, allowing users to convert
///         ERC20 tokens into ERC1155 tokens. This mechanism is designed with an emphasis on security,
///         efficiency, and user experience, incorporating features such as timed unwraps and a dynamic
///         token supply management system.
///
///         It is important to note that this contract assumes the existence of an ERC20 token for the
///         wrapping process and utilizes a specific token (identified by MFT) for representing wrapped assets.
///         Users are encouraged to review the contract's assumptions and limitations as part of their
///         integration process.
///
/// @author Created by TG: @the_inglourious_basterd
///         Feel free to reach out with questions, suggestions, or collaborations.
///
abstract contract ERC69_1155 is
    ERC69Errors,
    ERC1155,
    ERC1155Holder,
    Ownable,
    ReentrancyGuard
{
    IERC20 public _erc20Token;

    mapping(address => uint256) private _lastUnwrapTimestamp;

    string private _name;
    string private _symbol;
    string private _baseURI;

    uint256 private constant MFT = 1;
    uint256 private tokenAmount;

    event Unwrap(address indexed sender, uint256 amount);
    event Wrap(address indexed sender, uint256 amount);

    /**
     * @dev Sets the values for {name_}, {symbol_}, {baseURI_}, {erc20Token_}, {tokenAmount_}, and {maxSupply_}
     * 
     * @param name_  immutable name of the token
     * @param symbol_  immutable symbol of the token
     * @param baseURI_  base URI for the token
     * @param erc20Token_  address of the deposit token
     * @param tokenAmount_  amount of deposit token to wrap
     * @param maxSupply_  max supply of MFTs
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address erc20Token_,
        uint256 tokenAmount_,
        uint256 maxSupply_
    ) ERC1155("") {
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;

        _erc20Token = IERC20(erc20Token_);
        tokenAmount = tokenAmount_;
        _mint(address(this), MFT, maxSupply_, "");
    }

    /**
     * @dev Returns the name of the token
     *
     * @param amount_ amount of tokens to unwrap
     */
    function unwrap(uint256 amount_) public virtual nonReentrant {
        if (amount_ == 0) revert UnwrapZeroAmount();
        if (block.timestamp - _lastUnwrapTimestamp[msg.sender] < 5 minutes)
            revert WaitBeforeUnwrappingAgain();
        _lastUnwrapTimestamp[msg.sender] = block.timestamp;

        safeTransferFrom(msg.sender, address(this), MFT, amount_, "");
        _erc20Token.transfer(msg.sender, tokenAmount * amount_);
        emit Unwrap(msg.sender, amount_);
    }

    /**
     * @dev Returns the address of the deposit token
     *
     * @param amount_ amount of tokens to wrap
     */
    function wrap(uint256 amount_) public virtual nonReentrant {
        if (amount_ == 0) revert WrapZeroAmount();
        if (amount_ > balanceOf(address(this), MFT))
            revert InsufficientMFTsToWrap();
        _erc20Token.transferFrom(
            msg.sender,
            address(this),
            amount_ * tokenAmount
        );
        _safeTransferFrom(address(this), msg.sender, MFT, amount_, "");
        emit Wrap(msg.sender, amount_);
    }

    /**
     * @dev Returns the name of the token
     *
     * @param tokenId_ token id
     */
    function uri(
        uint256 tokenId_
    ) public view override returns (string memory) {
        return _baseURI;
    }

    /**
     * @dev Sets the base URI
     * 
     * @param newURI_  new base URI
     */
    function setURI(string memory newURI_) public virtual onlyOwner {
        _baseURI = newURI_;
    }

    /**
     * @dev Returns the URI
     * 
     * @param interfaceId_ interface id
     */
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC1155, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId_);
    }
}
