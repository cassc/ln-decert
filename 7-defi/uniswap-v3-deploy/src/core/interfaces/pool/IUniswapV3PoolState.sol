// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 可以改变的池状态
/// @notice 这些方法组成了池的状态，并且可以以任何频率（包括多次）改变
/// 每笔交易
interface IUniswapV3PoolState {
    /// @notice 池中的第 0 个存储槽存储许多值，并作为单一方法公开以节省 Gas
    /// 当外部访问时。
    /// @return sqrtPriceX96 矿池的当前价格，以 sqrt(token1/token0) Q64.96 值表示
    /// 池的当前刻度，即根据运行的最后一个刻度转换。
    /// 如果价格处于变动状态，则该值可能并不总是等于 SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96)
    /// 边界。
    /// ObservationIndex 最后写入的预言机观察的索引，
    /// 观察基数 当前存储在池中的最大观察数，
    /// ObservationCardinalityNext 下一个最大观察数，当观察时要更新。
    /// FeeProtocol 池中两种代币的协议费用。
    /// 编码为两个4位值，其中token1的协议费用移位4位，token0的协议费用移位4位
    /// 是低4位。用作掉期费用一小部分的分母，例如4 表示互换费用的 1/4。
    /// 已解锁 池当前是否锁定为可重入
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice 费用增长为 Q128.128 在池的整个生命周期内每单位流动性收取的 token0 费用
    /// @dev 该值可能会溢出 uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice 在池的整个生命周期内，每单位流动性收取的代币 1 费用为 Q128.128 的费用增长
    /// @dev 该值可能会溢出 uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice 欠协议的 token0 和 token1 的数量
    /// @dev 任一代币的协议费用永远不会超过 uint128 max
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice 资金池当前可用的流动性范围
    /// @dev 该值与所有报价的总流动性无关
    function liquidity() external view returns (uint128);

    /// @notice 查找有关池中特定蜱虫的信息
    /// @param 勾选要查找的勾选
    /// @return 流动性总计使用池的头寸流动性总额，无论是价格下跌还是
    /// 上面打勾，
    /// 当资金池价格穿过刻度线时，流动性净值有多少流动性变化，
    /// FeeGrowthOutside0X128 相对于 token0 中当前报价在报价另一侧的费用增长，
    /// FeeGrowthOutside1X128 相对于 token1 中当前报价在报价另一侧的费用增长，
    /// tickCumulativeOutside 从当前报价开始的报价另一侧的累计报价值
    /// SecondsPerLiquidityOutsideX128 当前报价在报价另一侧每个流动性花费的秒数，
    /// 秒数 在当前刻度线另一侧花费的秒数之外，
    /// 初始化 如果刻度已初始化，即流动性Gross 大于 0，则设置为 true，否则等于 false。
    /// 仅当刻度已初始化时（即，流动性总金额大于 0）才能使用外部值。
    /// 此外，这些值只是相对值，并且只能用于与之前的快照进行比较
    /// 一个特定的位置。
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice 返回 256 个打包刻度初始化的布尔值。请参阅 TickBitmap 了解更多信息
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice 通过位置键返回有关位置的信息
    /// @param key 位置的键是由所有者、tickLower 和tickUpper 组成的原像的哈希值
    /// @return _liquidity 头寸的流动资金量，
    /// 返回截至最后一次铸币/销毁/戳戳的价格范围内代币0的feeGrowthInside0LastX128费用增长，
    /// 返回截至最后一次铸币/销毁/戳戳的价格范围内代币 1 的 FeeGrowthInside1LastX128 费用增长，
    /// 返回 tokensOwed0 计算出的 token0 欠最后一次铸币/销毁/戳的位置的金额，
    /// 返回 tokensOwed1，计算出截至最后一次铸币/销毁/戳入位置所欠的 token1 数量
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice 返回有关特定观察索引的数据
    /// @param index 要获取的观察数组的元素
    /// @dev 您很可能希望使用 #observe() 而不是此方法来获取一段时间内的观察结果
    /// 之前，而不是在数组中的特定索引处。
    /// @return blockTimestamp 观察的时间戳，
    /// 返回tickCumulative，即tick乘以截至观察时间戳的池生命周期所经过的秒数，
    /// 返回 timesPerLiquidityCumulativeX128 截至观察时间戳的池生命周期内每个流动性范围内的秒数，
    /// 返回已初始化的观察是否已初始化并且值是否可以安全使用
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}
