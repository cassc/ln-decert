// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenScript is Script {
    function run(address recipient) external {

        vm.startBroadcast();
        address deployer = tx.origin; // capture forge broadcast account
        new RebaseToken(recipient);
        vm.stopBroadcast();

        deployer; // silence unused var
    }
}
