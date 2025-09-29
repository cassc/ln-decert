// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BuggyToken} from "../src/BuggyToken.sol";

contract BuggyTokenInvariant is StdInvariant {
    BuggyToken internal token;
    address internal deployer;

    function setUp() public {
        token = new BuggyToken();
        deployer = token.owner();

        targetContract(address(token));
        targetSender(address(this));
        targetSender(address(0xBEEF));
        targetSender(address(0xCAFE));
    }

    /// @notice Expected to fail because anyone can hijack ownership via setOwner.
    function invariant_onlyDeployerRemainsOwner() public view {
        require(token.owner() == deployer, "ownership should remain with deployer");
    }
}
