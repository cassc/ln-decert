// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {OptionToken} from "../src/OptionToken.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockStablecoin is ERC20 {
    constructor() ERC20("Mock USD", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockPool {
    receive() external payable {}
}

contract OptionTokenTest is Test {
    OptionToken internal option;
    MockStablecoin internal strikeAsset;

    address internal owner;
    address internal alice;
    address internal treasury;

    uint64 internal expiry;
    uint64 internal constant EXERCISE_WINDOW = 1 days;
    uint256 internal constant STRIKE_PRICE = 2_000 ether;

    function setUp() public {
        strikeAsset = new MockStablecoin();

        owner = makeAddr("owner");
        alice = makeAddr("alice");
        treasury = makeAddr("treasury");

        expiry = uint64(block.timestamp + 7 days);

        vm.deal(owner, 100 ether);
        vm.deal(alice, 10 ether);

        option =
            new OptionToken("ETH Call 2000", "ocETH-2000", owner, strikeAsset, STRIKE_PRICE, expiry, EXERCISE_WINDOW);
    }

    function _mintCollateral(uint256 amount, address to) internal {
        vm.prank(owner);
        option.mintOptions{value: amount}(to);
        emit log_named_decimal_uint("Minted CALL option to alice", amount, 18);
    }

    /// @notice 测试所有者铸造期权时锁定抵押品
    function testOwnerMintLocksCollateral() public {
        uint256 amount = 1 ether;
        // 所有者铸造期权，将ETH作为抵押品发送给合约
        _mintCollateral(amount, alice);
        console2.log("=== Mint log ===");
        console2.log("owner", owner);
        console2.log("receiver", alice);
        emit log_named_decimal_uint("collateral", amount, 18);
        emit log_named_decimal_uint("contract balance", address(option).balance, 18);
        emit log_named_decimal_uint("alice options", option.balanceOf(alice), 18);

        // 验证alice收到了相应数量的期权代币
        assertEq(option.balanceOf(alice), amount);
        // 验证合约锁定了相应数量的ETH作为抵押品
        assertEq(address(option).balance, amount);
    }

    /// @notice 测试非所有者无法铸造期权代币
    function testNonOwnerCannotMint() public {
        // 给alice发送1 ETH
        vm.deal(alice, 1 ether);
        // 期望交易回滚，并返回"未授权账户"错误
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        // alice尝试铸造期权（应该失败，因为不是所有者）
        vm.prank(alice);
        option.mintOptions{value: 1 ether}(alice);
    }

    /// @notice 测试在到期前无法行权
    function testCannotExerciseBeforeExpiry() public {
        uint256 amount = 1 ether;
        // 铸造1个期权代币给alice
        _mintCollateral(amount, alice);

        // 给alice铸造行权资产（稳定币）
        strikeAsset.mint(alice, amount);

        // alice授权合约使用她的行权资产
        vm.prank(alice);
        strikeAsset.approve(address(option), amount);

        // 期望交易回滚，因为行权窗口还未开启（未到期）
        vm.expectRevert(OptionToken.ExerciseWindowNotOpened.selector);
        // alice尝试行权（应该失败）
        vm.prank(alice);
        option.exercise(amount, alice);
    }

    /// @notice 测试在行权窗口内行权会销毁代币并支付抵押品
    function testExerciseWithinWindowBurnsTokensAndPaysOutCollateral() public {
        uint256 amount = 1 ether;
        // 铸造1个期权代币给alice
        _mintCollateral(amount, alice);

        // 计算行权成本：1 ETH * 2000 = 2000 稳定币
        uint256 strikeCost = (amount * STRIKE_PRICE) / 1e18;
        // 给alice铸造足够的行权资产
        strikeAsset.mint(alice, strikeCost);

        // 将时间推进到到期后1秒（进入行权窗口）
        vm.warp(expiry + 1);
        vm.deal(alice, 1 ether); 

        console2.log("=== Before exercising the option ===");
        console2.log("timestamp", block.timestamp);
        emit log_named_decimal_uint("alice ETH balance", alice.balance, 18);
        emit log_named_decimal_uint("alice USDC balance", strikeAsset.balanceOf(alice), 18);
        emit log_named_decimal_uint("alice owned options", option.balanceOf(alice), 18);
        emit log_named_decimal_uint("strike cost", strikeCost, 18);

        // alice授权合约使用她的行权资产
        vm.prank(alice);
        strikeAsset.approve(address(option), strikeCost);

        // 验证期权尚未完全过期（仍在行权窗口内）
        assertFalse(option.expired());
        // alice行权：支付2000稳定币，获得1 ETH
        vm.prank(alice);
        uint256 paid = option.exercise(amount, alice);
        console2.log("=== After exercising the option ===");
        emit log_named_decimal_uint("USDC paid for the strike", paid, 18);
        emit log_named_decimal_uint("alice owned options", option.balanceOf(alice), 18);
        emit log_named_decimal_uint("contract ETH", address(option).balance, 18);
        emit log_named_decimal_uint("contract USDC", strikeAsset.balanceOf(address(option)), 18);
        emit log_named_decimal_uint("total exercised options", option.totalExercised(), 18);
        emit log_named_decimal_uint("total USDC collected", option.totalStrikeCollected(), 18);

        // 验证支付的金额正确
        assertEq(paid, strikeCost);
        // 验证alice的期权代币已被销毁
        assertEq(option.balanceOf(alice), 0);
        // 验证合约的ETH抵押品已支付给alice
        assertEq(address(option).balance, 0);
        // 验证合约收到了行权资产（稳定币）
        assertEq(strikeAsset.balanceOf(address(option)), strikeCost);
        // 验证总行权数量统计正确
        assertEq(option.totalExercised(), amount);
        // 验证总收集的行权资产统计正确
        assertEq(option.totalStrikeCollected(), strikeCost);
    }

    /// @notice 测试行权窗口关闭后行权失败
    function testExerciseAfterWindowFails() public {
        uint256 amount = 1 ether;
        // 铸造期权代币
        _mintCollateral(amount, alice);

        // 计算行权成本
        uint256 strikeCost = (amount * STRIKE_PRICE) / 1e18;
        strikeAsset.mint(alice, strikeCost);

        // 将时间推进到行权窗口关闭后（到期时间 + 行权窗口 + 1秒）
        vm.warp(expiry + EXERCISE_WINDOW + 1);

        // alice授权合约使用行权资产
        vm.prank(alice);
        strikeAsset.approve(address(option), strikeCost);

        // 期望交易回滚，因为行权窗口已关闭
        vm.expectRevert(OptionToken.ExerciseWindowClosed.selector);
        // alice尝试行权（应该失败）
        vm.prank(alice);
        option.exercise(amount, alice);
    }

    /// @notice 测试所有者可以提取行权资产并回收过期抵押品
    function testOwnerCanWithdrawStrikeAndReclaimCollateral() public {
        uint256 minted = 2 ether;
        // 铸造2个期权代币给alice
        _mintCollateral(minted, alice);
        console2.log("=== Mint log ===");
        emit log_named_decimal_uint("minted", minted, 18);
        emit log_named_decimal_uint("alice options", option.balanceOf(alice), 18);

        // 给alice一些稳定币便于行权
        uint256 exerciseAmount = 1 ether;
        uint256 strikeCost = (exerciseAmount * STRIKE_PRICE) / 1e18;
        strikeAsset.mint(alice, strikeCost);

        // 进入行权窗口
        vm.warp(expiry + 1);
        vm.deal(alice, 1 ether);

        // alice授权并行权1个期权
        vm.prank(alice);
        strikeAsset.approve(address(option), strikeCost);

        vm.prank(alice);
        option.exercise(exerciseAmount, alice);
        console2.log("=== Exercise partial log ===");
        emit log_named_decimal_uint("exercised", exerciseAmount, 18);
        emit log_named_decimal_uint("contract strike", strikeAsset.balanceOf(address(option)), 18);
        emit log_named_decimal_uint("collateral left", address(option).balance, 18);

        // 验证所有者身份并提取行权收益
        assertEq(option.owner(), owner);
        vm.prank(owner);
        option.withdrawStrike(treasury, strikeCost);
        console2.log("=== Withdraw strike log ===");
        emit log_named_decimal_uint("treasury strike", strikeAsset.balanceOf(treasury), 18);
        // 验证treasury收到了行权资产
        assertEq(strikeAsset.balanceOf(treasury), strikeCost);

        // 将时间推进到行权窗口关闭后
        vm.warp(expiry + EXERCISE_WINDOW + 2);

        // 所有者回收未被行权的抵押品（2 - 1 = 1 ETH）
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        uint256 reclaimed = option.reclaimExpiredCollateral(owner);
        console2.log("=== Reclaim log ===");
        emit log_named_decimal_uint("reclaimed collateral", reclaimed, 18);
        emit log_named_decimal_uint("owner ether", owner.balance, 18);
        console2.log("expired", option.expired());

        // 验证回收的抵押品数量正确
        assertEq(reclaimed, minted - exerciseAmount);
        // 验证所有者的余额增加了回收的抵押品
        assertEq(owner.balance, ownerBalanceBefore + reclaimed);
        // 验证期权已完全过期
        assertTrue(option.expired());

        // 验证过期后无法转让期权代币
        vm.expectRevert(OptionToken.Expired.selector);
        vm.prank(alice);
        option.transfer(treasury, 0.1 ether);

        // 所有者销毁alice剩余的过期代币
        uint256 remaining = option.balanceOf(alice);
        vm.prank(owner);
        option.burnExpired(alice, remaining);
        // 验证总供应量归零
        assertEq(option.totalSupply(), 0);
    }

    /// @notice 测试所有者为流动性池提供初始资金
    function testOwnerSeedsLiquidityPair() public {
        uint256 minted = 3 ether;
        // 所有者给自己铸造3个期权代币
        vm.prank(owner);
        option.mintOptions{value: minted}(owner);

        // 创建一个模拟的流动性池
        MockPool pool = new MockPool();
        uint256 optionAmount = 1 ether;
        uint256 strikeAmount = 100 ether;

        // 给所有者铸造行权资产
        strikeAsset.mint(owner, strikeAmount);

        // 所有者授权合约使用行权资产
        vm.prank(owner);
        strikeAsset.approve(address(option), strikeAmount);

        // 期望触发LiquiditySeeded事件
        vm.expectEmit(true, false, false, true);
        emit OptionToken.LiquiditySeeded(address(pool), optionAmount, strikeAmount);

        // 所有者向流动性池提供初始资金（1个期权代币 + 100个行权资产）
        vm.prank(owner);
        option.seedLiquidity(address(pool), optionAmount, strikeAmount);

        // 验证流动性池收到了期权代币
        assertEq(option.balanceOf(address(pool)), optionAmount);
        // 验证流动性池收到了行权资产
        assertEq(strikeAsset.balanceOf(address(pool)), strikeAmount);
        // 验证所有者剩余的期权代币数量
        assertEq(option.balanceOf(owner), minted - optionAmount);
    }

    /// @notice 测试初始流动性为0时回滚
    function testSeedLiquidityZeroAmountReverts() public {
        uint256 minted = 1 ether;
        // 所有者铸造期权代币
        vm.prank(owner);
        option.mintOptions{value: minted}(owner);

        MockPool pool = new MockPool();
        uint256 strikeAmount = 10 ether;

        // 准备行权资产
        strikeAsset.mint(owner, strikeAmount);

        vm.prank(owner);
        strikeAsset.approve(address(option), strikeAmount);

        // 期望交易回滚，因为期权数量为0（无效数量）
        vm.expectRevert(OptionToken.InvalidAmount.selector);
        // 尝试使用0数量的期权代币提供流动性（应该失败）
        vm.prank(owner);
        option.seedLiquidity(address(pool), 0, strikeAmount);
    }

    /// @notice 测试到期后提供流动性会回滚
    function testSeedLiquidityAfterExpiryReverts() public {
        uint256 minted = 1 ether;
        // 所有者铸造期权代币
        vm.prank(owner);
        option.mintOptions{value: minted}(owner);

        MockPool pool = new MockPool();
        uint256 optionAmount = 0.5 ether;
        uint256 strikeAmount = 20 ether;

        // 准备行权资产
        strikeAsset.mint(owner, strikeAmount);

        vm.prank(owner);
        strikeAsset.approve(address(option), strikeAmount);

        // 将时间推进到到期后（进入行权窗口）
        vm.warp(expiry + 1);

        // 验证时间设置正确
        assertEq(option.expiry(), expiry);
        assertEq(block.timestamp, expiry + 1);
        // 期望交易回滚，因为期权已到期，不能再提供流动性
        vm.expectRevert(OptionToken.Expired.selector);
        // 尝试在到期后提供流动性（应该失败）
        vm.prank(owner);
        option.seedLiquidity(address(pool), optionAmount, strikeAmount);
    }
}
