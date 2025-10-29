// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../src/test-tokens/WETH9.sol";
import "../src/test-tokens/MockERC20.sol";

/**
 * 标题 UniswapV3BasicTest
 * @notice Uniswap V3 基础功能测试
 * @dev 测试核心 Factory 和 Pool 功能，不依赖 periphery 合约
 */
contract UniswapV3BasicTest is Test {
    WETH9 public weth;
    MockERC20 public dai;
    MockERC20 public usdc;
    UniswapV3Factory public factory;

    address public alice = address(0x1);
    address public bob = address(0x2);

    // 费率常量
    uint24 constant FEE_LOW = 500; // 0.05%
    uint24 constant FEE_MEDIUM = 3000; // 0.30%
    uint24 constant FEE_HIGH = 10000; // 1.00%

    // Tick 间距
    int24 constant TICK_SPACING_LOW = 10;
    int24 constant TICK_SPACING_MEDIUM = 60;
    int24 constant TICK_SPACING_HIGH = 200;

    // 初始化的 sqrtPriceX96（价格 1:1）
    // 设置初始价格建议：先确认 token0/token1 顺序，再按目标报价 P = token1/token0 选择合适 tick，
    // 使用 TickMath.getSqrtRatioAtTick 求得对应的 sqrtPriceX96，以避免手动换算误差
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function setUp() public {
        // 部署代币
        weth = new WETH9();
        dai = new MockERC20("Dai Stablecoin", "DAI");
        usdc = new MockERC20("USD Coin", "USDC");

        // 部署 Uniswap V3 Factory
        // 注意：Factory 构造函数已经启用了 500, 3000, 10000 这三个费率
        factory = new UniswapV3Factory();

        // 给测试用户一些代币
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        dai.mint(alice, 1000000 * 10 ** 18);
        usdc.mint(alice, 1000000 * 10 ** 6);
        dai.mint(bob, 1000000 * 10 ** 18);
        usdc.mint(bob, 1000000 * 10 ** 6);
    }

    /**
     * @notice 辅助函数：获取排序后的代币地址
     */
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }

    /**
     * @notice 测试：创建交易池
     */
    function testCreatePool() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        // 使用非标准费率创建池会失败
        vm.expectRevert();
        factory.createPool(token0, token1, 12);

        address pool = factory.createPool(token0, token1, FEE_MEDIUM);

        // 使用相同的代币对和费率再次创建池会失败
        vm.expectRevert();
        factory.createPool(token1, token0, FEE_MEDIUM);

        assertTrue(pool != address(0), "Pool should be created");
        assertEq(
            factory.getPool(token0, token1, FEE_MEDIUM),
            pool,
            "Forward mapping should return correct pool"
        );
        assertEq(
            factory.getPool(token1, token0, FEE_MEDIUM),
            pool,
            "Reverse mapping should return same pool"
        );
    }

    /**
     * @notice 测试：同一代币对可以创建多个不同费率的池
     */
    function testCreateMultiplePoolsWithDifferentFees() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        address poolLow = factory.createPool(token0, token1, FEE_LOW);
        address poolMedium = factory.createPool(token0, token1, FEE_MEDIUM);
        address poolHigh = factory.createPool(token0, token1, FEE_HIGH);

        assertTrue(poolLow != poolMedium, "Pools should be different");
        assertTrue(poolMedium != poolHigh, "Pools should be different");
        assertTrue(poolLow != poolHigh, "Pools should be different");
    }

    /**
     * @notice 测试：不能创建重复的池
     */
    function testCannotCreateDuplicatePool() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        factory.createPool(token0, token1, FEE_MEDIUM);

        vm.expectRevert();
        factory.createPool(token0, token1, FEE_MEDIUM);
    }

    /**
     * @notice 测试：初始化池子价格
     */
    function testInitializePool() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        address pool = factory.createPool(token0, token1, FEE_MEDIUM);
        IUniswapV3Pool(pool).initialize(SQRT_PRICE_1_1);

        // 注意：在尚未注入任何流动性之前，这个价格只是初始化参考值，并不代表真实成交价
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        assertEq(
            uint256(sqrtPriceX96),
            uint256(SQRT_PRICE_1_1),
            "Price should be initialized"
        );
    }

    /**
     * @notice 测试：不能重复初始化池子
     */
    function testCannotReinitializePool() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        address pool = factory.createPool(token0, token1, FEE_MEDIUM);
        // 可借助 TickMath.getSqrtRatioAtTick（必要时结合 getTickAtSqrtRatio）换算出 sqrtPriceX96，避免人工计算误差
        IUniswapV3Pool(pool).initialize(SQRT_PRICE_1_1);

        vm.expectRevert();
        IUniswapV3Pool(pool).initialize(SQRT_PRICE_1_1);
    }

    /**
     * @notice 测试：Factory owner 功能
     */
    function testFactoryOwner() public {
        assertEq(factory.owner(), address(this), "Deployer should be owner");

        // Only onwer can change owner
        vm.prank(bob);
        vm.expectRevert();
        factory.setOwner(alice);

        // 转移所有权
        factory.setOwner(alice);
        assertEq(factory.owner(), alice, "Alice should be new owner");

        // Can set the owner to zero address
        vm.prank(alice);
        factory.setOwner(address(0));
        assertEq(factory.owner(), address(0), "Factory owner should be zero address");
    }

    /**
     * @notice 测试：启用新的费率等级
     */
    function testEnableNewFeeAmount() public {
        uint24 newFee = 2500; // 0.25%
        int24 newTickSpacing = 50;

        // 非 owner 无法启用费率
        vm.prank(alice);
        vm.expectRevert();
        factory.enableFeeAmount(newFee, newTickSpacing);

        // Owner 可以启用
        factory.enableFeeAmount(newFee, newTickSpacing);
        assertEq(
            int256(factory.feeAmountTickSpacing(newFee)),
            int256(newTickSpacing)
        );

        // 可以创建使用新费率的池
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );
        address pool = factory.createPool(token0, token1, newFee);
        assertTrue(pool != address(0), "Pool with new fee should be created");
    }

    /**
     * @notice 测试：通过 Pool 添加流动性
     */
    function testMintLiquidityDirectly() public {
        vm.startPrank(alice);

        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        // 创建并初始化池
        address poolAddr = factory.createPool(token0, token1, FEE_MEDIUM);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        pool.initialize(SQRT_PRICE_1_1);

        // 授权池子使用代币
        dai.approve(poolAddr, type(uint256).max);
        usdc.approve(poolAddr, type(uint256).max);

        // 计算 tick 范围（全范围）
        int24 tickLower = TickMath.MIN_TICK;
        int24 tickUpper = TickMath.MAX_TICK;

        // 调整到符合 tick spacing
        tickLower = (tickLower / TICK_SPACING_MEDIUM) * TICK_SPACING_MEDIUM;
        tickUpper = (tickUpper / TICK_SPACING_MEDIUM) * TICK_SPACING_MEDIUM;

        // 通过回调添加流动性
        uint128 liquidity = 1000000;

        // 注意：这个测试会失败，因为我们没有实现回调
        // 这展示了为什么需要 NonfungiblePositionManager
        vm.expectRevert();
        pool.mint(alice, tickLower, tickUpper, liquidity, "");

        vm.stopPrank();
    }

    /**
     * @notice 测试：验证池子参数
     */
    function testPoolParameters() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        address poolAddr = factory.createPool(token0, token1, FEE_MEDIUM);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);

        // 验证代币地址
        assertEq(pool.token0(), token0, "Token0 should match");
        assertEq(pool.token1(), token1, "Token1 should match");

        // 验证费率
        assertEq(uint256(pool.fee()), uint256(FEE_MEDIUM), "Fee should match");

        // 验证 tick spacing
        assertEq(
            int256(pool.tickSpacing()),
            int256(TICK_SPACING_MEDIUM),
            "Tick spacing should match"
        );

        // 验证 factory
        assertEq(pool.factory(), address(factory), "Factory should match");
    }

    /**
     * @notice 测试：创建多个池子
     */
    function testCreateMultiplePools() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        address pool1 = factory.createPool(token0, token1, FEE_LOW);
        address pool2 = factory.createPool(token0, token1, FEE_MEDIUM);
        address pool3 = factory.createPool(token0, token1, FEE_HIGH);

        assertTrue(pool1 != address(0), "Pool 1 should be created");
        assertTrue(pool2 != address(0), "Pool 2 should be created");
        assertTrue(pool3 != address(0), "Pool 3 should be created");
    }

    /**
     * @notice 测试：费率验证
     */
    function testFeeAmountValidation() public {
        (address token0, address token1) = sortTokens(
            address(dai),
            address(usdc)
        );

        // 使用未启用的费率应该失败
        uint24 invalidFee = 12345;
        vm.expectRevert();
        factory.createPool(token0, token1, invalidFee);
    }

    /**
     * @notice 测试：代币顺序验证
     */
    function testTokenOrderValidation() public {
        // 相同的代币应该失败
        vm.expectRevert();
        factory.createPool(address(dai), address(dai), FEE_MEDIUM);

        // 零地址应该失败
        vm.expectRevert();
        factory.createPool(address(0), address(dai), FEE_MEDIUM);

        vm.expectRevert();
        factory.createPool(address(dai), address(0), FEE_MEDIUM);
    }
}
