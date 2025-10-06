// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {DecentMarketToken} from "../src/DecentMarketToken.sol";

/// @notice Deployment script for DecentMarketToken (ERC20 token).
contract DeployToken is Script {
    function run() external {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            vm.startBroadcast();
        }

        DecentMarketToken token = new DecentMarketToken();
        
        // Log deployment info
        console.log("DecentMarketToken deployed at:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Token decimals:", token.decimals());
        console.log("Total supply:", token.totalSupply());

        vm.stopBroadcast();
    }
}
