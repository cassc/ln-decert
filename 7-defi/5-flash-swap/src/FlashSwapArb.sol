// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Callee} from "./interfaces/IUniswapV2Callee.sol";
import {UniswapV2Math} from "./UniswapV2Math.sol";

/// @notice 在两个 Uniswap V2 流动性池之间执行闪电交换，捕获价格差异进行套利
contract FlashSwapArb is IUniswapV2Callee {
    address public immutable owner;
    address transient expectedCallbackPair;

    event ArbitrageExecuted(
        address indexed initiator,
        address indexed pairBorrow,
        address indexed pairSwap,
        address tokenBorrow,
        uint256 amountBorrowed,
        uint256 profit
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice 启动闪电交换套利：从池子 A 借入代币，在池子 B 进行交易
    function startArbitrage(
        address pairBorrow,
        address pairSwap,
        address tokenBorrow,
        uint256 amount,
        address profitRecipient
    ) external onlyOwner {
        require(amount > 0, "AMOUNT_ZERO");
        require(pairBorrow != address(0) && pairSwap != address(0), "PAIR_ZERO");
        require(pairBorrow != pairSwap, "PAIR_DUPLICATE");
        require(profitRecipient != address(0), "RECIPIENT_ZERO");

        IUniswapV2Pair borrowPair = IUniswapV2Pair(pairBorrow);
        require(borrowPair.factory() != address(0), "INVALID_BORROW_PAIR");
        address token0 = borrowPair.token0();
        address token1 = borrowPair.token1();

        bool borrowTokenIs0 = tokenBorrow == token0;
        if (!borrowTokenIs0) {
            require(tokenBorrow == token1, "TOKEN_NOT_IN_PAIR");
        }
        address tokenPay = borrowTokenIs0 ? token1 : token0;

        // 确保在第二个池子中交换方向有效
        IUniswapV2Pair swapPair = IUniswapV2Pair(pairSwap);
        require(swapPair.factory() != address(0), "INVALID_SWAP_PAIR");
        require(
            tokenBorrow == swapPair.token0() || tokenBorrow == swapPair.token1(),
            "TOKEN_NOT_IN_SWAP"
        );
        require(
            tokenPay == swapPair.token0() || tokenPay == swapPair.token1(),
            "PAY_TOKEN_NOT_IN_SWAP"
        );

        require(expectedCallbackPair == address(0), "CALLBACK_PENDING");
        // 使用 transient 存储临时记录允许回调的交易对地址
        // 防止攻击者部署假的 pair 合约，伪造 calldata 中的 pairBorrow，然后直接调用 uniswapV2Call
        // 这样可以避免攻击者让 msg.sender 等于假 pair 从而绕过安全检查
        // 交易结束时该字段会自动清空，不影响下次套利操作
        expectedCallbackPair = pairBorrow;

        (uint112 reserve0, uint112 reserve1, ) = borrowPair.getReserves();
        uint112 reserveBorrowToken = borrowTokenIs0 ? reserve0 : reserve1;
        require(amount < reserveBorrowToken, "AMOUNT_EXCEEDS_LIQ");

        uint amount0Out = borrowTokenIs0 ? amount : 0;
        uint amount1Out = borrowTokenIs0 ? 0 : amount;
        borrowPair.swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(pairBorrow, pairSwap, tokenBorrow, tokenPay, profitRecipient, borrowTokenIs0)
        );
    }

    /// @inheritdoc IUniswapV2Callee
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        (
            address pairBorrow,
            address pairSwap,
            address tokenBorrow,
            address tokenPay,
            address profitRecipient,
            bool borrowTokenIs0
        ) = abi.decode(data, (address, address, address, address, address, bool));
        require(sender == address(this), "BAD_SENDER");
        address expectedPair = expectedCallbackPair;
        require(expectedPair != address(0) && msg.sender == expectedPair, "BAD_PAIR");
        // 再次验证 calldata 中的 pairBorrow，防止攻击者伪造 data 参数绕过校验
        require(pairBorrow == expectedPair, "PAIR_MISMATCH");
        expectedCallbackPair = address(0);

        uint256 amountBorrowed = borrowTokenIs0 ? amount0 : amount1;
        require(amountBorrowed > 0, "NO_BORROW");

        IUniswapV2Pair borrowPair = IUniswapV2Pair(pairBorrow);
        IUniswapV2Pair swapPair = IUniswapV2Pair(pairSwap);

        // 在池子 B 中将借入的代币换成另一种代币
        (uint112 reserveSwap0, uint112 reserveSwap1, ) = swapPair.getReserves();
        address swapToken0 = swapPair.token0();

        uint256 amountOut;
        if (tokenBorrow == swapToken0) {
            _safeTransfer(tokenBorrow, pairSwap, amountBorrowed);
            amountOut = UniswapV2Math.getAmountOut(amountBorrowed, reserveSwap0, reserveSwap1);
            swapPair.swap(0, amountOut, address(this), "");
        } else {
            _safeTransfer(tokenBorrow, pairSwap, amountBorrowed);
            amountOut = UniswapV2Math.getAmountOut(amountBorrowed, reserveSwap1, reserveSwap0);
            swapPair.swap(amountOut, 0, address(this), "");
        }

        require(amountOut > 0, "NO_OUTPUT");

        // 计算需要归还给池子 A 的另一种代币数量
        (uint112 reserveBorrow0, uint112 reserveBorrow1, ) = borrowPair.getReserves();
        uint256 amountToRepay;
        if (borrowTokenIs0) {
            amountToRepay = UniswapV2Math.getAmountIn(amountBorrowed, reserveBorrow1, reserveBorrow0);
        } else {
            amountToRepay = UniswapV2Math.getAmountIn(amountBorrowed, reserveBorrow0, reserveBorrow1);
        }

        require(amountOut > amountToRepay, "NO_PROFIT");

        _safeTransfer(tokenPay, pairBorrow, amountToRepay);

        uint256 profit = amountOut - amountToRepay;
        _safeTransfer(tokenPay, profitRecipient, profit);

        emit ArbitrageExecuted(
            profitRecipient,
            pairBorrow,
            pairSwap,
            tokenBorrow,
            amountBorrowed,
            profit
        );
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}
