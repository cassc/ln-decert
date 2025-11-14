// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {esRNT} from "../src/EsRNT.sol";

contract EsRNTTest is Test {
    esRNT private token;

    function setUp() public {
        vm.warp(1_000);
        token = new esRNT();
    }

    function testLocksLength() public view {
        assertEq(token.locksLength(), 11);
    }
}
