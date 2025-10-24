// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/UniswapV2Factory.sol";
import "../src/core/UniswapV2Pair.sol";
import "../src/periphery/UniswapV2Router02.sol";
import "../src/test-tokens/WETH9.sol";
import "../src/test-tokens/MockERC20.sol";

contract UniswapV2FuzzInvariant is Test {
    WETH9 internal weth;
    MockERC20 internal token0;
    MockERC20 internal token1;
    MockERC20 internal token2;
    UniswapV2Factory internal factory;
    UniswapV2Router02 internal router;
    address internal user = address(0x1234);

    function setUp() public {
        weth = new WETH9();
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(weth));

        token0.mint(user, type(uint128).max);
        token1.mint(user, type(uint128).max);
        token2.mint(user, type(uint128).max);

        vm.startPrank(user);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        token2.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testFuzz_ConstantProductHolds(uint112 amountA, uint112 amountB, uint96 swapIn) public {
        amountA = uint112(bound(amountA, 1e18, 1e30));
        amountB = uint112(bound(amountB, 1e18, 1e30));
        uint256 maxSwap = uint256(amountA) / 3;
        if (maxSwap > type(uint96).max) {
            maxSwap = type(uint96).max;
        }
        if (maxSwap < 1e15) {
            maxSwap = 1e15;
        }
        swapIn = uint96(bound(swapIn, 1e15, maxSwap));

        vm.startPrank(user);
        router.addLiquidity(
            address(token0),
            address(token1),
            amountA,
            amountB,
            amountA,
            amountB,
            user,
            block.timestamp + 1
        );

        address pairAddr = factory.getPair(address(token0), address(token1));
        (uint112 reserve0Before, uint112 reserve1Before,) = UniswapV2Pair(pairAddr).getReserves();
        uint256 kBefore = uint256(reserve0Before) * uint256(reserve1Before);

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        router.swapExactTokensForTokens(
            swapIn,
            0,
            path,
            user,
            block.timestamp + 1
        );

        (uint112 reserve0After, uint112 reserve1After,) = UniswapV2Pair(pairAddr).getReserves();
        uint256 kAfter = uint256(reserve0After) * uint256(reserve1After);
        vm.stopPrank();

        assertGe(kAfter, kBefore, "Invariant violation: k decreased");
    }

    function testFuzz_AddRemoveLiquidityReturnsValue(uint112 amountA, uint112 amountB, uint112 removeBps) public {
        amountA = uint112(bound(amountA, 1e18, 1e30));
        amountB = uint112(bound(amountB, 1e18, 1e30));
        removeBps = uint112(bound(removeBps, 1, 10_000));

        vm.startPrank(user);
        (, , uint liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 1
        );

        address pairAddr = factory.getPair(address(token0), address(token1));
        UniswapV2Pair(pairAddr).approve(address(router), type(uint256).max);
        uint removeAmount = liquidity * removeBps / 10_000;
        (uint amountOut0, uint amountOut1) = router.removeLiquidity(
            address(token0),
            address(token1),
            removeAmount,
            0,
            0,
            user,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(amountOut0, 0, "No token0 returned");
        assertGt(amountOut1, 0, "No token1 returned");
    }

    function testFuzz_MultihopSwapProducesOutput(
        uint112 amountABase,
        uint112 amountBBridge,
        uint112 amountCBase,
        uint96 swapIn
    ) public {
        amountABase = uint112(bound(amountABase, 1e18, 1e30));
        amountBBridge = uint112(bound(amountBBridge, 1e18, 1e30));
        amountCBase = uint112(bound(amountCBase, 1e18, 1e30));

        uint256 maxSwap = uint256(amountABase) / 4;
        if (maxSwap > type(uint96).max) {
            maxSwap = type(uint96).max;
        }
        if (maxSwap < 1e15) {
            maxSwap = 1e15;
        }
        swapIn = uint96(bound(swapIn, 1e15, maxSwap));

        vm.startPrank(user);
        router.addLiquidity(
            address(token0),
            address(token1),
            amountABase,
            amountBBridge,
            0,
            0,
            user,
            block.timestamp + 1
        );
        router.addLiquidity(
            address(token1),
            address(token2),
            amountBBridge,
            amountCBase,
            0,
            0,
            user,
            block.timestamp + 1
        );

        address[] memory path = new address[](3);
        path[0] = address(token0);
        path[1] = address(token1);
        path[2] = address(token2);

        uint256 balanceBefore = token2.balanceOf(user);
        router.swapExactTokensForTokens(
            swapIn,
            0,
            path,
            user,
            block.timestamp + 1
        );
        uint256 balanceAfter = token2.balanceOf(user);
        vm.stopPrank();

        assertGt(balanceAfter, balanceBefore, "No output from multihop swap");
    }

    function testFuzz_SlippageGuardReverts(uint112 amountA, uint112 amountB, uint96 swapIn) public {
        amountA = uint112(bound(amountA, 1e18, 1e30));
        amountB = uint112(bound(amountB, 1e18, 1e30));

        uint256 maxSwap = uint256(amountA) / 4;
        if (maxSwap > type(uint96).max) {
            maxSwap = type(uint96).max;
        }
        if (maxSwap < 1e15) {
            maxSwap = 1e15;
        }
        swapIn = uint96(bound(swapIn, 1e15, maxSwap));

        vm.startPrank(user);
        router.addLiquidity(
            address(token0),
            address(token1),
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 1
        );

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uint[] memory expected = router.getAmountsOut(swapIn, path);
        uint minOut = expected[expected.length - 1] + 1;

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            swapIn,
            minOut,
            path,
            user,
            block.timestamp + 1
        );
        vm.stopPrank();
    }
}
