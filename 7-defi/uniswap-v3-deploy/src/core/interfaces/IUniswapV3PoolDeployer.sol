// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 能够部署 Uniswap V3 池的合约接口
/// @notice 构建池的合约必须实现此功能以将参数传递给池
/// @dev 这用于避免池合约中包含构造函数参数，从而导致初始化代码哈希
/// 池的值是恒定的，允许在链上廉价地计算池的 CREATE2 地址
interface IUniswapV3PoolDeployer {
    /// @notice 获取构建池时使用的参数，在池创建期间临时设置。
    /// @dev 由池构造函数调用以获取池的参数
    /// 返回工厂 工厂地址
    /// 返回 token0 按地址排序顺序的池中的第一个令牌
    /// 返回 token1 按地址排序顺序的池中的第二个令牌
    /// 返还费用 池中每次掉期收取的费用，以百分之二比值计价
    /// 返回tickSpacing 初始化刻度之间的最小刻度数
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        );
}
