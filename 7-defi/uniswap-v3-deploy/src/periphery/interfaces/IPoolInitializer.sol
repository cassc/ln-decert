// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// 标题 创建并初始化 V3 池
/// @notice 提供创建和初始化池的方法（如有必要），以便与其他方法捆绑在一起
/// 要求池存在。
interface IPoolInitializer {
    /// @notice 如果不存在则创建一个新池，如果未初始化则初始化
    /// @dev 此方法可以通过 IMulticall 与其他方法捆绑，以针对池执行第一个操作（例如铸币）
    /// 参数 token0 矿池token0的合约地址
    /// 参数 token1 矿池token1的合约地址
    /// 参数 Fee 指定代币对的 v3 池的费用金额
    /// 参数 sqrtPriceX96 池的初始平方根价格，为 Q64.96 值
    /// 返回 pool 根据代币和费用对返回矿池地址，如果需要将返回新创建的矿池地址
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}
