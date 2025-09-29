// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BuggyToken} from "../src/BuggyToken.sol";

contract DeployBuggyToken is Script {
    function run() external returns (BuggyToken token) {
        vm.startBroadcast();
        token = new BuggyToken();
        vm.stopBroadcast();
    }
}
