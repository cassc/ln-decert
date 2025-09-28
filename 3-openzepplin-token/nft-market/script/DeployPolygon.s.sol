// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";

/// @notice Deploy to Polygon Mainnet - cheap and OpenSea supported!
contract DeployPolygon is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address recipient = vm.envAddress("MINT_TO");

        string[] memory uris = new string[](3);
        uris[0] = vm.envString("TOKEN_URI_0");
        uris[1] = vm.envString("TOKEN_URI_1");
        uris[2] = vm.envString("TOKEN_URI_2");

        console.log("Deploying to Polygon Mainnet...");
        console.log("Deployer:", vm.addr(deployerKey));
        console.log("Recipient:", recipient);

        vm.startBroadcast(deployerKey);

        DecentMarketNFT nft = new DecentMarketNFT("Decent Market NFT", "DMNFT");

        console.log("Contract deployed at:", address(nft));

        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = nft.mintTo(recipient, uris[i]);
            console.log("Minted token", tokenId, "with URI:", uris[i]);
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== SUCCESS! ===");
        console.log("Contract Address:", address(nft));
        console.log("Add this to your .env file:");
        console.log("CONTRACT_ADDRESS=", vm.toString(address(nft)));
        console.log("");
        console.log("OpenSea Collection (wait 5-10 min for indexing):");
        console.log("https://opensea.io/assets/matic/", vm.toString(address(nft)));
        console.log("");
        console.log("Polygon Explorer:");
        console.log("https://polygonscan.com/address/", vm.toString(address(nft)));
    }
}
