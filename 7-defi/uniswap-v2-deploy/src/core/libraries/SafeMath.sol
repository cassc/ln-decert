// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

// 安全数学库，防止整数溢出
// 注意：Solidity 0.8.0+ 内置溢出检查，此库已不再必需
// 保留此文件仅为了与原始 Uniswap V2 代码保持一致
library SafeMath {
    // 安全加法 - 0.8.0+ 自动检查
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
    }

    // 安全减法 - 0.8.0+ 自动检查
    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y;
    }

    // 安全乘法 - 0.8.0+ 自动检查
    function mul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
    }
}
