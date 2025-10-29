// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 无需许可的池操作
/// @notice 包含任何人都可以调用的池方法
interface IUniswapV3PoolActions {
    /// @notice 设置池的初始价格
    /// @dev 价格表示为 sqrt(amountToken1/amountToken0) Q64.96 值
    /// @param sqrtPriceX96 池的初始 sqrt 价格为 Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice 为给定的接收者/tickLower/tickUpper 头寸增加流动性
    /// @dev 该方法的调用者收到 IUniswapV3MintCallback#uniswapV3MintCallback 形式的回调
    /// 他们必须支付流动性所欠的任何 token0 或 token1。 token0/token1 到期金额取决于
    /// ontickLower、tickUpper、流动性数量和当前价格。
    /// @param 接收者 将为其创建流动性的地址
    /// @param tickLower 添加流动性的头寸的下限价位
    /// @param tickUpper 添加流动性的头寸的上限
    /// @param amount 铸造的流动性数量
    /// @param data 应传递给回调的任何数据
    /// @return amount0 为铸造给定量的流动性而支付的 token0 的数量。匹配回调中的值
    /// @return amount1 为铸造给定量的流动性而支付的 token1 的数量。匹配回调中的值
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice 收集某个仓位所欠的代币
    /// @dev 不重新计算赚取的费用，这必须通过铸造或燃烧任何数量的流动性来完成。
    /// Collect 必须由仓位所有者调用。仅提取 token0 或仅 token1、请求的 amount0 或
    /// amount1Requested 可以设置为零。要撤回所欠的所有代币，调用者可以传递任何大于
    /// 实际欠下的代币，例如类型(uint128).max。所欠代币可能来自累积的掉期费用或消耗的流动性。
    /// @param 接收者 应接收所收取费用的地址
    /// @param tickLower 收取费用的仓位下限价位
    /// @param tickUpper 收费仓位的上限
    /// @param amount0Requested 应从所欠费用中提取多少 token0
    /// @param amount1Requested 应从所欠费用中提取多少 token1
    /// @return amount0 以 token0 收取的费用金额
    /// @return amount1 以 token1 收取的费用金额
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice 销毁发送者的流动性和该头寸所欠流动性的账户代币
    /// @dev 可用于通过调用金额为 0 来触发重新计算仓位所欠费用
    /// @dev 必须通过致电 #collect 单独收取费用
    /// @param tickLower 消耗流动性的头寸的下限
    /// @param tickUpper 消耗流动性的头寸的上限
    /// @param amount 要燃烧多少流动性
    /// @return amount0 发送给接收者的 token0 数量
    /// @return amount1 发送给接收者的 token1 数量
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice 将 token0 交换为 token1，或将 token1 交换为 token0
    /// @dev 该方法的调用者收到 IUniswapV3SwapCallback#uniswapV3SwapCallback 形式的回调
    /// @param 接收者 接收交换输出的地址
    /// @param ZeroForOne 交换方向，true表示token0到token1，false表示token1到token0
    /// @param amountSpecified 交换金额，隐式将交换配置为精确输入（正）或精确输出（负）
    /// @param sqrtPriceLimitX96 Q64.96 sqrt 价格限制。如果以零换一，价格不能低于这个
    /// 交换后的值。如果一换零，互换后价格不能大于这个值
    /// @param data 要传递给回调的任何数据
    /// @return amount0 池子 token0 余额的 delta，负数时精确，正数时最小
    /// @return amount1 池中token1余额的delta，负数时精确，正数时最小
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice 接收 token0 和/或 token1 并在回调中支付费用
    /// @dev 该方法的调用者收到 IUniswapV3FlashCallback#uniswapV3FlashCallback 形式的回调
    /// @dev 可用于通过调用按比例向当前范围内的流动性提供者捐赠基础代币
    /// 金额为 0{0,1} 并从回调中发送捐赠金额
    /// @param 接收者 将接收 token0 和 token1 金额的地址
    /// @param amount0 要发送的 token0 的数量
    /// @param amount1 要发送的 token1 的数量
    /// @param data 要传递给回调的任何数据
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice 增加该池将存储的价格和流动性观察的最大数量
    /// @dev 如果池中已经有一个observationCardinalityNext大于或等于，则此方法是无操作的
    /// 输入观察CardinalityNext。
    /// @param ObservationCardinalityNext 池要存储的所需最小观测值数量
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}
