// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 未存储的池状态
/// @notice 包含视图函数，以提供有关池的信息，这些信息是计算出来的，而不是存储在
/// 区块链。这里的函数可能具有可变的天然气成本。
interface IUniswapV3PoolDerivedState {
    /// @notice 返回当前区块时间戳中每个时间戳“secondsAgo”的累积报价和流动性
    /// @dev 要获得时间加权平均报价或范围内的流动性，您必须使用两个值来调用它，一个代表
    /// 一个周期的开始，另一个周期的结束。例如，要获取最后一小时的时间加权平均价格变动，
    /// 您必须使用秒数= [3600, 0] 来调用它。
    /// @dev 时间加权平均价格变动代表池子的几何时间加权平均价格，单位为
    /// 对 token1 / token0 的底 sqrt(1.0001) 进行对数。 TickMath 库可用于将刻度值转换为比率。
    /// @param SecondsAgos 从多久前应返回每个累计报价和流动性值
    /// @return tickCumulatives 从当前块时间戳开始的每个“SecondsAgos”的累积刻度值
    /// @return timesPerLiquidityCumulativeX128s 当前区块中每个“secondsAgos”的每个流动性范围内值的累计秒数
    /// 时间戳
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice 返回报价累积的快照、每个流动性的秒数以及报价范围内的秒数
    /// @dev 快照只能与职位存在期间拍摄的其他快照进行比较。
    /// 即，如果在第一次交易之间的整个期间内未持有头寸，则无法比较快照
    /// 拍摄快照并拍摄第二张快照。
    /// @param tickLower 范围的下刻度
    /// @param tickUpper 范围的上刻度
    /// @return tickCumulativeInside 该范围的刻度累加器的快照
    /// @return timesPerLiquidityInsideX128 该范围内每个流动性的秒数快照
    /// @return timesInside 该范围内每个流动性的秒数快照
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}
