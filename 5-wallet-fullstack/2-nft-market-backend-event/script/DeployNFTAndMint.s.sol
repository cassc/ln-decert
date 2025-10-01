// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";

/// @notice Deployment script for DecentMarketNFT that also mints three NFTs.
contract DeployNFTAndMint is Script {
    function run() external {
        string[] memory uris = new string[](3);
        uris[0] = vm.envString("TOKEN_URI_0");
        uris[1] = vm.envString("TOKEN_URI_1");
        uris[2] = vm.envString("TOKEN_URI_2");

        address recipient;
        try vm.envAddress("MINT_TO") returns (address value) {
            recipient = value;
        } catch {
            revert("MINT_TO env var is required");
        }

        vm.startBroadcast();

        DecentMarketNFT nft = new DecentMarketNFT("Decent Market NFT", "DMNFT");
        for (uint256 i = 0; i < uris.length; i++) {
            nft.mintTo(recipient, uris[i]);
        }

        vm.stopBroadcast();
    }
}
