// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {OpenspaceNFT} from "../contracts/OpenspaceNFT.sol";

contract DeployOpenspaceNFT is Script {
    function run() external returns (OpenspaceNFT deployed) {
        vm.startBroadcast();
        deployed = new OpenspaceNFT();
        vm.stopBroadcast();
    }
}
