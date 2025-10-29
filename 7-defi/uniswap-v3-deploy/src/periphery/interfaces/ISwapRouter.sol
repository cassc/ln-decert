// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title 路由器令牌交换功能
/// @notice 通过 Uniswap V3 交换代币的功能
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice 将一个代币的“amountIn”尽可能多地交换为另一种代币
    /// @param params 交换所需的参数，在 calldata 中编码为 `ExactInputSingleParams`
    /// @return amountOut 收到的代币数量
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice 沿指定路径将一个令牌的“amountIn”尽可能多地交换为另一个令牌
    /// @param params 多跳交换所需的参数，在 calldata 中编码为 `ExactInputParams`
    /// @return amountOut 收到的代币数量
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice 尽可能少地用一种代币交换另一种代币的“amountOut”
    /// @param params 交换所需的参数，在 calldata 中编码为 `ExactOutputSingleParams`
    /// @return amountIn 输入代币的金额
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice 沿指定路径尽可能少地用一个令牌交换另一个令牌的“amountOut”（相反）
    /// @param params 多跳交换所需的参数，在 calldata 中编码为 `ExactOutputParams`
    /// @return amountIn 输入代币的金额
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}
