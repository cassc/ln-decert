// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Counter {
    uint256 private counter;

    function add(uint256 val) external {
        unchecked {
            counter += val;
        }
    }

    function get() external view returns (uint256) {
        return counter;
    }
}
