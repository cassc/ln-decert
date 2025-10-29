// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 永远不会改变的池状态
/// @notice 这些参数对于池来说永远是固定的，即方法将始终返回相同的值
interface IUniswapV3PoolImmutables {
    /// @notice 部署池的合约，必须遵守 IUniswapV3Factory 接口
    /// 返回 合约地址
    function factory() external view returns (address);

    /// @notice 池中两个代币中的第一个，按地址排序
    /// 返回 代币合约地址
    function token0() external view returns (address);

    /// @notice 池中两个代币中的第二个，按地址排序
    /// 返回 代币合约地址
    function token1() external view returns (address);

    /// @notice 矿池费用以百分之一比普为单位，即 1e-6
    /// 返回 费用
    function fee() external view returns (uint24);

    /// @notice 池刻度间距
    /// @dev 刻度线只能以此值的倍数使用，最小为 1 并且始终为正值
    /// 例如：tickSpacing 为 3 意味着可以每隔 3 个刻度初始化刻度，即 ..., -6, -3, 0, 3, 6, ...
    /// 该值是 int24，以避免强制转换，即使它始终为正值。
    /// 返回 刻度间距
    function tickSpacing() external view returns (int24);

    /// @notice 可以使用范围内任何价格变动的头寸流动性的最大金额
    /// @dev 每个价格变动都会强制执行此参数，以防止流动性在任何时候溢出 uint128，并且
    /// 还可以防止使用超出范围的流动性来防止向池中添加范围内的流动性
    /// 返回 每个价格变动的最大流动性数量
    function maxLiquidityPerTick() external view returns (uint128);
}
