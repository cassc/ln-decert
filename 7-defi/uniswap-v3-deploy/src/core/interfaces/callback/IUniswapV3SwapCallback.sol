// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 IUniswapV3PoolActions#swap 回调
/// @notice 任何调用 IUniswapV3PoolActions#swap 的合约都必须实现此接口
interface IUniswapV3SwapCallback {
    /// @notice 通过 IUniswapV3Pool#swap 执行交换后调用“msg.sender”。
    /// @dev 在实施中，您必须支付交换所欠的池代币。
    /// 必须检查此方法的调用者是否是规范 UniswapV3Factory 部署的 UniswapV3Pool。
    /// 如果没有交换代币，amount0Delta 和 amount1Delta 都可以为 0。
    /// 参数 amount0Delta 池已发送（负）或必须接收（正）的 token0 数量
    /// 交换结束。如果为正，则回调必须将一定数量的 token0 发送到池中。
    /// 参数 amount1Delta 池已发送（负）或必须接收（正）的 token1 数量
    /// 交换结束。如果为正，则回调必须将相应数量的 token1 发送到池中。
    /// 参数 data 调用者通过 IUniswapV3PoolActions#swap 调用传递的任何数据
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
