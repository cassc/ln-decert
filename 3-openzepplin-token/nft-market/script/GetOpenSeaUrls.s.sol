// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GetOpenSeaUrls is Script {
    function run() external view {
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");

        console.log("OpenSea collection URLs:");
        console.log(string.concat("Polygon: https://opensea.io/assets/polygon/", vm.toString(contractAddress)));
        console.log(string.concat("Ethereum: https://opensea.io/assets/ethereum/", vm.toString(contractAddress)));
    }
}
