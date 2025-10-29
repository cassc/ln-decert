// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import './IMulticall.sol';
import './ISelfPermit.sol';
import './IPoolInitializer.sol';

/// @title V3迁移器
/// @notice 允许将流动性从 Uniswap v2 兼容货币对迁移到 Uniswap v3 池中
interface IV3Migrator is IMulticall, ISelfPermit, IPoolInitializer {
    struct MigrateParams {
        address pair; // the Uniswap v2-compatible pair
        uint256 liquidityToMigrate; // expected to be balanceOf(msg.sender)
        uint8 percentageToMigrate; // represented as a numerator over 100
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min; // must be discounted by percentageToMigrate
        uint256 amount1Min; // must be discounted by percentageToMigrate
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }

    /// @notice 通过燃烧 v2 流动性并为 v3 铸造新头寸，将流动性迁移到 v3
    /// @dev 滑点保护是通过“amount{0,1}Min”强制执行的，它应该是预期值的折扣
    /// v2流动性可以获得的最大v3流动性数量。对于迁移到的特殊情况
    /// 超出范围的位置，“amount{0,1}Min”可以设置为 0，强制该位置保持在范围之外
    /// @param params 迁移 v2 流动性所需的参数，在 calldata 中编码为“MigrateParams”
    function migrate(MigrateParams calldata params) external;
}
