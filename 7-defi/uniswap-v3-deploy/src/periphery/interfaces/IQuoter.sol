// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// 标题 报价者接口
/// @notice 支持引用精确输入或精确输出交换的计算金额
/// @dev 这些函数没有标记为视图，因为它们依赖于调用非视图函数并恢复
/// 来计算结果。它们的 Gas 效率也不高，不应该被称为链上的。
interface IQuoter {
    /// @notice 返回给定确切输入交换所收到的金额，而不执行交换
    /// 参数 path 交换的路径，即每个代币对和矿池费用
    /// 参数 amountIn 第一个要交换的代币数量
    /// 返回 amountOut 将收到的最后一个代币的金额
    function quoteExactInput(bytes memory path, uint256 amountIn) external returns (uint256 amountOut);

    /// @notice 返回给定确切输入但单个池交换时收到的金额
    /// 参数 tokenIn 被换入的代币
    /// 参数 tokenOut 被换出的 token
    /// 参数 费用 该货币对需要考虑的代币池费用
    /// 参数 amountIn 所需的输入金额
    /// 参数 sqrtPriceLimitX96 互换不能超过的池的价格限制
    /// 返回 amountOut 将收到的“tokenOut”数量
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    /// @notice 返回给定精确输出交换所需的金额，而不执行交换
    /// 参数 path 交换的路径，即每个代币对和矿池费用。路径必须以相反的顺序提供
    /// 参数 amountOut 最后收到的代币数量
    /// 返回 amountIn 需要支付的第一个代币金额
    function quoteExactOutput(bytes memory path, uint256 amountOut) external returns (uint256 amountIn);

    /// @notice 返回接收给定确切输出金额所需的金额，但对于单个池的交换
    /// 参数 tokenIn 被换入的代币
    /// 参数 tokenOut 被换出的 token
    /// 参数 费用 该货币对需要考虑的代币池费用
    /// 参数 amountOut 所需的输出金额
    /// 参数 sqrtPriceLimitX96 互换不能超过的池的价格限制
    /// 返回 amountIn 为接收“amountOut”而需要作为交换输入的金额
    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);
}
