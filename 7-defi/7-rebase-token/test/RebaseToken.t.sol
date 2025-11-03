// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private token;
    address private deployer = address(this);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        token = new RebaseToken(alice);
    }

    function testInitialState() public view {
        assertEq(token.owner(), deployer, "owner");
        assertEq(token.totalSupply(), 100_000_000 * 1e18, "supply");
        assertEq(token.balanceOf(alice), 100_000_000 * 1e18, "alice balance");
        assertEq(token.balanceOf(bob), 0, "bob balance");
        assertGt(token.lastRebaseTimestamp(), 0, "timestamp");
        assertEq(token.rebaseCount(), 0, "rebase count");
    }

    function testTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 1e18);

        assertEq(token.balanceOf(bob), 1e18);
        assertEq(token.balanceOf(alice), 100_000_000 * 1e18 - 1e18);
    }

    function testApproveAndTransferFrom() public {
        vm.prank(alice);
        token.approve(bob, 5e18);

        vm.prank(bob);
        token.transferFrom(alice, bob, 2e18);

        assertEq(token.balanceOf(bob), 2e18);
        assertEq(token.allowance(alice, bob), 3e18);
    }

    function testRebaseReducesSupply() public {
        vm.warp(token.lastRebaseTimestamp() + 365 days + 1);
        uint256 newSupply = token.rebase();

        uint256 expected = (100_000_000 * 1e18 * 99) / 100;
        assertEq(newSupply, expected, "supply after rebase");
        assertEq(token.totalSupply(), expected, "total supply stored");
        assertEq(token.balanceOf(alice), expected, "alice balance");
        assertEq(token.rebaseCount(), 1, "rebase count");
    }

    function testRebaseTooSoon() public {
        vm.expectRevert("RebaseToken: rebase too soon");
        token.rebase();
    }

    function testMultipleRebases() public {
        vm.warp(token.lastRebaseTimestamp() + 365 days + 1);
        token.rebase();

        vm.warp(block.timestamp + 365 days + 1);
        token.rebase();

        uint256 expected = (100_000_000 * 1e18 * 99 * 99) / (100 * 100);
        assertEq(token.totalSupply(), expected);
        assertEq(token.balanceOf(alice), expected);
        assertEq(token.rebaseCount(), 2);
    }

    function testTransferAfterRebase() public {
        vm.warp(token.lastRebaseTimestamp() + 365 days + 1);
        token.rebase();

        vm.prank(alice);
        token.transfer(bob, 1e18);

        uint256 expectedSupply = (100_000_000 * 1e18 * 99) / 100;
        assertEq(token.balanceOf(bob), 1e18);
        assertEq(token.balanceOf(alice), expectedSupply - 1e18);
    }

    function testSweepAfterRebase() public {
        vm.warp(token.lastRebaseTimestamp() + 365 days + 1);
        token.rebase();

        vm.startPrank(alice);
        uint256 fullBalance = token.balanceOf(alice);
        token.transfer(bob, fullBalance);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), fullBalance);
    }
}
