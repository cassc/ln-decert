// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {FlashSwapArb} from "../src/FlashSwapArb.sol";
import {MockUniswapV2Factory} from "../src/mocks/MockUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";

contract FlashSwapTest is Test {
    MyToken private tokenA;
    MyToken private tokenB;
    MockUniswapV2Factory private factoryA;
    MockUniswapV2Factory private factoryB;
    FlashSwapArb private flash;

    address private pairA;
    address private pairB;

    function setUp() public {
        tokenA = new MyToken("MyTokenA", "MTA", 1_000_000 ether, address(this));
        tokenB = new MyToken("MyTokenB", "MTB", 1_000_000 ether, address(this));

        factoryA = new MockUniswapV2Factory();
        factoryB = new MockUniswapV2Factory();

        pairA = factoryA.createPair(address(tokenA), address(tokenB));
        pairB = factoryB.createPair(address(tokenA), address(tokenB));

        _seedLiquidity(pairA, 1_000 ether, 1_000 ether); // 1:1 price
        _seedLiquidity(pairB, 500 ether, 1_000 ether);   // 1 A -> 2 B effective price

        flash = new FlashSwapArb();
    }

    function testFlashSwapCreatesProfit() public {
        uint256 balanceBefore = tokenB.balanceOf(address(this));

        flash.startArbitrage(pairA, pairB, address(tokenA), 100 ether, address(this));

        uint256 balanceAfter = tokenB.balanceOf(address(this));
        assertGt(balanceAfter, balanceBefore, "arbitrage should return profit in TokenB");
    }

    function _seedLiquidity(address pair, uint256 amountTokenA, uint256 amountTokenB) internal {
        tokenA.transfer(pair, amountTokenA);
        tokenB.transfer(pair, amountTokenB);
        IUniswapV2Pair(pair).mint(address(this));
    }
}
