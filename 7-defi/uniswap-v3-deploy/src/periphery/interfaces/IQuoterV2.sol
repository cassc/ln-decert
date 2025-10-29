// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// 标题 QuoterV2接口
/// @notice 支持引用精确输入或精确输出交换的计算金额。
/// @notice 对于每个池，还告诉您交叉的初始化刻度数以及交换后池的 sqrt 价格。
/// @dev 这些函数没有标记为视图，因为它们依赖于调用非视图函数并恢复
/// 来计算结果。它们的 Gas 效率也不高，不应该被称为链上的。
interface IQuoterV2 {
    /// @notice 返回给定确切输入交换所收到的金额，而不执行交换
    /// 参数 path 交换的路径，即每个代币对和矿池费用
    /// 参数 amountIn 第一个要交换的代币数量
    /// 返回 amountOut 将收到的最后一个代币的金额
    /// 返回 sqrtPriceX96AfterList 路径中每个池交换后的 sqrt 价格列表
    /// 返回 initializedTicksCrossedList 路径中每个池的交换交叉的初始化刻度列表
    /// 返回 gasEstimate 交换消耗的gas的估计
    function quoteExactInput(bytes memory path, uint256 amountIn)
        external
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );

    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice 返回给定确切输入但单个池交换时收到的金额
    /// 参数 params 报价的参数，编码为“QuoteExactInputSingleParams”
    /// tokenIn 被换入的代币
    /// tokenOut 被换出的 token
    /// 费用 该货币对需要考虑的代币池费用
    /// amountIn 所需的输入金额
    /// sqrtPriceLimitX96 互换不能超过的池的价格限制
    /// 返回 amountOut 将收到的“tokenOut”数量
    /// 返回 sqrtPriceX96After 交换后矿池的 sqrt 价格
    /// 返回 initializedTicksCrossed 交换跨越的初始化价格变动数
    /// 返回 gasEstimate 交换消耗的gas的估计
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );

    /// @notice 返回给定精确输出交换所需的金额，而不执行交换
    /// 参数 path 交换的路径，即每个代币对和矿池费用。路径必须以相反的顺序提供
    /// 参数 amountOut 最后收到的代币数量
    /// 返回 amountIn 需要支付的第一个代币金额
    /// 返回 sqrtPriceX96AfterList 路径中每个池交换后的 sqrt 价格列表
    /// 返回 initializedTicksCrossedList 路径中每个池的交换交叉的初始化刻度列表
    /// 返回 gasEstimate 交换消耗的gas的估计
    function quoteExactOutput(bytes memory path, uint256 amountOut)
        external
        returns (
            uint256 amountIn,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );

    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice 返回接收给定确切输出金额所需的金额，但对于单个池的交换
    /// 参数 params 报价的参数，编码为“QuoteExactOutputSingleParams”
    /// tokenIn 被换入的代币
    /// tokenOut 被换出的 token
    /// 费用 该货币对需要考虑的代币池费用
    /// amountOut 所需的输出金额
    /// sqrtPriceLimitX96 互换不能超过的池的价格限制
    /// 返回 amountIn 为接收“amountOut”而需要作为交换输入的金额
    /// 返回 sqrtPriceX96After 交换后矿池的 sqrt 价格
    /// 返回 initializedTicksCrossed 交换跨越的初始化价格变动数
    /// 返回 gasEstimate 交换消耗的gas的估计
    function quoteExactOutputSingle(QuoteExactOutputSingleParams memory params)
        external
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}
