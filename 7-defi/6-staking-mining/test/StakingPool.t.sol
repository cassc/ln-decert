// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StakingPool, IToken, ILendingProvider} from "../src/StakingPool.sol";

contract MockToken is IToken {
    string public constant name = "KK Token";
    string public constant symbol = "KK";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    function mint(address to, uint256 amount) external override {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockLendingProvider is ILendingProvider {
    address public immutable pool;
    uint256 public totalManaged;

    error Unauthorized();

        constructor(address pool_) {
            pool = pool_;
        }

        receive() external payable {
            totalManaged += msg.value;
        }

        function deposit() external payable override {
            if (msg.sender != pool) revert Unauthorized();
            totalManaged += msg.value;
        }

        function withdraw(address recipient, uint256 amount) external override returns (uint256) {
            if (msg.sender != pool) revert Unauthorized();
            if (amount > totalManaged) {
                amount = totalManaged;
            }

            totalManaged -= amount;

            (bool success,) = recipient.call{value: amount}("");
            require(success, "transfer failed");
            return amount;
        }

        function donateYield(uint256 amount) external payable {
            require(msg.value == amount, "mismatch");
            (bool success,) = pool.call{value: amount}("");
            require(success, "yield transfer failed");
        }
    }

contract ReentrantLendingProvider is ILendingProvider {
    enum Action {
        None,
        Claim
    }

    StakingPool public immutable pool;
    Action public action;

    constructor(StakingPool pool_) {
        pool = pool_;
    }

    function setAction(Action action_) external {
        action = action_;
    }

    receive() external payable {}

    function deposit() external payable override {
        if (msg.sender != address(pool)) revert("not pool");

        // mimic a malicious lending adapter that re-enters during the callback
        if (action == Action.Claim) {
            pool.claim();
        }
    }

        function withdraw(address recipient, uint256 amount) external override returns (uint256) {
            if (msg.sender != address(pool)) revert("not pool");

            uint256 balance = address(this).balance;
            if (amount > balance) {
                amount = balance;
            }

            (bool success,) = recipient.call{value: amount}("");
            require(success, "reentrant withdraw failed");
            return amount;
        }
    }

    contract StakingPoolTest is Test {
        MockToken internal rewardToken;
        StakingPool internal pool;
        address internal alice = address(0xA11CE);
        address internal bob = address(0xB0B);

        function setUp() public {
            rewardToken = new MockToken();
            pool = new StakingPool(rewardToken);

            vm.deal(alice, 100 ether);
            vm.deal(bob, 100 ether);
        }

        function testStakeIncreasesBalance() public {
            vm.prank(alice);
            pool.stake{value: 2 ether}();

            assertEq(pool.balanceOf(alice), 2 ether, "balance mismatch");
            assertEq(pool.totalStaked(), 2 ether, "total staked mismatch");
        }

        function testEarnedSingleStaker() public {
            vm.prank(alice);
            pool.stake{value: 1 ether}();

            vm.roll(block.number + 7);

            uint256 expected = 7 * pool.REWARD_PER_BLOCK();
            assertEq(pool.earned(alice), expected, "unexpected pending reward");
        }

        function testRewardsDistributedFairlyBetweenStakers() public {
            vm.prank(alice);
            pool.stake{value: 1 ether}();

            vm.roll(block.number + 3);

            vm.prank(bob);
            pool.stake{value: 3 ether}();

            uint256 initialWindow = 3 * pool.REWARD_PER_BLOCK();
            assertEq(pool.earned(alice), initialWindow, "alice rewards before second window");

            vm.roll(block.number + 5);

            uint256 sharedWindow = (5 * pool.REWARD_PER_BLOCK() * 1 ether) / 4 ether;
            uint256 expectedAlice = initialWindow + sharedWindow;
            uint256 expectedBob = (5 * pool.REWARD_PER_BLOCK() * 3 ether) / 4 ether;

            assertEq(pool.earned(alice), expectedAlice, "alice rewards mismatch");
            assertEq(pool.earned(bob), expectedBob, "bob rewards mismatch");
        }

        function testClaimMintsRewards() public {
            vm.prank(alice);
            pool.stake{value: 1 ether}();

            vm.roll(block.number + 10);

            vm.prank(alice);
            pool.claim();

            uint256 expected = 10 * pool.REWARD_PER_BLOCK();
            assertEq(rewardToken.balanceOf(alice), expected, "reward token balance mismatch");
            assertEq(pool.earned(alice), 0, "pending reward not cleared");
        }

        function testUnstakeReturnsPrincipal() public {
            vm.prank(alice);
            pool.stake{value: 2 ether}();

            uint256 aliceBalanceAfterStake = alice.balance;
            assertEq(aliceBalanceAfterStake, 98 ether, "stake not deducted");

            vm.prank(alice);
            pool.unstake(1 ether);

            assertEq(pool.balanceOf(alice), 1 ether, "remaining stake incorrect");
            assertEq(alice.balance, 99 ether, "unstake payout mismatch");

            vm.prank(alice);
            pool.unstake(1 ether);

            assertEq(pool.balanceOf(alice), 0, "final stake not zero");
            assertEq(alice.balance, 100 ether, "final ether balance mismatch");
        }

    function testStakeAndUnstakeWithLendingProvider() public {
        MockLendingProvider provider = new MockLendingProvider(address(pool));
        pool.setLendingProvider(address(provider));

        vm.prank(alice);
            pool.stake{value: 5 ether}();

            assertEq(address(pool).balance, 0, "pool should forward funds");
            assertEq(provider.totalManaged(), 5 ether, "provider balance mismatch");

            vm.roll(block.number + 4);

            vm.prank(alice);
            pool.unstake(3 ether);

            assertEq(provider.totalManaged(), 2 ether, "provider should release funds");
            assertEq(alice.balance, 98 ether, "alice should receive withdrawn principal");
    }

    function testReentrancyGuardBlocksLendingCallback() public {
        ReentrantLendingProvider provider = new ReentrantLendingProvider(pool);
        pool.setLendingProvider(address(provider));
        // trigger the malicious claim during stake -> deposit callback
        provider.setAction(ReentrantLendingProvider.Action.Claim);

        vm.startPrank(alice);
        vm.expectRevert(StakingPool.Reentrancy.selector);
        pool.stake{value: 1 ether}();
            vm.stopPrank();
        }

        function testOwnerCanPauseAndUnpause() public {
            pool.pause();
            assertTrue(pool.paused(), "pool should be paused");

            pool.unpause();
            assertFalse(pool.paused(), "pool should be unpaused");
        }

        function testNonOwnerCannotPause() public {
            vm.prank(alice);
            vm.expectRevert(StakingPool.Unauthorized.selector);
            pool.pause();
        }

        function testStakeBlockedWhenPaused() public {
            pool.pause();

            vm.startPrank(alice);
            vm.expectRevert(StakingPool.PausedError.selector);
            pool.stake{value: 1 ether}();
            vm.stopPrank();
        }

        function testUnstakeBlockedWhenPaused() public {
            vm.prank(alice);
            pool.stake{value: 2 ether}();

            pool.pause();

            vm.prank(alice);
            vm.expectRevert(StakingPool.PausedError.selector);
            pool.unstake(1 ether);
        }

        function testClaimBlockedWhenPaused() public {
            vm.prank(alice);
            pool.stake{value: 1 ether}();

            vm.roll(block.number + 3);

            pool.pause();

            vm.prank(alice);
            vm.expectRevert(StakingPool.PausedError.selector);
            pool.claim();
        }

        function testUnpauseRestoresFunctionality() public {
            vm.prank(alice);
            pool.stake{value: 1 ether}();

            pool.pause();
            pool.unpause();

            vm.prank(alice);
            pool.unstake(1 ether);

            assertEq(pool.balanceOf(alice), 0, "unstake should succeed after unpause");
        }
    }
