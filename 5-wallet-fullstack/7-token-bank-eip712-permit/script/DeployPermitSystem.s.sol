// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {PermitToken} from "../src/PermitToken.sol";
import {Bank} from "../src/Bank.sol";
import {PermitNFT} from "../src/PermitNFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

/// @notice End-to-end deployment for the permit-enabled token bank and NFT market.
contract DeployPermitSystem is Script {
    struct Deployment {
        PermitToken token;
        Bank bank;
        PermitNFT nft;
        NFTMarket market;
    }

    function run() external returns (Deployment memory deployment) {
        address tokenOwner = vm.envAddress("TOKEN_OWNER");
        address whitelistSigner = vm.envAddress("WHITELIST_SIGNER");
        address nftOwner = vm.envOr("NFT_OWNER", tokenOwner);
        string memory nftName = vm.envOr("NFT_NAME", string("Permit NFT"));
        string memory nftSymbol = vm.envOr("NFT_SYMBOL", string("PNFT"));

        console2.log("=== Permit system deployment parameters ===");
        console2.log("tokenOwner", tokenOwner);
        console2.log("nftOwner", nftOwner);
        console2.log("whitelistSigner", whitelistSigner);
        console2.log("nftName", nftName);
        console2.log("nftSymbol", nftSymbol);

        vm.startBroadcast();
        PermitToken token = new PermitToken(tokenOwner);
        Bank bank = new Bank(token);
        PermitNFT nft = new PermitNFT(nftOwner, nftName, nftSymbol);
        NFTMarket market = new NFTMarket(token, whitelistSigner);
        vm.stopBroadcast();

        console2.log("=== Deployed contracts ===");
        console2.log("PermitToken", address(token));
        console2.log("Bank", address(bank));
        console2.log("PermitNFT", address(nft));
        console2.log("NFTMarket", address(market));

        deployment = Deployment({
            token: token,
            bank: bank,
            nft: nft,
            market: market
        });
    }
}
