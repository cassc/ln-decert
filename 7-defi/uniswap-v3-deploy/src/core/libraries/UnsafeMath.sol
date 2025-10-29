// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 不检查输入或输出的数学函数
/// @notice 包含执行常见数学函数但不执行任何上溢或下溢检查的方法
library UnsafeMath {
    /// @notice 返回 ceil(x / y)
    /// @dev 除以 0 具有未指定的行为，必须进行外部检查
    /// 参数 x 股息
    /// 参数 y 除数
    /// 返回 z 商，ceil(x / y)
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}
