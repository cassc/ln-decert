// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import '../../core/interfaces/IUniswapV2Pair.sol';
import '../../core/libraries/SafeMath.sol';

/**
 * @title UniswapV2Library
 * @notice Uniswap V2 工具库 - 提供常用的计算和查询函数
 * @dev 这些函数在链上和链下都可以使用
 */
library UniswapV2Library {
    using SafeMath for uint;

    /**
     * @notice 对两个代币地址排序
     * @dev 确保 token0 < token1，与 Factory 中的排序逻辑一致
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @notice 计算交易对地址（无需查询 Factory）
     * @param factory Factory 合约地址
     * @param tokenA 第一个代币
     * @param tokenB 第二个代币
     * @return pair 交易对地址
     * @dev 使用 CREATE2 地址计算公式，避免链上查询，节省 gas
     *
     * ⚠️ 重要：init_code_hash 必须与实际部署的 UniswapV2Pair 字节码哈希一致
     *
     * CREATE2 地址计算：
     * pair = address(keccak256(abi.encodePacked(
     *     hex'ff',
     *     factory,
     *     keccak256(abi.encodePacked(token0, token1)),
     *     hex'<init_code_hash>' // 这里需要替换为实际的 pair 合约字节码哈希
     * )))
     *
     * 获取 init_code_hash 的方法：
     * 1. 部署后：keccak256(type(UniswapV2Pair).creationCode)
     * 2. 或使用脚本：keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode))
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'4d0725af34230adcaa6da48c8491546e5852ba1c2a1bea6827af5d9272a4a308' // keccak256(type(UniswapV2Pair).creationCode)
        )))));
    }

    /**
     * @notice 获取交易对的储备量
     * @dev 返回的储备量顺序与输入的 tokenA、tokenB 顺序一致
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice 根据等值计算另一个代币的数量
     * @dev 用于添加流动性时计算最优比例
     *
     * 公式：amountB = amountA * reserveB / reserveA
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @notice 计算给定输入数量的输出数量（考虑 0.3% 手续费）
     * @param amountIn 输入代币数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountOut 输出代币数量
     * @dev 基于恒定乘积公式：(x + Δx * 0.997) * (y - Δy) = x * y
     *
     * 推导：
     * amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
     *
     * 997/1000 = 0.997 表示扣除 0.3% 手续费后的输入
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /**
     * @notice 计算获得指定输出数量所需的输入数量（考虑 0.3% 手续费）
     * @param amountOut 期望输出数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountIn 所需输入数量
     * @dev 基于恒定乘积公式反向计算
     *
     * 推导：
     * amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
     * +1 是为了向上取整，确保输入足够
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    /**
     * @notice 计算多跳交换的输出数量
     * @param amountIn 初始输入数量
     * @param path 代币路径
     * @return amounts 每一跳的数量数组
     * @dev 用于精确输入的多跳交换
     */
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice 计算多跳交换的输入数量
     * @param amountOut 期望的最终输出数量
     * @param path 代币路径
     * @return amounts 每一跳的数量数组
     * @dev 用于精确输出的多跳交换
     */
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
