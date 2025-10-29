// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title 定点96
/// @notice 用于处理二进制定点数的库，请参阅 https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev 用于 SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
