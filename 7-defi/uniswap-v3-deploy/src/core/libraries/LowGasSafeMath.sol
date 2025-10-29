// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;

/// @title 优化的溢出和下溢安全数学运算
/// @notice 包含进行数学运算的方法，这些运算可以在溢出或下溢时恢复，以最小的天然气成本
library LowGasSafeMath {
    /// @notice 返回 x + y，如果总和溢出则恢复 uint256
    /// @param x 被加数
    /// @param y 加数
    /// @return z x 和 y 之和
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice 返回 x - y，如果下溢则恢复
    /// @param x 被减数
    /// @param y 减数
    /// @return z x 和 y 之差
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice 返回 x * y，如果溢出则恢复
    /// @param x 被乘数
    /// @param y 乘数
    /// @return z x 和 y 的乘积
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice 返回 x + y，如果上溢或下溢则恢复
    /// @param x 被加数
    /// @param y 加数
    /// @return z x 和 y 之和
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice 返回 x - y，如果上溢或下溢则恢复
    /// @param x 被减数
    /// @param y 减数
    /// @return z x 和 y 之差
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }
}
