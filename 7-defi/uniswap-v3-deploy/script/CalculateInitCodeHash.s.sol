// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "forge-std/Script.sol";
import "@uniswap/v3-core/contracts/UniswapV3Pool.sol";

/**
 * @title CalculateInitCodeHash
 * @notice 计算 UniswapV3Pool 的 init code hash
 * @dev 这个 hash 值用于 CREATE2 地址预计算
 *
 * 在 Uniswap V3 中，池子地址通过 CREATE2 部署，可以在链下预先计算：
 *
 * address = keccak256(
 *     abi.encodePacked(
 *         hex'ff',
 *         factory,
 *         keccak256(abi.encodePacked(token0, token1, fee)),
 *         POOL_INIT_CODE_HASH  // <-- 这里需要的值
 *     )
 * )
 *
 * 运行方式：
 * forge script script/CalculateInitCodeHash.s.sol
 */
contract CalculateInitCodeHash is Script {
    function run() public view {
        bytes32 POOL_INIT_CODE_HASH = keccak256(type(UniswapV3Pool).creationCode);

        console.log("==============================================");
        console.log("UniswapV3Pool Init Code Hash:");
        console.log("==============================================");
        console.logBytes32(POOL_INIT_CODE_HASH);
        console.log("==============================================");
        console.log("");
        console.log("Use this hash in PoolAddress library or for address computation");
        console.log("Example usage in v3-periphery/contracts/libraries/PoolAddress.sol");
    }
}
