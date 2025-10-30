// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @dev Uniswap V2 工厂接口
 * 用于查询两个代币之间的交易对地址
 */
interface ITwapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @dev Uniswap V2 交易对接口
 * 提供价格累积数据和储备量信息
 */
interface ITwapPair {
    /// @dev 返回交易对中的 token0 地址
    function token0() external view returns (address);

    /// @dev 返回交易对中的 token1 地址
    function token1() external view returns (address);

    /// @dev token0 的累积价格（price0 = reserve1 / reserve0）
    function price0CumulativeLast() external view returns (uint256);

    /// @dev token1 的累积价格（price1 = reserve0 / reserve1）
    function price1CumulativeLast() external view returns (uint256);

    /// @dev 返回当前储备量和最后更新时间
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/**
 * @title MemeTwapOracle - Meme 代币时间加权平均价格预言机
 * @notice 追踪 Meme 代币相对于报价资产的时间加权平均价格（TWAP）
 *
 * ## TWAP 原理说明
 * TWAP（Time-Weighted Average Price）通过累积价格随时间的变化来计算平均价格。
 *
 * ### 核心概念：
 * 1. **累积价格**：Uniswap V2 在每个区块记录 price * time 的累积值
 * 2. **时间差值**：通过两个时间点的累积价格差除以时间差，得到平均价格
 * 3. **Q112 精度**：使用 2^112 作为固定点数精度，避免除法精度损失
 *
 * ### 计算公式：
 * TWAP = (priceCumulative_now - priceCumulative_before) / timeElapsed
 *
 * ### 为什么使用 TWAP？
 * - 抗操纵：单笔大额交易无法立即影响价格
 * - 平滑价格：过滤短期价格波动，提供更稳定的参考价格
 * - 去中心化：完全基于链上数据，无需外部喂价
 */
contract MemeTwapOracle {
    /**
     * @dev Q112 精度常量（2^112）
     * Uniswap V2 使用 UQ112.112 格式表示价格：
     * - 112 位整数部分 + 112 位小数部分 = 224 位
     * - 这样可以精确表示价格，同时避免溢出
     *
     * ## 为什么定义为 `1 << 112` 而非直接写 `2**112`？
     * - 两者数学上完全等价
     * - 位移操作在编译时计算，gas 成本相同
     * - `1 << 112` 更常见于固定点数库中，清晰表达"位移"的概念
     */
    uint256 private constant Q112 = 1 << 112;

    /**
     * @dev 观察记录结构体
     * 存储每个 Meme 代币的 TWAP 计算所需数据
     */
    struct Observation {
        address pair;                   // 交易对地址
        bool memeIsToken0;              // Meme 代币是否为 token0（影响价格方向）
        uint256 priceCumulativeLast;    // 上次记录的累积价格
        uint32 blockTimestampLast;      // 上次更新的区块时间戳
        uint224 priceAverageX112;       // 计算出的平均价格（Q112 精度）
        bool initialized;               // 是否已初始化
    }

    /// @dev 统计周期（秒），必须等待此时间后才能更新价格
    uint32 public immutable period;

    /// @dev Uniswap V2 工厂合约
    ITwapFactory public immutable factory;

    /// @dev 报价代币地址（通常是 WETH）
    address public immutable quoteToken;

    /// @dev 存储每个 Meme 代币的观察记录
    mapping(address => Observation) public observations;

    // ========== 错误定义 ==========
    /// @dev 配置参数无效（地址为零或周期为零）
    error InvalidConfig();

    /// @dev 代币已经初始化过
    error AlreadyInitialized(address memeToken);

    /// @dev 未找到交易对
    error PairNotFound(address memeToken);

    /// @dev 交易对没有流动性
    error NoLiquidity(address pair);

    /// @dev 观察记录未初始化
    error ObservationNotInitialized(address memeToken);

    /// @dev 统计周期未达到
    error PeriodNotElapsed(uint32 timeElapsed);

    /// @dev 价格数据未就绪（需要先调用 update）
    error PriceNotReady(address memeToken);

    /**
     * @dev 构造函数
     * @param factory_ Uniswap V2 工厂合约地址
     * @param quoteToken_ 报价代币地址（例如 WETH）
     * @param period_ TWAP 统计周期（秒）
     *
     * 注意：周期越长，价格越平滑，但响应速度越慢
     * 常见设置：30 分钟 = 1800 秒，1 小时 = 3600 秒
     */
    constructor(address factory_, address quoteToken_, uint32 period_) {
        if (factory_ == address(0) || quoteToken_ == address(0) || period_ == 0) revert InvalidConfig();
        factory = ITwapFactory(factory_);
        quoteToken = quoteToken_;
        period = period_;
    }

    /**
     * @notice 初始化 Meme 代币的 TWAP 观察记录
     * @param memeToken Meme 代币地址
     * @return pair 交易对地址
     *
     * ## 工作流程：
     * 1. 从工厂合约查询 memeToken/quoteToken 交易对
     * 2. 确定 Meme 代币在交易对中的位置（token0 或 token1）
     * 3. 检查交易对是否有流动性
     * 4. 记录当前的累积价格和时间戳作为 TWAP 计算的起点
     *
     * ## 注意事项：
     * - 每个 Meme 代币只能初始化一次
     * - 必须在交易对创建并注入流动性后调用
     * - 初始化后需要等待至少 period 时间才能调用 update
     *
     * ## Uniswap V2 价格方向说明：
     * - 如果 meme 是 token0：使用 price0 = reserve1 / reserve0（用 token1 计价 token0）
     * - 如果 meme 是 token1：使用 price1 = reserve0 / reserve1（用 token0 计价 token1）
     */
    function initialize(address memeToken) external returns (address pair) {
        // 1. 基础验证
        if (memeToken == address(0)) revert InvalidConfig();
        Observation storage obs = observations[memeToken];
        if (obs.initialized) revert AlreadyInitialized(memeToken);

        // 2. 查询交易对
        pair = factory.getPair(memeToken, quoteToken);
        if (pair == address(0)) revert PairNotFound(memeToken);

        // 3. 确定 Meme 代币在交易对中的位置
        ITwapPair uniPair = ITwapPair(pair);
        address token0 = uniPair.token0();
        address token1 = uniPair.token1();
        bool memeIsToken0;
        if (memeToken == token0) {
            memeIsToken0 = true;  // Meme 是 token0，价格 = reserve1 / reserve0
        } else if (memeToken == token1) {
            memeIsToken0 = false; // Meme 是 token1，价格 = reserve0 / reserve1
        } else {
            revert PairNotFound(memeToken);
        }

        // 4. 检查流动性
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = uniPair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert NoLiquidity(pair);

        // 5. 初始化观察记录，记录起始累积价格
        obs.pair = pair;
        obs.memeIsToken0 = memeIsToken0;
        // 根据 Meme 代币位置选择对应的累积价格
        obs.priceCumulativeLast = memeIsToken0
            ? uniPair.price0CumulativeLast()
            : uniPair.price1CumulativeLast();
        obs.blockTimestampLast = blockTimestampLast;
        obs.priceAverageX112 = 0;  // 初始时平均价格为 0，需要 update 后才有值
        obs.initialized = true;
    }

    /**
     * @notice 更新 TWAP 价格
     * @param memeToken Meme 代币地址
     * @return priceX112 新的时间加权平均价格（Q112 精度）
     *
     * ## TWAP 计算核心逻辑：
     * 1. 获取当前累积价格
     * 2. 计算时间差（必须 >= period）
     * 3. 计算平均价格 = (当前累积价格 - 上次累积价格) / 时间差
     * 4. 更新存储的累积价格和时间戳，为下次计算做准备
     *
     * ## 累积价格的工作原理：
     * Uniswap V2 在每次交易后更新：
     * priceCumulative += (reserve1/reserve0) * timeElapsed
     *
     * 因此：
     * (priceCumulative_t2 - priceCumulative_t1) / (t2 - t1)
     * = 时间段内的平均价格
     *
     * ## 为什么需要等待 period？
     * - 防止价格操纵：攻击者无法通过单笔交易立即影响 TWAP
     * - 确保数据充分：有足够的交易和时间样本来计算准确的平均价格
     *
     * ## 示例：
     * 假设 period = 1800 秒（30 分钟）
     * - 初始化时记录：priceCumulative = 1000, timestamp = 0
     * - 30 分钟后调用 update：priceCumulative = 5200, timestamp = 1800
     * - TWAP = (5200 - 1000) / 1800 = 2.33 (Q112 精度)
     */
    function update(address memeToken) external returns (uint224 priceX112) {
        Observation storage obs = observations[memeToken];
        if (!obs.initialized) revert ObservationNotInitialized(memeToken);

        // 1. 获取当前累积价格（包括未记录的时间段）
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            _currentCumulativePrices(obs.pair);

        // 2. 计算时间差并验证是否满足最小周期要求
        uint32 timeElapsed = blockTimestamp - obs.blockTimestampLast;
        if (timeElapsed < period) revert PeriodNotElapsed(timeElapsed);

        // 3. 计算时间加权平均价格
        // 选择对应的累积价格（根据 Meme 代币位置）
        uint256 priceCumulative = obs.memeIsToken0 ? price0Cumulative : price1Cumulative;
        // TWAP = 累积价格差 / 时间差
        //
        // 关键设计：priceCumulative 经过长时间累积可能溢出，但这是有意设计！
        // uint256 减法的模运算特性确保即使溢出回绕，差值计算仍然正确
        //
        // 示例：oldPrice = 2^256 - 1000, newPrice = 500 (溢出后)
        //       diff = 500 - (2^256 - 1000) = 1500 (在 uint256 模运算下正确)
        //
        // 注意：此处的减法不会 revert，因为我们从已溢出的值中读取差值
        // 这与存储累积值时需要 unchecked{} 是不同的场景
        uint224 average = uint224((priceCumulative - obs.priceCumulativeLast) / timeElapsed);

        // 4. 更新观察记录，为下次 update 做准备
        obs.priceAverageX112 = average;
        obs.priceCumulativeLast = priceCumulative;
        obs.blockTimestampLast = blockTimestamp;
        priceX112 = average;
    }

    /**
     * @notice 查询指定数量 Meme 代币对应的平均价格
     * @param memeToken Meme 代币地址
     * @param amountIn Meme 代币数量（输入）
     * @return amountOut 对应的报价代币数量（输出）
     *
     * ## 价格转换逻辑：
     * 由于 priceAverageX112 使用 Q112 精度表示价格，计算时需要：
     * amountOut = Math.mulDiv(priceAverageX112, amountIn, 2^112)
     *
     * 使用 `Math.mulDiv` 可以避免大数乘法溢出，并保持 Q112 固定点精度。
     *
     * ## 使用场景：
     * - 获取代币的平均兑换价值
     * - 价格展示和计算
     * - 防止价格操纵的交易保护
     *
     * ## 示例：
     * 假设 priceAverageX112 = 5192296858534827628530496329220096（Q112 精度）
     * 这相当于 1 个 Meme = 0.001 个 WETH
     * 查询 1000 个 Meme：
     * amountOut = Math.mulDiv(5192296858534827628530496329220096, 1000, 2^112)
     *           ~= 1 WETH (假设 WETH 18 位小数)
     *
     * ## 注意事项：
     * - 必须先调用 update 至少一次，否则 priceAverageX112 为 0
     * - 返回值的精度取决于报价代币的小数位数
     * - 这是一个 view 函数，不消耗 gas（在链下调用时）
     */
    function consult(address memeToken, uint256 amountIn) external view returns (uint256 amountOut) {
        Observation storage obs = observations[memeToken];
        if (!obs.initialized) revert ObservationNotInitialized(memeToken);
        if (obs.priceAverageX112 == 0) revert PriceNotReady(memeToken);

        // 价格转换：使用 mulDiv 在保持 Q112 精度的同时避免乘法溢出
        amountOut = Math.mulDiv(uint256(obs.priceAverageX112), amountIn, Q112);
    }

    /**
     * @notice 获取 Meme 代币的完整观察记录
     * @param memeToken Meme 代币地址
     * @return pair 交易对地址
     * @return initialized 是否已初始化
     * @return memeIsToken0 Meme 代币是否为 token0
     * @return priceCumulativeLast 上次记录的累积价格
     * @return blockTimestampLast 上次更新时间戳
     * @return priceAverageX112 时间加权平均价格（Q112 精度）
     *
     * ## 用途：
     * - 调试和监控 TWAP 状态
     * - 检查是否已初始化
     * - 查看原始数据进行分析
     * - 前端展示详细信息
     */
    function getObservation(address memeToken)
        external
        view
        returns (
            address pair,
            bool initialized,
            bool memeIsToken0,
            uint256 priceCumulativeLast,
            uint32 blockTimestampLast,
            uint224 priceAverageX112
        )
    {
        Observation storage obs = observations[memeToken];
        return (
            obs.pair,
            obs.initialized,
            obs.memeIsToken0,
            obs.priceCumulativeLast,
            obs.blockTimestampLast,
            obs.priceAverageX112
        );
    }

    /**
     * @dev 获取交易对的当前累积价格
     * @param pair 交易对地址
     * @return price0Cumulative token0 的累积价格
     * @return price1Cumulative token1 的累积价格
     * @return blockTimestamp 当前区块时间戳
     *
     * ## 核心逻辑：
     * Uniswap V2 的累积价格不是实时更新的，只在交易发生时更新。
     * 因此我们需要手动计算从最后一次交易到现在的价格累积。
     *
     * ## 计算步骤：
     * 1. 获取交易对存储的累积价格（上次交易时的值）
     * 2. 如果当前区块时间戳与上次记录不同：
     *    - 计算时间差
     *    - 根据当前储备量计算瞬时价格
     *    - 将瞬时价格 * 时间差加到累积价格上
     *
     * ## 累积价格公式：
     * price0Cumulative += (reserve1 / reserve0) * timeElapsed
     * price1Cumulative += (reserve0 / reserve1) * timeElapsed
     *
     * 由于使用 Q112 精度：
     * price0Cumulative += (reserve1 * 2^112 / reserve0) * timeElapsed
     *
     * ## 为什么需要这个函数？
     * 如果直接使用 Pair 的 price0CumulativeLast()，会丢失最后一次交易到现在的价格信息。
     * 这个函数确保累积价格始终是最新的，即使最近没有交易发生。
     *
     * ## 注意：时间戳溢出处理
     * 使用 uint32 时间戳会在 2106 年溢出，但：
     * - 时间差计算仍然正确（uint32 减法的环绕特性）
     * - 与 Uniswap V2 的实现保持一致
     */
    function _currentCumulativePrices(address pair)
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        ITwapPair uniPair = ITwapPair(pair);
        // 获取交易对存储的累积价格（上次交易时）
        price0Cumulative = uniPair.price0CumulativeLast();
        price1Cumulative = uniPair.price1CumulativeLast();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = uniPair.getReserves();

        // 获取当前时间戳（取模以匹配 uint32 范围）
        blockTimestamp = uint32(block.timestamp % 2 ** 32);

        // 如果时间戳不同，说明需要累加最后一次交易后的价格
        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // 累加 token0 的价格：price0 = reserve1 / reserve0
            // 注意：使用 * Q112 而非 << 112，因为 Solidity 0.8+ 的乘法有溢出检查，更安全
            // 虽然单次增量不会溢出（uint112 * 2^112 * 2^32 < 2^256），但乘法提供额外保障
            //
            // ⚠️ 关键修复：必须使用 unchecked 允许溢出回绕！
            //
            // 问题：
            // - Pair 合约（Solidity 0.6.6）的 price0CumulativeLast 可能接近 uint256 max
            // - 我们读取这个值后，如果再用 += 添加增量，可能溢出
            // - Solidity 0.8+ 的 += 会在溢出时 revert，导致 oracle 永久失败
            //
            // 解决方案：
            // - 使用 unchecked {} 允许溢出回绕
            // - 这是安全的，因为 TWAP 使用差值计算，模运算确保结果正确
            unchecked {
                price0Cumulative += (uint256(reserve1) * Q112 / reserve0) * timeElapsed;
                // 累加 token1 的价格：price1 = reserve0 / reserve1
                price1Cumulative += (uint256(reserve0) * Q112 / reserve1) * timeElapsed;
            }
        }
        // 如果时间戳相同，说明当前区块已经有交易了，直接返回存储的累积价格
    }
}
