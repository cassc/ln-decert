// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FlashSwapArb} from "../src/FlashSwapArb.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Run a flash swap using an already deployed FlashSwapArb contract.
contract RunArbitrage is Script {
    function run(
        address caller,
        address flashArb,
        address pairBorrow,
        address pairSwap,
        address tokenBorrow,
        uint256 amount,
        address profitRecipient
    ) public {
        require(caller != address(0), "CALLER_REQUIRED");
        require(flashArb != address(0), "FLASH_ARB_REQUIRED");

        address profitToken = _resolveProfitToken(pairBorrow, tokenBorrow);
        uint256 balanceBefore = IERC20(profitToken).balanceOf(profitRecipient);

        vm.startBroadcast(caller);

        FlashSwapArb(flashArb).startArbitrage(pairBorrow, pairSwap, tokenBorrow, amount, profitRecipient);

        vm.stopBroadcast();

        uint256 balanceAfter = IERC20(profitToken).balanceOf(profitRecipient);
        uint256 profit = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;

        console2.log("Arbitrage executed");
        console2.log("Flash contract  :", flashArb);
        console2.log("Borrow pair     :", pairBorrow);
        console2.log("Swap pair       :", pairSwap);
        console2.log("Token borrowed  :", tokenBorrow);
        console2.log("Borrow amount   :", amount);
        console2.log("Profit recipient:", profitRecipient);
        console2.log("Profit token    :", profitToken);
        console2.log("Profit amount   :", profit);
    }

    function _resolveProfitToken(address pairBorrow, address tokenBorrow) internal view returns (address) {
        address token0 = IUniswapV2Pair(pairBorrow).token0();
        address token1 = IUniswapV2Pair(pairBorrow).token1();
        if (tokenBorrow == token0) {
            return token1;
        }
        require(tokenBorrow == token1, "TOKEN_NOT_IN_PAIR");
        return token0;
    }
}
