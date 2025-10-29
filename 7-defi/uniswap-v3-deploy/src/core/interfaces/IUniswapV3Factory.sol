// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 Uniswap V3 Factory 的界面
/// @notice Uniswap V3 Factory 有助于创建 Uniswap V3 池并控制协议费用
interface IUniswapV3Factory {
    /// @notice 工厂所有者变更时发出
    /// 参数 oldOwner 所有者更改之前的所有者
    /// 参数 newOwner 所有者变更后的所有者
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice 创建池时发出
    /// 参数 token0 池中的第一个令牌（按地址排序顺序）
    /// 参数 token1 池中的第二个令牌（按地址排序顺序）
    /// 参数 费用 池中每次掉期收取的费用，以百分之一 BIP 计价
    /// 参数 tickSpacing 初始化刻度之间的最小刻度数
    /// 参数 pool 创建的池的地址
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    /// @notice 当通过工厂为池创建启用新的费用金额时发出
    /// 参数 费用 启用的费用，以百分之一 BIP 计价
    /// 参数 tickSpacing 使用给定费用创建的池的初始化刻度之间的最小刻度数
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice 返回工厂的当前所有者
    /// @dev 当前所有者可以通过 setOwner 进行更改
    /// 返回 工厂主的地址
    function owner() external view returns (address);

    /// @notice 如果启用，则返回给定费用金额的刻度间距；如果未启用，则返回 0
    /// @dev 费用金额永远无法删除，因此该值应该硬编码或缓存在调用上下文中
    /// 参数 费用 启用的费用，以百分之一 BIP 计价。如果未启用费用，则返回 0
    /// 返回 刻度间距
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice 返回给定代币对和费用的矿池地址，如果不存在则返回地址 0
    /// @dev tokenA 和 tokenB 可以按 token0/token1 或 token1/token0 的顺序传递
    /// 参数 tokenA token0或token1的合约地址
    /// 参数 tokenB 另一个代币的合约地址
    /// 参数 费用 池中每次掉期收取的费用，以百分之一 BIP 计价
    /// 返回 池 池地址
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /// @notice 为给定的两个代币和费用创建一个池
    /// 参数 tokenA 所需池中的两个代币之一
    /// 参数 tokenB 所需池中两个代币中的另一个
    /// 参数 费用 池所需的费用
    /// @dev tokenA 和 tokenB 可以按以下任一顺序传递：token0/token1 或 token1/token0。检索到刻度间距
    /// 从费用。如果池已存在、费用无效或令牌参数，则调用将恢复
    /// 均无效。
    /// 返回 pool 新创建的池的地址
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /// @notice 更新工厂的所有者
    /// @dev 必须由当前所有者调用
    /// 参数 _owner 工厂的新主人
    function setOwner(address _owner) external;

    /// @notice 启用具有给定tickSpacing的费用金额
    /// @dev 一旦启用，费用金额将永远不会被删除
    /// 参数 费用 启用的费用金额，以百分之一 BIP 计价（即 1e-6）
    /// 参数 tickSpacing 对于使用给定费用金额创建的所有池强制执行的刻度之间的间距
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
