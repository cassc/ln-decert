// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 不可变状态
/// @notice 返回路由器不可变状态的函数
interface IPeripheryImmutableState {
    /// @return 返回 Uniswap V3 工厂的地址
    function factory() external view returns (address);

    /// @return 返回 WETH9 的地址
    function WETH9() external view returns (address);
}
