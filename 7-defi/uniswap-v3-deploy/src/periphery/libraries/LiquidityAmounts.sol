// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

/// 标题 流动性金额函数
/// @notice 提供根据代币数量和价格计算流动性数量的函数
library LiquidityAmounts {
    /// @notice 将 uint256 向下转换为 uint128
    /// 参数 x 要向下转换的 uint258
    /// 返回 y 传递的值，向下转换为 uint128
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice 计算给定数量的 token0 和价格范围收到的流动性数量
    /// @dev 计算 amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 amount0 正在发送的 amount0
    /// 返回 流动性 返还的流动性金额
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96);
        return toUint128(FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice 计算给定数量的代币1和价格范围收到的流动性数量
    /// @dev 计算 amount1 / (sqrt(upper) - sqrt(lower))。
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 amount1 正在发送的 amount1
    /// 返回 流动性 返还的流动性金额
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return toUint128(FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice 计算给定数量的 token0、token1、当前收到的最大流动性数量
    /// 池价格和刻度边界的价格
    /// 参数 sqrtRatioX96 代表当前池价格的 sqrt 价格
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 amount0 发送的 token0 的数量
    /// 参数 amount1 发送的 token1 的数量
    /// 返回 流动性 收到的最大流动性金额
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    /// @notice 计算给定流动性和价格范围的 token0 数量
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 流动性 被评估的流动性
    /// 返回 amount0 代币0的数量
    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            FullMath.mulDiv(
                uint256(liquidity) << FixedPoint96.RESOLUTION,
                sqrtRatioBX96 - sqrtRatioAX96,
                sqrtRatioBX96
            ) / sqrtRatioAX96;
    }

    /// @notice 计算给定流动性和价格范围下的 token1 数量
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 流动性 被评估的流动性
    /// 返回 amount1 代币1的数量
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /// @notice 计算给定流动性数量的 token0 和 token1 值，当前
    /// 池价格和刻度边界的价格
    /// 参数 sqrtRatioX96 代表当前池价格的 sqrt 价格
    /// 参数 sqrtRatioAX96 代表第一个刻度边界的 sqrt 价格
    /// 参数 sqrtRatioBX96 代表第二个刻度线边界的 sqrt 价格
    /// 参数 流动性 被评估的流动性
    /// 返回 amount0 代币0的数量
    /// 返回 amount1 代币1的数量
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}
