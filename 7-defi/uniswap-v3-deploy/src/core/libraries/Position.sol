// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// 标题 位置
/// @notice 头寸代表所有者地址在下限和上限边界之间的流动性
/// @dev 头寸存储额外状态以跟踪该头寸所欠费用
library Position {
    // 为每个用户的位置存储的信息
    struct Info {
        // 该头寸拥有的流动性数量
        uint128 liquidity;
        // 截至上次更新流动性或所欠费用时，每单位流动性的费用增长
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // token0/token1 中欠仓位所有者的费用
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice 返回职位的信息结构，给定所有者和职位边界
    /// 参数 self 包含所有用户位置的映射
    /// 参数 所有者 仓位所有者的地址
    /// 参数 tickLower 仓位的下刻度线边界
    /// 参数 tickUpper 仓位的上刻度线边界
    /// 返回 给定所有者位置的位置信息结构体
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice 将累积费用记入用户的位置
    /// 参数 self 要更新的个人位置
    /// 参数 LiquidityDelta 头寸更新导致的资金池流动性变化
    /// 参数 FeeGrowthInside0X128 在头寸的报价范围内，每单位流动性的 token0 的历史费用增长
    /// 参数 FeeGrowthInside1X128 持仓变动范围内每单位流动性的代币 1 的历史费用增长
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); // disallow pokes for 0 liquidity positions
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        // 计算累计费用
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        // 更新位置
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // 溢出是可以接受的，必须在输入类型（uint128）之前提款。最大费用
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
