// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/ERC69Errors.sol";

/// @title ERC69_721
/// @notice ERC69_721 is a novel token standard combining the flexibility of ERC721 NFTs with 
///         unique wrapping and unwrapping mechanisms. This contract introduces a 
///         seamless way to wrap ERC20 tokens into ERC721 NFTs, allowing for unique 
///         asset management and liquidity options.
///
///         Designed for versatility and efficiency, ERC69_721 aims to facilitate 
///         new forms of token interactions while maintaining compatibility with 
///         existing ERC standards.
///
/// @dev    This implementation assumes certain behaviors for wrapping and unwrapping 
///         tokens, leveraging ERC721's uniqueness for asset representation.
///         It introduces mechanisms such as timed unwraps and dynamic supply 
///         management, with safeguards to ensure user transactions are processed 
///         accurately and securely.
///
///         The contract utilizes a deposit system, where ERC20 tokens can be 
///         wrapped into ERC721 tokens, creating a new layer of value transfer 
///         and interaction within the Ethereum ecosystem.
///
/// @author TG: @the_inglourious_basterd
///         Feel free to reach out with questions, suggestions, or collaborations.
///
/// @custom:experimental This is an experimental contract and is not audited.
abstract contract ERC69_721 is
    ERC69Errors,
    ERC721,
    ERC721Holder,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;
    IERC20 private _erc20Token; // deposit token

    mapping(address => uint256) private _lastUnwrapTimestamp; // 5 minutes
    mapping(address => uint256[]) private _tokenIds; // user address => token ids

    string public baseURI;

    uint256 private _maxSupply; // max supply of MFTs
    uint256 private _tokenAmount; // amount of deposit token to wrap
    uint256 private _totalSupply; // total supply of MFTs

    event Unwrap(address indexed sender, uint256[] tokenIds);
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
    ) ERC721(name_, symbol_) {
        baseURI = baseURI_;

        _erc20Token = IERC20(erc20Token_);
        _tokenAmount = tokenAmount_;
        _maxSupply = maxSupply_;
        _mint(address(this), 0);
        _tokenIds[address(this)].push(0);
        _totalSupply = 1;
    }

    /**
     * @dev Returns the address of the deposit token
     */
    function erc20Token() public view returns (address) {
        return address(_erc20Token);
    }

    /**
     * @dev Returns the max supply of MFTs
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns the amount of deposit token to wrap
     */
    function tokenAmount() public view returns (uint256) {
        return _tokenAmount;
    }

    /**
     * @dev Returns the total supply of MFTs
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the token ids of the user
     *
     * @param user_  address of the user
     */
    function getUserTokenIds(
        address user_
    ) public view virtual returns (uint256[] memory) {
        return _tokenIds[user_];
    }

    /**
     * @dev Unwraps the MFTs
     *
     * @param tokenIds_  array of token ids to unwrap
     */
    function unwrap(uint256[] calldata tokenIds_) public virtual {
        if (tokenIds_.length == 0) revert UnwrapZeroAmount();
        if (block.timestamp - _lastUnwrapTimestamp[msg.sender] < 5 minutes)
            revert WaitBeforeUnwrappingAgain();
        _lastUnwrapTimestamp[msg.sender] = block.timestamp;
        // check if user has enough MFTs to unwrap
        uint256 _count = tokenIds_.length;
        for (uint256 x; x < _count; ) {
            safeTransferFrom(msg.sender, address(this), tokenIds_[x]);
            unchecked {
                ++x;
            }
        }
        _erc20Token.transfer(msg.sender, _tokenAmount * _count);
        emit Unwrap(msg.sender, tokenIds_);
    }

    /**
     * @dev Wraps the deposit token
     *
     * @param amount_  amount of deposit token to wrap
     */
    function wrap(uint256 amount_) public virtual {
        if (amount_ == 0) revert WrapZeroAmount();
        //check max supply
        if (_totalSupply + amount_ > _maxSupply) revert ExceedsMaxSupply();
        _erc20Token.transferFrom(
            msg.sender,
            address(this),
            amount_ * _tokenAmount
        );

        // iterate over amount and pop the last token id from tokenIds array and send to sender
        uint256[] storage userTokenIds = _tokenIds[msg.sender];
        uint256[] storage contractTokenIds = _tokenIds[address(this)];
        for (uint256 x; x < amount_; ) {
            uint256 tokenId;
            if (contractTokenIds.length == 0) {
                // check max supply
                if (_totalSupply + 1 > _maxSupply) revert ExceedsMaxSupply();
                // mint new token
                tokenId = _totalSupply;
                _mint(msg.sender, tokenId);
                ++_totalSupply;
                userTokenIds.push(tokenId);
            } else {
                // send last token in tokenIds array to sender
                tokenId = contractTokenIds[contractTokenIds.length - 1];
                contractTokenIds.pop();
                _safeTransfer(address(this), msg.sender, tokenId, "");
            }

            unchecked {
                ++x;
            }
        }

        emit Wrap(msg.sender, amount_);
    }

    /**
     * @dev Sets the base URI
     *
     * @param newURI_  new base URI
     */
    function setURI(string memory newURI_) public virtual onlyOwner {
        baseURI = newURI_;
    }

    /**
     * @dev Returns the URI
     *
     * @param interfaceId_ interface id
     */
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC721) returns (bool) {
        return
            interfaceId_ == type(IERC721).interfaceId ||
            interfaceId_ == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId_);
    }

    /**
     * @dev Returns the URI
     *
     * @param tokenId_  token id
     */
    function tokenURI(
        uint256 tokenId_
    ) public view override returns (string memory) {
        if (_exists(tokenId_)) revert InvalidTokenId();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId_.toString()))
                : "";
    }

    /**
     * @dev Internal function to transfer a specific token
     *
     * @param from_  address of the sender
     * @param to_  address of the receiver
     * @param tokenId_  token id
     */
    function _transfer(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal override {
        super._transfer(from_, to_, tokenId_);
        // update tokenIds array for sender and receiver
        if (from_ != address(0)) {
            uint256[] storage fromTokenIds = _tokenIds[from_];
            uint256 fcounter = fromTokenIds.length;
            for (uint256 i; i < fcounter; ) {
                if (fromTokenIds[i] == tokenId_) {
                    fromTokenIds[i] = fromTokenIds[fcounter - 1];
                    fromTokenIds.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }
        if (to_ != address(0)) {
            _tokenIds[to_].push(tokenId_);
        }
    }
}
