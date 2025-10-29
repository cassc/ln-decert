// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Uniswap 的最小 ERC20 接口
/// @notice 包含 Uniswap V3 中使用的完整 ERC20 接口的子集
interface IERC20Minimal {
    /// @notice 返回代币余额
    /// @param account 要查找其拥有的代币数量的账户，即其余额
    /// @return 账户持有代币数量
    function balanceOf(address account) external view returns (uint256);

    /// @notice 将令牌数量从“msg.sender”转移到接收者
    /// @param 接收者 将接收转账金额的帐户
    /// @param amount 从发送者发送到接收者的令牌数量
    /// @return 转账成功返回 true，转账不成功返回 false
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice 返回所有者给予消费者的当前津贴
    /// @param 所有者 代币所有者的账户
    /// @param 花费者 代币花费者的账户
    /// @return 当前“所有者”授予“消费者”的津贴
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice 将支出者的津贴从“msg.sender”设置为值“amount”
    /// @param 支出者 允许花费一定数量的所有者代币的账户
    /// @param amount 允许“spender”使用的代币数量
    /// @return 审核成功返回 true，审核失败返回 false
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice 将“amount”代币从“sender”转移到“recipient”，最多可达“msg.sender”的限额
    /// @param 发送者 发起转账的账户
    /// @param 接收者 转账的接收者
    /// @param 金额 转账金额
    /// @return 转账成功返回 true，不成功返回 false
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice 当代币通过“#transfer”或“#transferFrom”从一个地址转移到另一个地址时发出事件。
    /// @param from 发送代币的账户，即余额减少
    /// @param to 代币发送到的账户，即余额增加
    /// @param value 已转移的代币数量
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice 当给定所有者代币的花费者的批准金额发生变化时发出事件。
    /// @param 所有者 批准支出其代币的账户
    /// @param 支出者 支出津贴被修改的账户
    /// @param value 所有者给消费者的新津贴
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
