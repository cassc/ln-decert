// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// 标题 IERC20 元数据
/// 标题 ERC20元数据接口
/// @notice 包含代币元数据的 IERC20 扩展
interface IERC20Metadata is IERC20 {
    /// 返回 代币名称
    function name() external view returns (string memory);

    /// 返回 代币的符号
    function symbol() external view returns (string memory);

    /// 返回 令牌的小数位数
    function decimals() external view returns (uint8);
}
