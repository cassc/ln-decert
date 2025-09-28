// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {NFTMarket} from "../src/NFTMarket.sol";
import {DecentMarketToken} from "../src/DecentMarketToken.sol";

/// @notice Deployment script for NFTMarket contract.
contract DeployNFTMarket is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        
        // Get the token address from environment variable or deploy a new one
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        
        vm.startBroadcast(deployerKey);

        DecentMarketToken token;
        
        if (tokenAddress == address(0)) {
            // Deploy a new token if address not provided
            token = new DecentMarketToken();
            console.log("New DecentMarketToken deployed at:", address(token));
        } else {
            // Use existing token
            token = DecentMarketToken(tokenAddress);
            console.log("Using existing DecentMarketToken at:", tokenAddress);
        }

        NFTMarket market = new NFTMarket(token);
        
        // Log deployment info
        console.log("NFTMarket deployed at:", address(market));
        console.log("Payment token:", address(market.paymentToken()));

        vm.stopBroadcast();
    }
}