// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IBetToken} from "../src/interface/IBetToken.sol"; // Assuming this interface exists
import {BaseBetToken} from "../src/BetTokens/BaseBetToken.sol"; // Adjust path if needed
import {stdError} from "forge-std/StdError.sol";

contract BaseBetTokenTest is Test {
    BaseBetToken public baseToken;
    address public deployer; // Define a deployer address (used for deploying the token)
    address public user1 = address(0x101); // A test user
    uint256 public constant MAX_SUPPLY = 1000 ether; // Example max supply
    // Define the specific minter address that the contract uses
    address public minter = 0x14650D0420cFf23c5d9300Db8483aDD0D6feb2a1;

    function setUp() public {
        // Set the deployer address (used for deploying the token)
        deployer = makeAddr("Deployer");
        vm.label(deployer, "Deployer");
        vm.label(user1, "User1");
        // Label the actual minter address for clarity in traces
        vm.label(minter, "Minter");

        // Deploy the BaseBetToken, passing the designated minter address
        // We prank as the deployer to simulate deployment, but the minter is set via constructor arg
        vm.startPrank(deployer);
        // Assuming BaseBetToken constructor takes name, symbol, max supply, and minter
        baseToken = new BaseBetToken("BaseBet", "BBT", MAX_SUPPLY, minter);
        vm.stopPrank(); // Stop pranking after deployment
    }

    // Test that minting tokens works successfully within the supply limit
    function test_Mint_Success_Basic() public {
        uint256 mintAmount = 100 ether;

        // Use vm.prank to call mint from the CORRECT minter's address
        vm.prank(minter); // <-- Prank as the actual minter address
        baseToken.mint(user1, mintAmount);

        // Assert user1's balance is the minted amount
        assertEq(
            baseToken.balanceOf(user1),
            mintAmount,
            "User1 balance incorrect after mint"
        );
        // Assert total supply increased by the minted amount
        assertEq(
            baseToken.totalSupply(),
            mintAmount,
            "Total supply incorrect after mint"
        );
    }

    // Test that minting tokens fails if it exceeds the maximum supply
    function test_Mint_Fail_MaxSupply_Basic() public {
        uint256 mintAmount1 = MAX_SUPPLY / 2;
        uint256 mintAmount2 = MAX_SUPPLY / 2;
        uint256 mintAmount3 = 1; // Amount that will exceed max supply

        // Use vm.prank to call mint from the CORRECT minter's address
        vm.prank(minter); // <-- Prank as the actual minter address
        baseToken.mint(user1, mintAmount1);

        vm.prank(minter); // <-- Prank as the actual minter address again
        baseToken.mint(user1, mintAmount2);

        // Assert total supply is at the limit
        assertEq(
            baseToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should be at max supply limit"
        );

        // Use vm.startPrank/stopPrank for the failing mint attempt from the CORRECT minter
        vm.startPrank(minter); // <-- Prank as the actual minter address
        // Attempt to mint one more token, which should revert
        // CORRECTED: Expect the actual revert message from your contract
        vm.expectRevert("Max supply reached"); // <-- Changed the expected revert message
        // If your contract uses a custom error for max supply, use vm.expectRevert(YourMaxSupplyError.selector);
        baseToken.mint(user1, mintAmount3);
        vm.stopPrank();

        // Assert total supply remains unchanged
        assertEq(
            baseToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not change after failed mint"
        );
    }
}
