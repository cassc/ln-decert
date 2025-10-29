// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "forge-std/Script.sol";
import "@uniswap/v3-core/contracts/UniswapV3Pool.sol";

/**
 * @title 计算 InitCodeHash
 * @notice 计算 UniswapV3Pool 的 init code hash
 * @dev 该哈希值用于 CREATE2 地址预计算
 *
 * 在 Uniswap V3 中，池地址通过 CREATE2 部署，可以在链下预先计算：
 *
 * 地址 = keccak256(
 *     abi.encodePacked(              // 拼接输入参数
 *         hex'ff',                   // CREATE2 固定前缀
 *         factory,                   // 工厂地址
 *         keccak256(abi.encodePacked(token0, token1, fee)), // 代币与费率哈希
 *         POOL_INIT_CODE_HASH        // <-- 这里需要的值
 *     )                            // 编码结束
 * )                                // 计算地址
 *
 * 使用方式：
 * forge script script/CalculateInitCodeHash.s.sol  // 运行脚本命令
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
