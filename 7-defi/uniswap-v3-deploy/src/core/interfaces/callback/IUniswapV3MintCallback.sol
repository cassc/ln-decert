// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IUniswapV3PoolActions 的回调#mint
/// @notice 任何调用 IUniswapV3PoolActions#mint 的合约都必须实现此接口
interface IUniswapV3MintCallback {
    /// @notice 在将流动性从 IUniswapV3Pool#mint 铸造到某个位置后调用“msg.sender”。
    /// @dev 在实施过程中，您必须支付因铸造流动性而欠下的池代币。
    /// 必须检查此方法的调用者是否是规范 UniswapV3Factory 部署的 UniswapV3Pool。
    /// @param amount0Owed 铸造流动性池中的 token0 数量
    /// @param amount1Owed 铸造流动性池中的 token1 数量
    /// @param data 调用者通过 IUniswapV3PoolActions#mint 调用传递的任何数据
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
