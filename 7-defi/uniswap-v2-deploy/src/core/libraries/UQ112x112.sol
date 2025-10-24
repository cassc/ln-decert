// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

// UQ112x112 是一个定点数库，用于表示范围在 [0, 2^112 - 1] 的数字
// 编码为 uint224，精度为 112 位小数部分
// 用于价格累积器以防止溢出
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // 将 uint112 编码为 UQ112x112 格式
    // 参数: y - 要编码的数字
    // 返回: z - 编码后的 UQ112x112 数字（y * 2^112）
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 永不溢出
    }

    // 执行 UQ112x112 除以 uint112 的除法，返回 UQ112x112
    // 参数: x - UQ112x112 格式的被除数
    // 参数: y - uint112 格式的除数
    // 返回: z - UQ112x112 格式的商
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
