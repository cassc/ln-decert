// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title 多路通话接口
/// @notice 允许在一次调用合约中调用多个方法
interface IMulticall {
    /// @notice 调用当前合约中的多个函数，如果都成功则返回所有函数的数据
    /// @dev 对于可从多重调用调用的任何方法，不应信任“msg.value”。
    /// @param data 对此合约进行的每次调用的编码函数数据
    /// @return results 通过数据传入的每个调用的结果
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
