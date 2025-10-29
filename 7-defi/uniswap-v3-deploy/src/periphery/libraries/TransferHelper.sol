// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {
    /// @notice 将代币从目标地址转移到给定目的地
    /// @notice 如果传输失败，则会出现“STF”错误
    /// 参数 token 待转账代币的合约地址
    /// 参数 from 代币转账的起始地址
    /// 参数 to 传输的目的地址
    /// 参数 value 要转账的金额
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice 将令牌从 msg.sender 转移到收件人
    /// @dev 如果传输失败，ST 会出错
    /// 参数 token 将要转账的token合约地址
    /// 参数 至转账接收人
    /// 参数 价值 转移的价值
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice 批准规定的合同，以给定的代币花费给定的津贴
    /// @dev 如果传输失败，则会出现“SA”错误
    /// 参数 token 待审批token的合约地址
    /// 参数 至 审批目标
    /// 参数 value 允许目标花费的给定代币的金额
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice 将 ETH 转入收款人地址
    /// @dev 因“STE”失败
    /// 参数 至 转乘目的地
    /// 参数 value 要传输的值
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}
