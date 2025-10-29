// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3PoolDeployer.sol';

import './UniswapV3Pool.sol';

contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev 通过临时设置参数存储槽来部署具有给定参数的池，然后
    /// 部署池后清除它。
    /// @param 工厂 Uniswap V3 工厂的合约地址
    /// @param token0 池中的第一个令牌（按地址排序顺序）
    /// @param token1 池中的第二个令牌（按地址排序顺序）
    /// @param 费用 池中每次掉期收取的费用，以百分之一 BIP 计价
    /// @param tickSpacing 可用刻度之间的间距
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
