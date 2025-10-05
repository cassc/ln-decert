// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    function run() external returns (MultiSigWallet) {
        // Example owners - replace with actual addresses
        address[] memory owners = new address[](3);
        owners[0] = 0xbfDB175c3A4AD1965d2137a18B88a63e16A38426; // Replace with actual address
        owners[1] = 0xD150b45b2c76b65231B682FDbF896A304809209F; // Replace with actual address
        owners[2] = 0x0e7AB1726A497032b6070407678e3c6b7a408aE2; // Replace with actual address

        uint256 requiredConfirmations = 2; // 2 out of 3 multisig

        vm.startBroadcast();

        MultiSigWallet wallet = new MultiSigWallet(owners, requiredConfirmations);

        console.log("MultiSigWallet deployed at:", address(wallet));
        console.log("Owners:");
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("  -", owners[i]);
        }
        console.log("Required confirmations:", requiredConfirmations);

        vm.stopBroadcast();

        return wallet;
    }
}
