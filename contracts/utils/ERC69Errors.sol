// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

abstract contract ERC69Errors {
    error ExceedsMaxSupply();
    error InsufficientMFTsToWrap();
    error InvalidTokenId();
    error UnwrapZeroAmount();
    error WaitBeforeUnwrappingAgain();
    error WrapZeroAmount();
}
