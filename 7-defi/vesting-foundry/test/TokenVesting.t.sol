// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenVestingTest is Test {
    uint256 private constant TOTAL = 1_000_000;
    uint256 private constant MONTH = 30 days;

    MockERC20 private token;
    TokenVesting private vesting;
    address private beneficiary;

    function setUp() public {
        token = new MockERC20();
        beneficiary = address(0xBEEF);

        token.mint(address(this), TOTAL);

        address futureVesting = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        token.approve(futureVesting, TOTAL);

        vesting = new TokenVesting(IERC20(address(token)), beneficiary, TOTAL);
    }

    function testDeploymentLocksTokens() public view {
        assertEq(token.balanceOf(address(vesting)), TOTAL);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testCannotReleaseBeforeCliff() public {
        vm.warp(vesting.cliffTimestamp() - 1);
        vm.expectRevert("cliff not reached");
        vesting.release();
    }

    function testFuzzCannotReleaseBeforeCliff(uint256 delta) public {
        uint256 maxDelta = vesting.cliffTimestamp() - vesting.startTimestamp();
        delta = bound(delta, 1, maxDelta);
        vm.warp(vesting.cliffTimestamp() - delta);
        vm.expectRevert("cliff not reached");
        vesting.release();
    }

    function testReleaseAfterFirstMonth() public {
        vm.warp(vesting.cliffTimestamp() + MONTH);

        vesting.release();

        uint256 expected = TOTAL / 24;
        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(), expected);
    }

    function testReleaseAccumulatesOverTime() public {
        vm.warp(vesting.cliffTimestamp() + MONTH);
        vesting.release();

        vm.warp(vesting.cliffTimestamp() + 3 * MONTH);
        vesting.release();

        uint256 expected = (TOTAL * 3) / 24;
        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(), expected);
    }

    function testReleaseCanBeTriggeredByAnyone() public {
        vm.warp(vesting.cliffTimestamp() + MONTH);

        address caller = address(0xCA11);
        vm.prank(caller);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL / 24);
    }

    function testFuzzReleaseExactMonth(uint256 monthsElapsed) public {
        monthsElapsed = bound(monthsElapsed, 1, 24);
        vm.warp(vesting.cliffTimestamp() + monthsElapsed * MONTH);

        vesting.release();

        uint256 expected = (TOTAL * monthsElapsed) / 24;
        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(), expected);
    }

    function testReleaseAfterScheduleCompletes() public {
        vm.warp(vesting.vestingEndTimestamp());
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL);
        assertEq(vesting.released(), TOTAL);
    }
}
