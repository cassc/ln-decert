// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title 周边支付
/// @notice 轻松存取 ETH 的功能
interface IPeripheryPayments {
    /// @notice 解开合约的 WETH9 余额并将其作为 ETH 发送给接收者。
    /// @dev amountMinimum 参数可防止恶意合约窃取用户的 WETH9。
    /// @param amountMinimum 解包的 WETH9 的最低数量
    /// @param 接收者 接收 ETH 的地址
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    /// @notice 将此合约持有的任何 ETH 余额退还给“msg.sender”
    /// @dev 对于与薄荷捆绑或增加使用以太坊的流动性或精确的输出交换很有用
    /// 使用以太币作为输入金额
    function refundETH() external payable;

    /// @notice 将本合约持有的代币全额转移给接收者
    /// @dev amountMinimum 参数可防止恶意合约窃取用户的代币
    /// @param token 将被转移到“recipient”的代币的合约地址
    /// @param amountMinimum 转账所需的最小代币数量
    /// @param 接收者 令牌的目标地址
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;
}
