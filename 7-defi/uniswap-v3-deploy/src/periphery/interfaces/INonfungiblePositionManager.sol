// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol';

import './IPoolInitializer.sol';
import './IERC721Permit.sol';
import './IPeripheryPayments.sol';
import './IPeripheryImmutableState.sol';

/// @title 仓位的不可替代代币
/// @notice 将 Uniswap V3 头寸包装在不可替代的代币接口中，允许它们进行转移
/// 并授权。
interface INonfungiblePositionManager is
    IPoolInitializer,
    IPeripheryPayments,
    IPeripheryImmutableState,
    IERC721Metadata,
    IERC721Enumerable,
    IERC721Permit
{
    /// @notice 当 NFT 头寸的流动性增加时发出
    /// @dev 铸造代币时也会发出
    /// @param tokenId 增加流动性的代币ID
    /// @param 流动性 NFT 头寸流动性增加的金额
    /// @param amount0 为增加流动性而支付的 token0 数量
    /// @param amount1 为增加流动性而支付的 token1 数量
    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice 当 NFT 头寸的流动性减少时发出
    /// @param tokenId 流动性减少的代币 ID
    /// @param 流动性 NFT 头寸流动性减少的金额
    /// @param amount0 造成流动性减少的 token0 数量
    /// @param amount1 导致流动性减少的 token1 数量
    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice 当为 NFT 仓位收集代币时发出
    /// @dev 由于四舍五入的原因，报告的金额可能不完全等于转移的金额
    /// @param tokenId 收集底层代币的代币 ID
    /// @param 接收者 接收所收集代币的账户地址
    /// @param amount0 已收取仓位欠下的 token0 金额
    /// @param amount1 所欠持仓的 token1 金额
    event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

    /// @notice 返回与给定令牌 ID 关联的位置信息。
    /// @dev 如果令牌 ID 无效，则抛出该异常。
    /// @param tokenId 代表仓位的代币ID
    /// @return nonce 许可证的随机数
    /// @return 运营商 批准支出的地址
    /// @return token0 特定池的 token0 的地址
    /// @return token1 特定池的 token1 的地址
    /// @return 费用 与矿池相关的费用
    /// @return tickLower 仓位变动范围的下限
    /// @return tickUpper 仓位的价格变动范围的上限
    /// @return 流动性 头寸的流动性
    /// @return FeeGrowthInside0LastX128 截至单个仓位最后一次操作的 token0 的费用增长
    /// @return FeeGrowthInside1LastX128 截至单个仓位最后一次操作的 token1 的费用增长
    /// @return tokensOwed0 上次计算时欠仓的 token0 的未收取金额
    /// @return tokensOwed1 截至上次计算的头寸未收取的 token1 金额
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice 创建一个包裹在 NFT 中的新头寸
    /// @dev 当池确实存在并初始化时调用此方法。请注意，如果池已创建但未初始化
    /// 方法不存在，即假设池已初始化。
    /// @param params 创建位置所需的参数，在 calldata 中编码为“MintParams”
    /// @return tokenId 代表铸造位置的代币 ID
    /// @return 流动性 该头寸的流动性金额
    /// @return amount0 代币0的数量
    /// @return amount1 代币1的数量
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice 增加头寸的流动性，由“msg.sender”支付代币
    /// @param params tokenId 正在增加流动性的代币 ID，
    /// amount0Desired 所需花费的 token0 数量，
    /// amount1Desired 所需花费的 token1 数量，
    /// amount0Min 花费的最小 token0 金额，用作滑点检查，
    /// amount1Min 花费的最小 token1 金额，用作滑点检查，
    /// 截止日期 必须包含交易才能使更改生效的时间
    /// @return 流动性 增加后的新流动性金额
    /// @return amount0 用于实现流动性的 token0 数量
    /// @return amount1 用于实现流动性的 token1 数量
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice 减少头寸的流动性并将其记入该头寸
    /// @param params tokenId 流动性减少的代币 ID，
    /// amount 流动性将减少的金额，
    /// amount0Min 应计入销毁流动性的 token0 的最小数量，
    /// amount1Min 应计入销毁流动性的 token1 的最小数量，
    /// 截止日期 必须包含交易才能使更改生效的时间
    /// @return amount0 持仓所欠代币中所占的 token0 金额
    /// @return amount1 持仓所欠代币中所占的 token1 金额
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice 向接收者收取特定职位所欠的最高金额的费用
    /// @param params tokenId 正在收集代币的 NFT 的 ID，
    /// 接收者 应接收代币的帐户，
    /// amount0Max 收集token0的最大数量，
    /// amount1Max 收集token1的最大数量
    /// @return amount0 以 token0 收取的费用金额
    /// @return amount1 以 token1 收取的费用金额
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice 销毁代币 ID，将其从 NFT 合约中删除。该代币必须具有0流动性并且所有代币
    /// 必须先收集。
    /// @param tokenId 正在销毁的代币ID
    function burn(uint256 tokenId) external payable;
}
