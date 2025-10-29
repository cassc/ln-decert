// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/Tick.sol';

contract TickEchidnaTest {
    function checkTickSpacingToParametersInvariants(int24 tickSpacing) external pure {
        require(tickSpacing <= TickMath.MAX_TICK);
        require(tickSpacing > 0);

        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;

        uint128 maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing);

        // 围绕 0 刻度对称
        assert(maxTick == -minTick);
        // 正最大刻度
        assert(maxTick > 0);
        // 可分性
        assert((maxTick - minTick) % tickSpacing == 0);

        uint256 numTicks = uint256((maxTick - minTick) / tickSpacing) + 1;
        // 每个价格变动的最大流动性小于上限
        assert(uint256(maxLiquidityPerTick) * numTicks <= type(uint128).max);
    }
}
