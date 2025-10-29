// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IUniswapV3PoolActions 的回调#flash
/// @notice 任何调用 IUniswapV3PoolActions#flash 的合约都必须实现此接口
interface IUniswapV3FlashCallback {
    /// @notice 从 IUniswapV3Pool#flash 传输到接收者后调用“msg.sender”。
    /// @dev 在实现中，您必须向矿池偿还由闪存发送的代币以及计算出的费用金额。
    /// 必须检查此方法的调用者是否是规范 UniswapV3Factory 部署的 UniswapV3Pool。
    /// @param Fee0 闪存结束时 token0 中的费用金额
    /// @param Fee1 闪电结束时 token1 中的费用金额
    /// @param data 调用者通过 IUniswapV3PoolActions#flash 调用传递的任何数据
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
