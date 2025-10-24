// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Pair.sol";

/**
 * @title CalculateInitCodeHash
 * @notice 计算 UniswapV2Pair 的 init_code_hash
 * @dev 这个 hash 需要被复制到 UniswapV2Library.sol 的 pairFor 函数中
 *
 * 运行方式：
 * forge script script/CalculateInitCodeHash.s.sol
 */
contract CalculateInitCodeHash is Script {
    function run() public view {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 hash = keccak256(bytecode);

        console.log("==============================================");
        console.log("UniswapV2Pair Init Code Hash:");
        console.logBytes32(hash);
        console.log("==============================================");
        console.log("");
        console.log("Please update this hash in:");
        console.log("src/periphery/libraries/UniswapV2Library.sol");
        console.log("in the pairFor() function");
        console.log("==============================================");
    }
}
