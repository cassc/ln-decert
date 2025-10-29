// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './FullMath.sol';
import './UnsafeMath.sol';
import './FixedPoint96.sol';

/// @title 基于 Q64.96 sqrt 价格和流动性的功能
/// @notice 包含使用价格平方根作为 Q64.96 和流动性来计算 delta 的数学
library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /// @notice 获取给定 token0 增量的下一个 sqrt 价格
    /// @dev 始终向上舍入，因为在确切的输出情况（价格增加）下，我们至少需要移动价格
    /// 足够远以获得所需的输出量，并且在确切的输入情况下（价格下降），我们需要移动
    /// 价格较低，以免输出过多。
    /// 最精确的公式是流动性 * sqrtPX96 / (流动性 +- 金额 * sqrtPX96)，
    /// 如果由于溢出而无法实现，我们将计算流动性 / (流动性 / sqrtPX96 +- 金额)。
    /// @param sqrtPX96 起始价格，即在考虑 token0 delta 之前
    /// @param 流动性 可用流动性的数量
    /// @param amount 从虚拟储备中添加或删除多少 token0
    /// @param add 是否添加或删除token0的数量
    /// @return 添加或删除数量后的价格，取决于添加量
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // 我们短路 amount == 0 因为否则不能保证结果等于输入价格
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 product;
            if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // 始终适合 160 位
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            }

            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));
        } else {
            uint256 product;
            // 如果乘积溢出，我们知道分母下溢
            // 此外，我们必须检查分母是否下溢
            require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
            uint256 denominator = numerator1 - product;
            return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    /// @notice 给定 token1 的增量，获取下一个 sqrt 价格
    /// @dev 始终向下舍入，因为在确切的输出情况（价格下降）下，我们至少需要移动价格
    /// 足够远以获得所需的输出量，并且在确切的输入情况（价格增加）下，我们需要移动
    /// 价格较低，以免输出过多。
    /// 我们计算的公式在无损版本的 <1 wei 范围内：s​​qrtPX96 +- 金额 / 流动性
    /// @param sqrtPX96 起始价格，即在考虑 token1 delta 之前
    /// @param 流动性 可用流动性的数量
    /// @param amount 从虚拟储备中添加或删除多少 token1
    /// @param add 是否添加或删除token1的数量
    /// @return 添加或删除“金额”后的价格
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // 如果我们要加（减），则向下舍入需要将商向下（向上）舍入
        // 在这两种情况下，对于大多数输入都避免使用 mulDiv
        if (add) {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                );

            return uint256(sqrtPX96).add(quotient).toUint160();
        } else {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

            require(sqrtPX96 > quotient);
            // 始终适合 160 位
            return uint160(sqrtPX96 - quotient);
        }
    }

    /// @notice 给定输入金额 token0 或 token1 获取下一个 sqrt 价格
    /// @dev 如果价格或流动性为 0，或者下一个价格超出范围，则抛出异常
    /// @param sqrtPX96 起始价格，即在考虑输入金额之前
    /// @param 流动性 可用流动性的数量
    /// @param amountIn 交换了多少 token0 或 token1
    /// @param ZeroForOne 中的金额是否为token0或token1
    /// @return sqrtQX96 输入金额与token0或token1相加后的价格
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // 一轮以确保我们没有超过目标价格
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
                : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /// @notice 给定输出金额 token0 或 token1 获取下一个 sqrt 价格
    /// @dev 如果价格或流动性为 0 或下一个价格超出范围，则抛出异常
    /// @param sqrtPX96 未计算产量的起始价格
    /// @param 流动性 可用流动性的数量
    /// @param amountOut 有多少 token0 或 token1 被换出
    /// @param ZeroForOne 出的金额是token0还是token1
    /// @return sqrtQX96 去除token0或token1的输出金额后的价格
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // 回合以确保我们通过目标价格
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
                : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /// @notice 获取两个价格之间的 amount0 delta
    /// @dev 计算流动性 / sqrt(下) - 流动性 / sqrt(上),
    /// 即流动性 * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtRatioAX96 开方价格
    /// @param sqrtRatioBX96 另一个 sqrt 价格
    /// @param 流动性 可用流动性的数量
    /// @param roundUp 是否向上或向下舍入金额
    /// @return amount0 覆盖两个传递价格之间的流动性头寸所需的 token0 数量
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
    /// @param sqrtRatioAX96 开方价格
    /// @param sqrtRatioBX96 另一个 sqrt 价格
    /// @param 流动性 可用流动性的数量
    /// @param roundUp 是否向上或向下舍入金额
    /// @return amount1 弥补两个传递价格之间的流动性头寸所需的 token1 数量
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

    /// @notice 获得签名 token0 delta 的助手
    /// @param sqrtRatioAX96 开方价格
    /// @param sqrtRatioBX96 另一个 sqrt 价格
    /// @param 流动性 计算 amount0 delta 的流动性变化
    /// @return amount0 传递的流动性对应的 token0 数量 两个价格之间的Delta
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }

    /// @notice 获得签名 token1 增量的助手
    /// @param sqrtRatioAX96 开方价格
    /// @param sqrtRatioBX96 另一个 sqrt 价格
    /// @param 流动性 计算金额 1 增量的流动性变化
    /// @return amount1 传递的流动性对应的token1数量 两个价格之间的Delta
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }
}
