// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FlashSwapArb} from "../src/FlashSwapArb.sol";

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

        vm.startBroadcast(caller);

        FlashSwapArb(flashArb).startArbitrage(pairBorrow, pairSwap, tokenBorrow, amount, profitRecipient);

        vm.stopBroadcast();

        console2.log("Arbitrage executed");
        console2.log("Flash contract  :", flashArb);
        console2.log("Borrow pair     :", pairBorrow);
        console2.log("Swap pair       :", pairSwap);
        console2.log("Token borrowed  :", tokenBorrow);
        console2.log("Borrow amount   :", amount);
        console2.log("Profit recipient:", profitRecipient);
    }
}
