// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/SimpleLeverageDEX.sol";
import "../src/mocks/MockUSDC.sol";

contract SimpleLeverageDEXTest is Test {
    MockUSDC internal usdc;
    SimpleLeverageDEX internal dex;

    address internal alice = address(0x1);
    address internal bob = address(0x2);
    address internal liquidator = address(0x3);

    function setUp() public {
        usdc = new MockUSDC("Mock USDC", "mUSDC", 18);
        dex = new SimpleLeverageDEX(IERC20(address(usdc)), 100 ether, 100_000 ether);

        usdc.mint(alice, 1_000_000 ether);
        usdc.mint(bob, 1_000_000 ether);
        usdc.mint(liquidator, 1_000_000 ether);

        vm.prank(alice);
        usdc.approve(address(dex), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(dex), type(uint256).max);
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }

    function testOpenAndCloseLongNoPnL() public {
        uint256 startBalance = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.openPosition(1_000 ether, 2, true);

        assertEq(usdc.balanceOf(alice), startBalance - 1_000 ether);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), startBalance);

        (uint256 margin,, int256 position) = dex.positions(alice);
        assertEq(margin, 0);
        assertEq(position, 0);
    }

    function testOpenAndCloseShortNoPnL() public {
        uint256 startBalance = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.openPosition(1_000 ether, 3, false);

        assertEq(usdc.balanceOf(alice), startBalance - 1_000 ether);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), startBalance);
    }

    function testLongPositionGainsAfterPriceMove() public {
        uint256 startBalance = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.openPosition(2_000 ether, 3, true);

        vm.prank(bob);
        dex.openPosition(5_000 ether, 3, true);

        int256 pnl = dex.calculatePnL(alice);
        assertGt(pnl, 0);

        vm.prank(alice);
        dex.closePosition();

        uint256 finalBalance = usdc.balanceOf(alice);
        assertGt(finalBalance, startBalance);
    }

    function testLiquidationTransfersMarginToLiquidator() public {
        vm.prank(alice);
        dex.openPosition(2_000 ether, 4, true);

        // Strong short to move price down against Alice.
        vm.prank(bob);
        dex.openPosition(15_000 ether, 4, false);

        int256 pnl = dex.calculatePnL(alice);
        assertLt(pnl, 0);

        uint256 before = usdc.balanceOf(liquidator);

        vm.prank(liquidator);
        dex.liquidatePosition(alice);

        uint256 afterBalance = usdc.balanceOf(liquidator);
        assertGe(afterBalance, before);

        (uint256 marginAfter,, int256 position) = dex.positions(alice);
        assertEq(marginAfter, 0);
        assertEq(position, 0);
    }

    function testCalculatePnLMismatchFromTruncation() public {
        SimpleLeverageDEX dexSmall = new SimpleLeverageDEX(IERC20(address(usdc)), 27, 82);

        address traderLong = address(0x4);
        address traderShort1 = address(0x5);
        address traderShort2 = address(0x6);

        usdc.mint(traderLong, 1_000_000 ether);
        usdc.mint(traderShort1, 1_000_000 ether);
        usdc.mint(traderShort2, 1_000_000 ether);

        vm.prank(alice);
        usdc.approve(address(dexSmall), type(uint256).max);
        vm.prank(traderLong);
        usdc.approve(address(dexSmall), type(uint256).max);
        vm.prank(traderShort1);
        usdc.approve(address(dexSmall), type(uint256).max);
        vm.prank(traderShort2);
        usdc.approve(address(dexSmall), type(uint256).max);

        vm.prank(alice);
        dexSmall.openPosition(5, 1, true);

        vm.prank(traderLong);
        dexSmall.openPosition(32, 1, true);

        vm.prank(traderShort1);
        dexSmall.openPosition(61, 1, false);

        vm.prank(traderShort2);
        dexSmall.openPosition(51, 1, false);

        int256 viewPnL = dexSmall.calculatePnL(alice);

        (uint256 margin, uint256 borrowed, int256 position) = dexSmall.positions(alice);
        uint256 notional = margin + borrowed;
        uint256 ethSize = uint256(position);

        uint256 vETHAfter = dexSmall.vETHAmount();
        uint256 vUSDCAfter = dexSmall.vUSDCAmount();
        uint256 vKAfter = dexSmall.vK();

        uint256 newETH = vETHAfter + ethSize;
        uint256 newUSDC = vKAfter / newETH;
        if (vKAfter % newETH != 0) {
            newUSDC += 1;
        }
        uint256 usdcOut = vUSDCAfter - newUSDC;
        int256 expectedPnL = int256(usdcOut) - int256(notional);

        assertEq(viewPnL, expectedPnL, "calculatePnL should match vAMM settlement");
    }
}
