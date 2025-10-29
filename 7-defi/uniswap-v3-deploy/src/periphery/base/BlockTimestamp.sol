// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

/// @title 获取区块时间戳的函数
/// @dev 为测试而覆盖的基础合约
abstract contract BlockTimestamp {
    /// @dev 纯粹为了测试而重写的方法
    /// @return 当前区块时间戳
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
