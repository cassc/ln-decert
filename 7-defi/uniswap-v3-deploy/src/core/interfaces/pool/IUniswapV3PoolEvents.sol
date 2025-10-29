// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 池发出的事件
/// @notice 包含池发出的所有事件
interface IUniswapV3PoolEvents {
    /// @notice 当第一次在池上调用 #initialize 时，由池仅发出一次
    /// @dev 在初始化之前，池不能发出铸造/燃烧/交换
    /// @param sqrtPriceX96 矿池的初始 sqrt 价格，为 Q64.96
    /// @param 池的初始价格，即池起始价格的对数基数1.0001
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice 当给定头寸铸造流动性时发出
    /// @param 发送者 铸造流动性的地址
    /// @param 所有者 头寸的所有者和任何铸造流动性的接收者
    /// @param tickLower 仓位的下刻度线
    /// @param tickUpper 仓位的上刻度
    /// @param amount 铸造到头寸范围的流动性数量
    /// @param amount0 铸造流动性需要多少 token0
    /// @param amount1 铸造流动性需要多少 token1
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice 当头寸所有者收取费用时发出
    /// @dev 当调用者选择不收取费用时，收集事件可能会发出为零 amount0 和 amount1
    /// @param 所有者 收取费用的职位的所有者
    /// @param tickLower 仓位的下刻度线
    /// @param tickUpper 仓位的上刻度
    /// @param amount0 收取的 token0 费用金额
    /// @param amount1 收取的 token1 费用金额
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice 当头寸的流动性被移除时发出
    /// @dev 不提取流动性头寸赚取的任何费用，该费用必须通过#collect 提取
    /// @param 所有者 流动性被移除的头寸的所有者
    /// @param tickLower 仓位的下刻度线
    /// @param tickUpper 仓位的上刻度
    /// @param amount 要移除的流动性数量
    /// @param amount0 提取的token0数量
    /// @param amount1 提取的token1数量
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice 由池针对 token0 和 token1 之间的任何交换发出
    /// @param sender 发起交换调用并接收回调的地址
    /// @param 接收者 接收交换输出的地址
    /// @param amount0 池中 token0 余额的增量
    /// @param amount1 池中 token1 余额的增量
    /// @param sqrtPriceX96 交换后池的 sqrt(price)，作为 Q64.96
    /// @param 流动性 互换后池子的流动性
    /// @param 勾选 互换后矿池价格的对数底数 1.0001
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice 由池针对 token0/token1 的任何闪烁发出
    /// @param sender 发起交换调用并接收回调的地址
    /// @param 接收者 从闪存接收令牌的地址
    /// @param amount0 刷入的token0数量
    /// @param amount1 闪现的 token1 数量
    /// @param paid0 为闪付支付的token0金额，可以超过amount0加上手续费
    /// @param paid1 为闪现支付的token1金额，可以超过amount1加上费用
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice 由池发出，用于增加可存储的观测值数量
    /// @dev 在将观察写入索引之前，observationCardinalityNext 不是观察基数
    /// 就在铸币/交换/销毁之前。
    /// @param ObservationCardinalityNextOld 下一个观察基数的前一个值
    /// @param ObservationCardinalityNextNew 下一个观察基数的更新值
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice 当矿池更改协议费用时发出
    /// @param FeeProtocol0Old token0 协议费用的先前值
    /// @param FeeProtocol1Old token1 协议费用的先前值
    /// @param FeeProtocol0New token0 协议费用的更新值
    /// @param FeeProtocol1New token1 协议费用的更新值
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice 当工厂主提取收取的协议费时发出
    /// @param sender 收取协议费用的地址
    /// @param 接收者 接收收取的协议费用的地址
    /// @param amount0 提取的 token0 协议费用金额
    /// @param amount0 提取的 token1 协议费用金额
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}
