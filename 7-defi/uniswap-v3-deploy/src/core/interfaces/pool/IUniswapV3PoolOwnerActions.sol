// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 允许的池操作
/// @notice 包含只能由工厂所有者调用的池方法
interface IUniswapV3PoolOwnerActions {
    /// @notice 设置协议费用百分比的分母
    /// 参数 FeeProtocol0 池中 token0 的新协议费用
    /// 参数 FeeProtocol1 池中 token1 的新协议费用
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice 收取池中产生的协议费
    /// 参数 接收者 收取的协议费应发送到的地址
    /// 参数 amount0Requested 发送token0的最大数量，可以为0以仅在token1中收取费用
    /// 参数 amount1Requested 发送token1的最大数量，可以为0以仅在token0中收取费用
    /// 返回 amount0 以 token0 收取的协议费用
    /// 返回 amount1 以 token1 收取的协议费用
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
