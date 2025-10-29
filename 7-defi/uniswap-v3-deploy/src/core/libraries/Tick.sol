// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './TickMath.sol';
import './LiquidityMath.sol';

/// @title 打钩
/// @notice 包含管理报价流程和相关计算的函数
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    // 为每个初始化的单独刻度存储的信息
    struct Info {
        // 引用此报价的总头寸流动性
        uint128 liquidityGross;
        // 从左向右（从右向左）交叉时增加（减去）的净流动性金额，
        int128 liquidityNet;
        // 此报价变动另一侧每单位流动性的费用增长（相对于当前报价）
        // 仅具有相对含义，而不是绝对含义 - 该值取决于刻度线的初始化时间
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        // 刻度另一侧的累积刻度值
        int56 tickCumulativeOutside;
        // 此报价另一侧每单位流动性的秒数（相对于当前报价）
        // 仅具有相对含义，而不是绝对含义 - 该值取决于刻度线的初始化时间
        uint160 secondsPerLiquidityOutsideX128;
        // 在刻度线另一侧花费的秒数（相对于当前刻度线）
        // 仅具有相对含义，而不是绝对含义 - 该值取决于刻度线的初始化时间
        uint32 secondsOutside;
        // true 当且仅当刻度已初始化，即该值完全等于表达式 LiquidityGross != 0
        // 设置这 8 位是为了防止在跨越新初始化的刻度时出现新的存储
        bool initialized;
    }

    /// @notice 从给定的价格变动间隔得出每个价格变动的最大流动性
    /// @dev 在池构造函数中执行
    /// @param tickSpacing 所需的刻度间隔量，以 `tickSpacing` 的倍数实现
    ///     例如，tickSpacing 为 3 要求每第 3 个刻度初始化刻度，即 ..., -6, -3, 0, 3, 6, ...
    /// @return 每个价格变动的最大流动性
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    /// @notice 检索费用增长数据
    /// @param self 包含初始化刻度的所有刻度信息的映射
    /// @param tickLower 仓位的下刻度线边界
    /// @param tickUpper 仓位的上刻度线边界
    /// @param 当前刻度 当前刻度
    /// @param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长（以 token0 为单位）
    /// @param FeeGrowthGlobal1X128 历史上每单位流动性的全球费用增长（以 token1 为单位）
    /// @return FeeGrowthInside0X128 在头寸的报价范围内，每单位流动性的 token0 的历史费用增长
    /// @return FeeGrowthInside1X128 持仓变动范围内每单位流动性的代币 1 的历史费用增长
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // 计算下面的费用增长
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // 计算上面的费用增长
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /// @notice 更新刻度并在刻度从初始化翻转为未初始化时返回 true，反之亦然
    /// @param self 包含初始化刻度的所有刻度信息的映射
    /// @param 勾选 将要更新的勾选
    /// @param 当前刻度 当前刻度
    /// @param LiquidityDelta 当从左到右（从右到左）划过刻度线时要添加（减去）的新流动性数量
    /// @param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长（以 token0 为单位）
    /// @param FeeGrowthGlobal1X128 历史上每单位流动性的全球费用增长（以 token1 为单位）
    /// @param SecondsPerLiquidityCumulativeX128 池中每个 max(1, 流动性) 的所有时间秒数
    /// @param tickCumulative 自池首次初始化以来经过的tick * 时间
    /// @param time 当前块时间戳转换为 uint32
    /// @param upper true 用于更新仓位的上刻度线，或 false 用于更新仓位的下刻度线
    /// @param maxLiquidity 单笔报价的最大流动性分配
    /// @return Flipped 是否将刻度从已初始化翻转为未初始化，反之亦然
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // 按照惯例，我们假设在初始化蜱虫之前的所有增长都发生在蜱虫下方
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // 当下（上）刻度线从左到右（从右到左）交叉时，必须添加（去除）流动性
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    /// @notice 清除刻度数据
    /// @param self 包含初始化刻度的所有初始化刻度信息的映射
    /// @param 勾选 将被清除的勾选
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /// @notice 根据价格变动的需要过渡到下一个报价
    /// @param self 包含初始化刻度的所有刻度信息的映射
    /// @param 转场的目标刻度
    /// @param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长（以 token0 为单位）
    /// @param FeeGrowthGlobal1X128 历史上每单位流动性的全球费用增长（以 token1 为单位）
    /// @param SecondsPerLiquidityCumulativeX128 每个流动性的当前秒数
    /// @param tickCumulative 自池首次初始化以来经过的tick * 时间
    /// @param time 当前区块.timestamp
    /// @return LiquidityNet 从左到右（从右到左）划线时增加（减去）的流动性金额
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}
