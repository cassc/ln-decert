// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Router02} from "../../src/interfaces/IUniswapV2Router02.sol";

contract MockUniswapV2Router is IUniswapV2Router02 {
    address public immutable override WETH;

    uint256 public tokensPerEth; // 以 1e18 为精度的代币兑 ETH 比率

    address public lastLiquidityToken;
    uint256 public lastAmountToken;
    uint256 public lastAmountEth;
    uint256 public lastLiquidity;
    address public lastLiquidityRecipient;

    constructor(address weth_) {
        WETH = weth_;
    }

    function setTokensPerEth(uint256 newRate) external {
        tokensPerEth = newRate;
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 /* deadline */
    ) external payable override returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        require(amountTokenDesired >= amountTokenMin, "token slippage");
        require(msg.value >= amountETHMin, "eth slippage");

        IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);

        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = amountTokenDesired;

        lastLiquidityToken = token;
        lastAmountToken = amountToken;
        lastAmountEth = amountETH;
        lastLiquidity = liquidity;
        lastLiquidityRecipient = to;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view override returns (uint256[] memory amounts) {
        require(path.length == 2, "unsupported path");
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = (amountIn * tokensPerEth) / 1e18;
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external payable override returns (uint256[] memory amounts) {
        require(path.length == 2, "unsupported path");
        uint256 amountOut = (msg.value * tokensPerEth) / 1e18;
        require(amountOut >= amountOutMin, "insufficient output");

        IERC20(path[1]).transfer(to, amountOut);

        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = amountOut;
    }
}
