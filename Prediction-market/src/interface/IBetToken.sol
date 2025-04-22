// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IHighBetToken
 * @dev An interface for the HighBetToken contract.
 */

interface IBetToken {
    function mint(address to, uint256 amount) external;
    function MAX_SUPPLY() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function burn(address account, uint256 amount) external;
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}