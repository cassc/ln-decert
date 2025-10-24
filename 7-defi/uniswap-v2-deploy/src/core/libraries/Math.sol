// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

// 数学库，提供 Babylonian 平方根算法
library Math {
    // 返回两个数中的最小值
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // 使用 Babylonian 方法计算平方根
    // 这是一种迭代算法，快速收敛到准确值
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
