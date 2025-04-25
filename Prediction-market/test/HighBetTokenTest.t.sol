// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BetTokens/HighBetToken.sol";

contract HighBetTokenTest is Test {
    HighBetToken token;
    address owner = address(1);
    address nonOwner = address(2);
    address minter = address(3);
    address user = address(4);

    function setUp() public {
        vm.prank(owner);
        token = new HighBetToken(owner);
    }

    function test_Constructor_Basic() public {
        assertEq(token.name(), "HighBet Token");
        assertEq(token.symbol(), "HIGHBET");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.minter(), address(0));
        assertEq(token.owner(), owner);
    }

    function test_SetMinter_Success() public {
        vm.prank(owner);
        token.setMinter(minter);
        assertEq(token.minter(), minter);
    }

    function test_SetMinter_Fail_NotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        token.setMinter(minter);
    }

    function test_SetMinter_Fail_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(
            bytes("HighBetToken: Minter cannot be the zero address")
        );
        token.setMinter(address(0));
    }

    function test_Mint_Success() public {
        uint256 mintAmount = 1000 ether;

        vm.prank(owner);
        token.setMinter(minter);

        vm.prank(minter);
        token.mint(user, mintAmount);

        assertEq(token.totalSupply(), mintAmount);
        assertEq(token.balanceOf(user), mintAmount);
    }

    function test_Mint_Fail_NotMinter() public {
        uint256 mintAmount = 1000 ether;
        vm.prank(owner);
        token.setMinter(minter);

        vm.expectRevert("HighBetToken: Caller is not the authorized minter");
        vm.prank(nonOwner);
        token.mint(user, mintAmount);
    }

    function test_Mint_Fail_MaxSupplyExceeded() public {
        address testminter = address(0x123);
        vm.prank(owner);
        token.setMinter(testminter);

        uint256 maxSupply = token.MAX_SUPPLY(); // move it out of the prank context

        vm.prank(testminter);
        token.mint(user, maxSupply); // this will now be correct

        vm.prank(testminter);
        vm.expectRevert("HighBetToken: Minting exceeds maximum supply");
        token.mint(user, 1);
    }
}
