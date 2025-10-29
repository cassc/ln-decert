// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title TickLens 接口
/// @notice 提供针对某个池按字获取刻度数据块的函数
/// @dev 避免外部先获取位图、再解析决定要拿哪些刻度、再发多次调用的流程
interface ITickLens {
    struct PopulatedTick {
        int24 tick;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /// @notice 从某池的刻度位图的一个字中获取所有已填充刻度的数据
    /// @param pool 目标池地址
    /// @param tickBitmapIndex 刻度位图中要解析的字索引
    /// @return populatedTicks 给定字内所有已填充刻度的数据数组
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);
}
