// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {OptionToken} from "../src/OptionToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployOptionToken is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address strikeAsset = vm.envAddress("STRIKE_ASSET");
        uint256 strikePrice = vm.envUint("STRIKE_PRICE");
        uint64 expiry = uint64(vm.envUint("EXPIRY"));
        uint64 exerciseWindow = uint64(vm.envUint("EXERCISE_WINDOW"));

        vm.startBroadcast();
        new OptionToken(
            "ETH Call Learning", "ocETH-LAB", owner, IERC20(strikeAsset), strikePrice, expiry, exerciseWindow
        );
        vm.stopBroadcast();
    }
}
