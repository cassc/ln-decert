// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

/// @title 预言机工具库（Oracle Library）
/// @notice 提供与 Uniswap V3 池预言机集成的实用函数
library OracleLibrary {
    /// @notice 计算给定 Uniswap V3 池的时间加权平均刻度与流动性
    /// @param pool 目标池地址
    /// @param secondsAgo 回溯的秒数区间
    /// @return arithmeticMeanTick 在 [block.timestamp - secondsAgo, block.timestamp] 区间内的算术平均刻度
    /// @return harmonicMeanLiquidity 在该区间内的调和平均流动性
    function consult(address pool, uint32 secondsAgo)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / secondsAgo);
        // 始终向负无穷方向取整
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)) arithmeticMeanTick--;

        // 使用乘法而非移位，避免 harmonicMeanLiquidity 溢出 uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /// @notice 给定刻度与代币数量，计算交换可获得的代币数量
    /// @param tick 用于计算报价的刻度
    /// @param baseAmount 要兑换的基础代币数量
    /// @param baseToken 作为基础金额计价的 ERC20 代币地址
    /// @param quoteToken 作为报价金额计价的 ERC20 代币地址
    /// @return quoteAmount 按照给定刻度与方向可获得的 quoteToken 数量
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // 若平方不溢出，按更高精度计算 quoteAmount
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    /// @notice 返回某池最早一次观察距今的秒数
    /// @param pool 目标 Uniswap V3 池地址
    /// @return secondsAgo 距离当前时间的秒数
    function getOldestObservationSecondsAgo(address pool) internal view returns (uint32 secondsAgo) {
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();
        require(observationCardinality > 0, 'NI');

        (uint32 observationTimestamp, , , bool initialized) =
            IUniswapV3Pool(pool).observations((observationIndex + 1) % observationCardinality);

        // 若基数正在增长，下一个索引可能未初始化
        // 此时，最旧观察值固定位于索引 0
        if (!initialized) {
            (observationTimestamp, , , ) = IUniswapV3Pool(pool).observations(0);
        }

        secondsAgo = uint32(block.timestamp) - observationTimestamp;
    }

    /// @notice 返回当前区块开始时的刻度与流动性
    /// @param pool Uniswap V3 池地址
    /// @return int24 开始刻度，uint128 开始流动性
    function getBlockStartingTickAndLiquidity(address pool) internal view returns (int24, uint128) {
        (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();

        // 至少需要 2 次观察才能可靠计算区块起始价格
        require(observationCardinality > 1, 'NEO');

        // 若最新观察发生在过去，说明本区块尚无交易
        // 此时 slot0 中的刻度即为区块起始刻度
        (uint32 observationTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, ) =
            IUniswapV3Pool(pool).observations(observationIndex);
        if (observationTimestamp != uint32(block.timestamp)) {
            return (tick, IUniswapV3Pool(pool).liquidity());
        }

        uint256 prevIndex = (uint256(observationIndex) + observationCardinality - 1) % observationCardinality;
        (
            uint32 prevObservationTimestamp,
            int56 prevTickCumulative,
            uint160 prevSecondsPerLiquidityCumulativeX128,
            bool prevInitialized
        ) = IUniswapV3Pool(pool).observations(prevIndex);

        require(prevInitialized, 'ONI');

        uint32 delta = observationTimestamp - prevObservationTimestamp;
        tick = int24((tickCumulative - prevTickCumulative) / delta);
        uint128 liquidity =
            uint128(
                (uint192(delta) * type(uint160).max) /
                    (uint192(secondsPerLiquidityCumulativeX128 - prevSecondsPerLiquidityCumulativeX128) << 32)
            );
        return (tick, liquidity);
    }

    /// @notice 用于计算加权算术平均价格变动的信息
    struct WeightedTickData {
        int24 tick;
        uint128 weight;
    }

    /// @notice 给定一系列刻度和权重，计算加权算术平均刻度
    /// 参数 WeightedTickData 价格变动和权重的数组
    /// 返回 WeightedArithmeticMeanTick 加权算术平均刻度
    /// @dev “weightedTickData”的每个条目应代表具有相同基础池代币的池中的报价。如果他们不这样做，
    /// 必须格外小心，以确保报价具有可比性（包括小数差异）。
    /// @dev 请注意，加权算术平均价格变动对应于加权几何平均价格。
    function getWeightedArithmeticMeanTick(WeightedTickData[] memory weightedTickData)
        internal
        pure
        returns (int24 weightedArithmeticMeanTick)
    {
        // 累加每个刻度与其权重之间的乘积之和
        int256 numerator;

        // 累加权重总和
        uint256 denominator;

        // 产品适合 152 位，因此需要长度为 ~2**104 的数组才能溢出此逻辑
        for (uint256 i; i < weightedTickData.length; i++) {
            numerator += weightedTickData[i].tick * int256(weightedTickData[i].weight);
            denominator += weightedTickData[i].weight;
        }

        weightedArithmeticMeanTick = int24(numerator / int256(denominator));
        // 始终向负无穷方向取整
        if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
    }

    /// @notice 返回“合成”刻度，表示 tokens[0] 相对 tokens[last] 的价格
    /// @dev 对沿路径计算相对价格很有用
    /// @dev 路径中的每个代币对都需提供一个刻度
    /// @param tokens 代币地址数组
    /// @param ticks 刻度数组，代表路径上每个代币对的价格刻度
    /// @return syntheticTick 合成刻度，表示最外层两端代币的相对价格
    function getChainedPrice(address[] memory tokens, int24[] memory ticks)
        internal
        pure
        returns (int256 syntheticTick)
    {
        require(tokens.length - 1 == ticks.length, 'DL');
        for (uint256 i = 1; i <= ticks.length; i++) {
            // 根据地址顺序决定加减，累积到合成刻度，确保中间代币“抵消”
            tokens[i - 1] < tokens[i] ? syntheticTick += ticks[i - 1] : syntheticTick -= ticks[i - 1];
        }
    }
}
