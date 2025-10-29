// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import './IPeripheryPayments.sol';

/// 标题 周边支付
/// @notice 轻松存取 ETH 的功能
interface IPeripheryPaymentsWithFee is IPeripheryPayments {
    /// @notice 解开合约的 WETH9 余额并将其作为 ETH 发送给接收者，百分比介于
    /// 0（不包括）和 1（包括）将支付给收款人
    /// @dev amountMinimum 参数可防止恶意合约窃取用户的 WETH9。
    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    /// @notice 将本合约持有的代币全额转移给接收者，百分比介于
    /// 0（不包括）和 1（包括）将支付给收款人
    /// @dev amountMinimum 参数可防止恶意合约窃取用户的代币
    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;
}
