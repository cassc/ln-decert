// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/UnsafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

/// 标题 基于 Q64.96 sqrt 价格和流动性的功能
/// @notice 从 @uniswap/v3-core SqrtPriceMath 公开两个函数
/// 使用价格的平方根作为 Q64.96 和流动性来计算 delta
library SqrtPriceMathPartial {
    /// @notice 获取两个价格之间的 amount0 delta
    /// @dev 计算流动性 / sqrt(下) - 流动性 / sqrt(上),
    /// 即流动性 * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// 参数 sqrtRatioAX96 开方价格
    /// 参数 sqrtRatioBX96 另一个 sqrt 价格
    /// 参数 流动性 可用流动性的数量
    /// 参数 roundUp 是否向上或向下舍入金额
    /// 返回 amount0 覆盖两个传递价格之间的流动性头寸所需的 token0 数量
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
    }

    /// @notice 获取两个价格之间的 amount1 Delta
    /// @dev 计算流动性 * (sqrt(上) - sqrt(下))
    /// 参数 sqrtRatioAX96 开方价格
    /// 参数 sqrtRatioBX96 另一个 sqrt 价格
    /// 参数 流动性 可用流动性的数量
    /// 参数 roundUp 是否向上或向下舍入金额
    /// 返回 amount1 弥补两个传递价格之间的流动性头寸所需的 token1 数量
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }
}
