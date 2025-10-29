// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

/// 标题 甲骨文库
/// @notice 提供与V3池oracle集成的功能
library OracleLibrary {
    /// @notice 计算给定 Uniswap V3 池的时间加权平均值和流动性
    /// 参数 pool 我们要观察的池的地址
    /// 参数 timesAgo 计算时间加权平均值的过去秒数
    /// 返回 mathMeanTick 从 (block.timestamp - SecondsAgo) 到 block.timestamp 的算术平均刻度
    /// 返回 HarmonicMeanLiquidity 从 (block.timestamp - SecondsAgo) 到 block.timestamp 的调和平均流动性
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
        // 始终四舍五入到负无穷大
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)) arithmeticMeanTick--;

        // 我们在这里相乘而不是移位，以确保 HarmonicMeanLiquidity 不会溢出 uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /// @notice 给定一个刻度和一个代币数量，计算在交换中收到的代币数量
    /// 参数 刻度 用于计算报价的刻度值
    /// 参数 baseAmount 要转换的代币数量
    /// 参数 用作基本金额面额的 ERC20 代币合约的 baseToken 地址
    /// 参数 quoteToken 用作 quoteAmount 面额的 ERC20 代币合约的地址
    /// 返回 quoteAmount 收到的 quoteToken 数量，用于 baseAmount of baseToken
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // 如果与自身相乘时不溢出，则以更高的精度计算 quoteAmount
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

    /// @notice 给定一个池，它返回最早存储的观察值之前的秒数
    /// 参数 pool 我们想要观察的Uniswap V3池的地址
    /// 返回 timesAgo 为池存储的最旧观察的秒数
    function getOldestObservationSecondsAgo(address pool) internal view returns (uint32 secondsAgo) {
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();
        require(observationCardinality > 0, 'NI');

        (uint32 observationTimestamp, , , bool initialized) =
            IUniswapV3Pool(pool).observations((observationIndex + 1) % observationCardinality);

        // 如果基数正在增加，则下一个索引可能不会初始化
        // 在这种情况下，最旧的观察值始终位于索引 0 中
        if (!initialized) {
            (observationTimestamp, , , ) = IUniswapV3Pool(pool).observations(0);
        }

        secondsAgo = uint32(block.timestamp) - observationTimestamp;
    }

    /// @notice 给定一个池，它返回当前块开始时的刻度值
    /// 参数 Uniswap V3 矿池地址
    /// 返回 当前块开始时池所在的刻度
    function getBlockStartingTickAndLiquidity(address pool) internal view returns (int24, uint128) {
        (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();

        // 需要 2 次观察才能可靠地计算区块起始价格
        require(observationCardinality > 1, 'NEO');

        // 如果最新的观察发生在过去，则该区块中没有发生任何变动交易
        // 因此，“slot0”中的刻度与当前块开头的刻度相同。
        // 我们不需要检查这个观察是否被初始化——它肯定是被初始化的。
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
        // 始终四舍五入到负无穷大
        if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
    }

    /// @notice 返回“合成”刻度，代表“tokens”中第一个条目相对于最后一个条目的价格
    /// @dev 对于计算沿线的相对价格很有用。
    /// @dev 每对标记集必须有一个刻度。
    /// 参数 tokens 代币合约地址
    /// 参数 刻度线 刻度线，代表“tokens”中每个代币对的价格
    /// 返回 SynthesisTick 合成价格变动，代表“tokens”中最外层代币的相对价格
    function getChainedPrice(address[] memory tokens, int24[] memory ticks)
        internal
        pure
        returns (int256 syntheticTick)
    {
        require(tokens.length - 1 == ticks.length, 'DL');
        for (uint256 i = 1; i <= ticks.length; i++) {
            // 检查令牌的地址排序顺序，然后累积
            // 滴答进入正在运行的合成滴答，确保中间代币“抵消”
            tokens[i - 1] < tokens[i] ? syntheticTick += ticks[i - 1] : syntheticTick -= ticks[i - 1];
        }
    }
}
