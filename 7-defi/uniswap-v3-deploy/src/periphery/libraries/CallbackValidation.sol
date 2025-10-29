// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import './PoolAddress.sol';

/// @notice 为来自 Uniswap V3 池的回调提供验证
library CallbackValidation {
    /// @notice 返回有效 Uniswap V3 池的地址
    /// @param 工厂 Uniswap V3 工厂的合约地址
    /// @param tokenA token0或token1的合约地址
    /// @param tokenB 另一个代币的合约地址
    /// @param 费用 池中每次掉期收取的费用，以百分之一 BIP 计价
    /// @return pool V3池合约地址
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /// @notice 返回有效 Uniswap V3 池的地址
    /// @param 工厂 Uniswap V3 工厂的合约地址
    /// @param poolKey V3池的识别键
    /// @return pool V3池合约地址
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}
