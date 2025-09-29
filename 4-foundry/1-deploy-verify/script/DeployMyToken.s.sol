// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external {
        string memory name = vm.envOr("TOKEN_NAME", string(unicode"登链"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("DTL"));

        vm.startBroadcast();
        new MyToken(name, symbol);
        vm.stopBroadcast();
    }
}
