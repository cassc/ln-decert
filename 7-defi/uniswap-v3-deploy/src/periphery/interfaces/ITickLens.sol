// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title 勾选镜头
/// @notice 提供为池获取刻度数据块的函数
/// @dev 这避免了获取刻度位图、解析位图以了解要获取哪些刻度以及
/// 然后发送额外的多重调用来获取刻度数据
interface ITickLens {
    struct PopulatedTick {
        int24 tick;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /// @notice 从池的刻度位图的一个字中获取已填充刻度的所有刻度数据
    /// @param pool 要获取填充的刻度数据的池的地址
    /// @param ticketBitmapIndex 刻度位图中要解析位图的单词的索引
    /// 获取所有已填充的刻度
    /// @return populatedTicks 刻度位图中给定字的刻度数据数组
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);
}
