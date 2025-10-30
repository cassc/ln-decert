// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";
import {MemeTwapOracle} from "../src/MemeTwapOracle.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    mapping(address => mapping(address => address)) private _pairs;
    address[] private _allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(_pairs[tokenA][tokenB] == address(0), "PAIR_EXISTS");

        pair = address(new MockPair(tokenA, tokenB));
        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
        _allPairs.push(pair);

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        emit PairCreated(token0, token1, pair, _allPairs.length);
    }

    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        pair = _pairs[tokenA][tokenB];
    }
}

contract MockPair {
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    constructor(address tokenA, address tokenB) {
        (address _token0, address _token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        token0 = _token0;
        token1 = _token1;
    }

    /// @dev 用于测试：手动设置累积价格为接近 uint256 max 的值
    function setCumulativePricesNearMax(uint256 price0, uint256 price1) external {
        price0CumulativeLast = price0;
        price1CumulativeLast = price1;
    }

    function mint(address) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        require(amount0 > 0 && amount1 > 0, "NO_LIQUIDITY_ADDED");
        liquidity = _sqrt(amount0 * amount1);
        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        require(data.length == 0, "UNSUPPORTED_DATA");
        require(amount0Out > 0 || amount1Out > 0, "ZERO_OUTPUT");

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > (_reserve0 - amount0Out) ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > (_reserve1 - amount1Out) ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT");

        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * 1_000_000,
            "K_INVARIANT"
        );

        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "BALANCE_OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 注意：与真实的 Uniswap V2 Pair 一样，必须使用 unchecked 允许溢出
            // 这是 TWAP 设计的关键部分
            unchecked {
                price0CumulativeLast += ((uint256(_reserve1) << 112) / _reserve0) * timeElapsed;
                price1CumulativeLast += ((uint256(_reserve0) << 112) / _reserve1) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract MemeTwapOracleTest is Test {
    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant PER_MINT = 1_000 ether;
    uint256 internal constant PRICE = 1 ether;
    uint32 internal constant PERIOD = 15 minutes;
    uint256 internal constant Q112 = 1 << 112;

    address internal constant TREASURY = address(1);
    address internal constant ISSUER = address(2);

    MemeFactory internal memeFactory;
    MemeToken internal meme;
    TestERC20 internal weth;
    MockFactory internal mockFactory;
    MemeTwapOracle internal oracle;
    MockPair internal pair;
    bool internal memeIsToken0;

    function setUp() public {
        vm.warp(1_000_000);

        mockFactory = new MockFactory();
        memeFactory = new MemeFactory(TREASURY, address(123));
        weth = new TestERC20("Mock WETH", "mWETH");

        vm.prank(ISSUER);
        address memeAddr = memeFactory.deployMeme("MEME", TOTAL_SUPPLY, PER_MINT, PRICE);
        meme = MemeToken(memeAddr);

        address pairAddr = mockFactory.createPair(address(meme), address(weth));
        pair = MockPair(pairAddr);
        memeIsToken0 = pair.token0() == address(meme);

        uint256 memeLiquidity = 40_000 ether;
        uint256 wethLiquidity = 400 ether;

        _mintMeme(address(this), 60_000 ether);
        meme.transfer(pairAddr, memeLiquidity);
        weth.mint(address(this), 1_000 ether);
        weth.transfer(pairAddr, wethLiquidity);

        pair.mint(address(this));

        oracle = new MemeTwapOracle(address(mockFactory), address(weth), PERIOD);
        oracle.initialize(address(meme));
    }

    function testConsultAfterMultipleTrades() public {
        (, , , uint256 baseCumulative, uint32 baseTimestamp, ) = oracle.getObservation(address(meme));

        vm.warp(block.timestamp + 5 minutes);
        _swapWethForMeme(address(this), 50 ether, address(this));

        vm.warp(block.timestamp + 8 minutes);
        _swapMemeForWeth(address(this), 5_000 ether, address(this));

        vm.warp(block.timestamp + 10 minutes);
        uint224 priceX112 = oracle.update(address(meme));

        uint256 pricePerMeme = oracle.consult(address(meme), 1 ether);

        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = _currentCumulativePrices();
        uint256 priceCumulative = memeIsToken0 ? price0Cumulative : price1Cumulative;
        uint32 elapsed = blockTimestamp - baseTimestamp;
        uint224 expectedX112 = uint224((priceCumulative - baseCumulative) / elapsed);

        assertEq(priceX112, expectedX112, "stored TWAP should match cumulative delta");

        uint256 expectedPrice = Math.mulDiv(uint256(expectedX112), 1 ether, Q112);
        assertEq(pricePerMeme, expectedPrice, "consult output should match expected TWAP");
    }

    function testConsultBeforeUpdateReverts() public {
        vm.expectRevert(abi.encodeWithSelector(MemeTwapOracle.PriceNotReady.selector, address(meme)));
        oracle.consult(address(meme), 1 ether);
    }

    function testUpdateNeedsWaitingPeriod() public {
        vm.expectRevert(abi.encodeWithSelector(MemeTwapOracle.PeriodNotElapsed.selector, 0));
        oracle.update(address(meme));
    }

    /// @notice 测试累积价格溢出边缘情况
    /// @dev 这个测试验证当 Pair 的累积价格接近 uint256 max 时，oracle 仍能正常工作
    ///      如果没有使用 unchecked {}，这个测试会 revert
    function testCumulativePriceOverflow() public {
        // 1. 设置 Pair 的累积价格为接近 uint256 max
        //    模拟一个已经运行数年的 Pair
        uint256 nearMax = type(uint256).max - 1e30; // 留一些空间用于增量
        pair.setCumulativePricesNearMax(nearMax, nearMax);

        // 2. 进行一些交易，让时间流逝
        vm.warp(block.timestamp + 5 minutes);
        _swapWethForMeme(address(this), 10 ether, address(this));

        // 3. 等待足够时间后更新 oracle
        vm.warp(block.timestamp + PERIOD);

        // 4. 如果没有 unchecked {}，下面的调用会 revert
        //    因为 _currentCumulativePrices 中的 += 会溢出
        uint224 priceX112 = oracle.update(address(meme));

        // 5. 验证价格被正确计算
        assertGt(priceX112, 0, "TWAP should be calculated even with overflow");

        // 6. 验证 consult 也能正常工作
        uint256 priceForOne = oracle.consult(address(meme), 1 ether);
        assertGt(priceForOne, 0, "consult should work with overflowed cumulative price");
    }

    /// @notice 测试累积价格完全溢出回绕的情况
    /// @dev 测试当累积价格溢出并回绕到小值时，差值计算仍然正确
    function testCumulativePriceCompleteOverflow() public {
        // 1. 计算本次 swap 将累积的价格增量，并设置 nearMax 以确保下一次累加必然溢出
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint32 elapsed = PERIOD + 1;

        // price0Increment 使用 reserve1/reserve0 -> (WETH / Meme)，因为 reserve1 远小于 reserve0，所以增量极小
        // price1Increment 使用 reserve0/reserve1 -> (Meme / WETH)，因为 reserve0 远大于 reserve1，所以增量极大
        // 真实环境中也是如此：累积 price1（用 WETH 计 Meme 的价格）增长更快，更容易溢出
        uint256 price0Increment = (uint256(reserve1) << 112) / reserve0;
        uint256 price1Increment = (uint256(reserve0) << 112) / reserve1;

        price0Increment *= elapsed;
        price1Increment *= elapsed;

        // nearMax = 2^256 - price1Increment + 1: 下一次加上 price1Increment 必然回绕
        // price0Increment 很小，加上 nearMax 仍在范围内，因此只会有 price1 溢出
        uint256 nearMax = type(uint256).max - price1Increment + 1;
        pair.setCumulativePricesNearMax(nearMax, nearMax);

        // 2. 足够的时间和交易，让累积价格溢出回绕
        vm.warp(block.timestamp + elapsed);
        _swapWethForMeme(address(this), 50 ether, address(this));

        // 溢出后累积价格应与期望相符（price1 将回绕，price0 仍在 range 内，模拟真实 Uniswap 行为）
        uint256 expectedC0;
        uint256 expectedC1;
        bool overflow0;
        bool overflow1;
        unchecked {
            expectedC0 = nearMax + price0Increment;
            overflow0 = expectedC0 < nearMax;
            expectedC1 = nearMax + price1Increment;
            overflow1 = expectedC1 < nearMax;
        }

        assertTrue(overflow1, "price1 cumulative should overflow");
        assertFalse(overflow0, "price0 cumulative should stay within range");
        assertEq(pair.price0CumulativeLast(), expectedC0, "cumulative price0 should follow wrap logic");
        assertEq(pair.price1CumulativeLast(), expectedC1, "cumulative price1 should wrap to expected value");

        // 3. 此时 Pair 的累积价格可能已经溢出回绕到小值
        // 但我们的 oracle 应该能正确处理这种情况
        uint224 priceX112 = oracle.update(address(meme));

        // 4. 价格应该是合理的正值
        assertGt(priceX112, 0, "TWAP should handle overflow wraparound"); 

        // 5. 验证可以继续使用
        vm.warp(block.timestamp + PERIOD);
        _swapMemeForWeth(address(this), 1000 ether, address(this));

        uint224 priceX112Second = oracle.update(address(meme));
        assertGt(priceX112Second, 0, "Should continue working after overflow");
    }

    function _swapWethForMeme(address trader, uint256 amountIn, address recipient) internal returns (uint256 amountOut) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        vm.startPrank(trader);
        if (memeIsToken0) {
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
            weth.transfer(address(pair), amountIn);
            pair.swap(amountOut, 0, recipient, new bytes(0));
        } else {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
            weth.transfer(address(pair), amountIn);
            pair.swap(0, amountOut, recipient, new bytes(0));
        }
        vm.stopPrank();
    }

    function _swapMemeForWeth(address trader, uint256 amountIn, address recipient) internal returns (uint256 amountOut) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        vm.startPrank(trader);
        if (memeIsToken0) {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
            meme.transfer(address(pair), amountIn);
            pair.swap(0, amountOut, recipient, new bytes(0));
        } else {
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
            meme.transfer(address(pair), amountIn);
            pair.swap(amountOut, 0, recipient, new bytes(0));
        }
        vm.stopPrank();
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(amountIn > 0, "INSUFFICIENT_INPUT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function _currentCumulativePrices()
        private
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        blockTimestamp = uint32(block.timestamp % 2 ** 32);
        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // 测试辅助函数也需要 unchecked 来匹配实际行为
            unchecked {
                price0Cumulative += (uint256(reserve1) * Q112 / reserve0) * timeElapsed;
                price1Cumulative += (uint256(reserve0) * Q112 / reserve1) * timeElapsed;
            }
        }
    }

    function _mintMeme(address to, uint256 amount) internal {
        uint256 rounds = amount / PER_MINT;
        require(rounds * PER_MINT == amount, "amount not multiple of perMint");
        for (uint256 i = 0; i < rounds; i++) {
            vm.prank(address(memeFactory));
            meme.mint(to);
        }
    }
}
