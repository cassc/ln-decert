// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '../interfaces/IERC20Minimal.sol';

/// @title 转账助手
/// @notice 包含用于与 ERC20 代币交互的辅助方法，这些方法并不始终返回 true/false
library TransferHelper {
    /// @notice 将令牌从 msg.sender 转移到收件人
    /// @dev 在代币合约上调用转账，如果转账失败则 TF 出错
    /// @param token 将要转账的token合约地址
    /// @param 至转账接收人
    /// @param 价值 转移的价值
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');
    }
}
