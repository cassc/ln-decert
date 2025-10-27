// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/core/UniswapV2Factory.sol";
import "../src/core/UniswapV2Pair.sol";
import "../src/periphery/UniswapV2Router02.sol";
import "../src/test-tokens/WETH9.sol";
import "../src/test-tokens/MockERC20.sol";

/**
 * @title UniswapV2Test
 * @notice Uniswap V2 完整功能测试
 * @dev 测试覆盖：
 *      - 工厂合约：创建交易对
 *      - 流动性管理：添加、移除流动性
 *      - 代币交换：单跳、多跳交换
 *      - 价格计算：验证恒定乘积公式
 */
contract UniswapV2Test is Test {
    WETH9 public weth;
    MockERC20 public dai;
    MockERC20 public usdc;
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;

    uint256 internal alicePrivateKey;
    address public alice;
    address public bob = address(0x2);

    function setUp() public {
        // 初始化测试账户
        alicePrivateKey = 0xA11CE;
        alice = vm.addr(alicePrivateKey);

        // 部署代币
        weth = new WETH9();
        dai = new MockERC20("Dai Stablecoin", "DAI");
        usdc = new MockERC20("USD Coin", "USDC");

        // 部署 Uniswap V2
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(weth));

        // 给测试用户一些代币
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        dai.mint(alice, 100000 * 10**18);
        usdc.mint(alice, 100000 * 10**6);
        dai.mint(bob, 100000 * 10**18);
        usdc.mint(bob, 100000 * 10**6);
    }

    /**
     * @notice 测试：创建交易对
     */
    function testCreatePair() public {
        address pair = factory.createPair(address(dai), address(usdc));

        assertTrue(pair != address(0), "Pair should be created");
        assertEq(factory.getPair(address(dai), address(usdc)), pair);
        assertEq(factory.getPair(address(usdc), address(dai)), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    /**
     * @notice 测试：不能创建重复的交易对
     */
    function testCannotCreateDuplicatePair() public {
        factory.createPair(address(dai), address(usdc));

        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(dai), address(usdc));
    }

    /**
     * @notice 测试：添加流动性
     */
    function testAddLiquidity() public {
        vm.startPrank(alice);

        // 创建交易对
        factory.createPair(address(dai), address(usdc));

        // 授权
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        // 添加流动性
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,  // 10000 DAI
            10000 * 10**6,   // 10000 USDC
            0,
            0,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();

        assertEq(amountA, 10000 * 10**18, "Should add 10000 DAI");
        assertEq(amountB, 10000 * 10**6, "Should add 10000 USDC");
        assertTrue(liquidity > 0, "Should receive LP tokens");
    }

    /**
     * @notice 测试：在已有储备下添加流动性时使用最优数额
     */
    function testAddLiquidityOptimalRebalancesAmounts() public {
        vm.startPrank(alice);

        // 创建交易对并添加初始流动性（1:1 比例）
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dai),
            address(usdc),
            1000 * 10**18,
            1000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 再次添加流动性，但期望数量与池中比例不匹配
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(dai),
            address(usdc),
            2000 * 10**18,  // 期望投入更多的 DAI
            5000 * 10**6,   // 期望投入更多的 USDC
            1900 * 10**18,
            1900 * 10**6,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();

        assertTrue(liquidity > 0, "Should mint LP tokens");
        assertEq(amountA, 2000 * 10**18, "Router should consume full DAI amount");
        assertEq(amountB, 2000 * 10**6, "Router should scale USDC down to match pool ratio");
    }

    /**
     * @notice 测试：添加 ETH 流动性
     */
    function testAddLiquidityETH() public {
        vm.startPrank(alice);

        // 创建交易对
        factory.createPair(address(weth), address(dai));

        // 授权 DAI
        dai.approve(address(router), type(uint256).max);

        // 添加 ETH-DAI 流动性
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 5 ether}(
            address(dai),
            10000 * 10**18,  // 10000 DAI
            0,
            0,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();

        assertEq(amountETH, 5 ether, "Should add 5 ETH");
        assertEq(amountToken, 10000 * 10**18, "Should add 10000 DAI");
        assertTrue(liquidity > 0, "Should receive LP tokens");
    }

    /**
     * @notice 测试：移除流动性
     */
    function testRemoveLiquidity() public {
        vm.startPrank(alice);

        // 创建交易对并添加流动性
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        (, , uint liquidity) = router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 移除流动性
        address pair = factory.getPair(address(dai), address(usdc));
        UniswapV2Pair(pair).approve(address(router), type(uint256).max);

        (uint amountA, uint amountB) = router.removeLiquidity(
            address(dai),
            address(usdc),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();

        assertTrue(amountA > 0, "Should receive DAI back");
        assertTrue(amountB > 0, "Should receive USDC back");
    }

    /**
     * @notice 测试：使用 permit 移除流动性
     */
    function testRemoveLiquidityWithPermit() public {
        vm.startPrank(alice);

        // 创建交易对并添加流动性
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        (, , uint liquidity) = router.addLiquidity(
            address(dai),
            address(usdc),
            5000 * 10**18,
            5000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();

        address pair = factory.getPair(address(dai), address(usdc));
        uint deadline = block.timestamp + 300;
        uint nonce = UniswapV2Pair(pair).nonces(alice);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                UniswapV2Pair(pair).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        UniswapV2Pair(pair).PERMIT_TYPEHASH(),
                        alice,
                        address(router),
                        liquidity,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.prank(alice);
        (uint amountA, uint amountB) = router.removeLiquidityWithPermit(
            address(dai),
            address(usdc),
            liquidity,
            0,
            0,
            alice,
            deadline,
            false,
            v,
            r,
            s
        );

        assertGt(amountA, 0, "Should receive DAI back");
        assertGt(amountB, 0, "Should receive USDC back");
        assertEq(UniswapV2Pair(pair).balanceOf(alice), 0, "LP balance should be cleared");
    }

    /**
     * @notice 测试：精确输入交换
     */
    function testSwapExactTokensForTokens() public {
        vm.startPrank(alice);

        // 创建并添加流动性
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 执行交换：1000 DAI -> USDC
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(usdc);

        uint256 usdcBefore = usdc.balanceOf(alice);

        router.swapExactTokensForTokens(
            1000 * 10**18,  // 输入 1000 DAI
            0,              // 接受任何数量的 USDC
            path,
            alice,
            block.timestamp + 300
        );

        uint256 usdcAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        assertTrue(usdcAfter > usdcBefore, "Should receive USDC");
        // 应该收到大约 906 USDC（考虑 0.3% 手续费和滑点）
        assertApproxEqRel(usdcAfter - usdcBefore, 906 * 10**6, 0.01e18); // 1% 容差
    }

    /**
     * @notice 测试：精确输出交换
     */
    function testSwapTokensForExactTokens() public {
        vm.startPrank(alice);

        // 创建并添加流动性
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 执行交换：DAI -> 精确 1000 USDC
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(usdc);

        uint256 daiBefore = dai.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);

        router.swapTokensForExactTokens(
            1000 * 10**6,   // 期望输出 1000 USDC
            type(uint256).max,  // 愿意支付任何数量的 DAI
            path,
            alice,
            block.timestamp + 300
        );

        uint256 daiAfter = dai.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        assertTrue(daiBefore > daiAfter, "Should spend DAI");
        uint256 usdcReceived = usdcAfter - usdcBefore;
        assertEq(usdcReceived, 1000 * 10**6, "Should receive exactly 1000 USDC");
    }

    /**
     * @notice 测试：多跳交换 (DAI -> WETH -> USDC)
     */
    function testMultihopSwap() public {
        vm.startPrank(alice);

        // 创建交易对
        factory.createPair(address(dai), address(weth));
        factory.createPair(address(weth), address(usdc));

        // 添加流动性
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidityETH{value: 10 ether}(
            address(dai),
            20000 * 10**18,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        router.addLiquidityETH{value: 10 ether}(
            address(usdc),
            20000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 多跳交换：DAI -> WETH -> USDC
        address[] memory path = new address[](3);
        path[0] = address(dai);
        path[1] = address(weth);
        path[2] = address(usdc);

        uint256 usdcBefore = usdc.balanceOf(alice);

        router.swapExactTokensForTokens(
            1000 * 10**18,  // 输入 1000 DAI
            0,
            path,
            alice,
            block.timestamp + 300
        );

        uint256 usdcAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        assertTrue(usdcAfter > usdcBefore, "Should receive USDC from multihop swap");
    }

    /**
     * @notice 测试：恒定乘积公式验证
     */
    function testConstantProduct() public {
        vm.startPrank(alice);

        // 创建并添加流动性
        address pair = factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 获取交换前的储备量
        (uint112 reserve0Before, uint112 reserve1Before,) = UniswapV2Pair(pair).getReserves();
        uint256 kBefore = uint256(reserve0Before) * uint256(reserve1Before);

        // 执行交换
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(usdc);

        router.swapExactTokensForTokens(
            1000 * 10**18,
            0,
            path,
            alice,
            block.timestamp + 300
        );

        // 获取交换后的储备量
        (uint112 reserve0After, uint112 reserve1After,) = UniswapV2Pair(pair).getReserves();
        uint256 kAfter = uint256(reserve0After) * uint256(reserve1After);

        vm.stopPrank();

        // k 值应该增加（因为有 0.3% 手续费）
        assertTrue(kAfter > kBefore, "k should increase due to fees");
    }

    /**
     * @notice 测试：滑点保护
     */
    function testSlippageProtection() public {
        vm.startPrank(alice);

        // 创建并添加流动性
        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // 尝试交换但设置过高的最小输出（应该失败）
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(usdc);

        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            1000 * 10**18,
            2000 * 10**6,  // 期望至少 2000 USDC（实际不可能）
            path,
            alice,
            block.timestamp + 300
        );

        vm.stopPrank();
    }

    /**
     * @notice 测试：deadline 保护
     */
    function testDeadlineProtection() public {
        vm.startPrank(alice);

        factory.createPair(address(dai), address(usdc));
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);

        // 使用过期的 deadline（应该失败）
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidity(
            address(dai),
            address(usdc),
            10000 * 10**18,
            10000 * 10**6,
            0,
            0,
            alice,
            block.timestamp - 1  // 已过期
        );

        vm.stopPrank();
    }
}
