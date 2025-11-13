// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {esRNT} from "../src/EsRNT.sol";

contract DeployEsRNTScript is Script {
    function run() public returns (esRNT deployed) {
        vm.startBroadcast();
        deployed = new esRNT();
        vm.stopBroadcast();

        console2.log("esRNT deployed at", address(deployed));
    }
}
