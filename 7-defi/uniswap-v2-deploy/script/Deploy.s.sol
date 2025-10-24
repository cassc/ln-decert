// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Factory.sol";
import "../src/periphery/UniswapV2Router02.sol";
import "../src/test-tokens/WETH9.sol";
import "../src/test-tokens/MockERC20.sol";

/**
 * @title Deploy
 * @notice Uniswap V2 完整部署脚本
 * @dev 部署顺序：
 *      1. 测试代币（WETH, DAI, USDC）
 *      2. UniswapV2Factory
 *      3. UniswapV2Router02
 *      4. 创建测试交易对
 *      5. 添加初始流动性
 *
 * 运行方式：
 * forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url <RPC_URL>
 *
 * 或本地测试：
 * forge script script/Deploy.s.sol:Deploy --fork-url http://localhost:8545 --broadcast
 */
contract Deploy is Script {
    // 部署的合约地址
    WETH9 public weth;
    MockERC20 public dai;
    MockERC20 public usdc;
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;

    // 初始流动性数量
    uint256 constant INITIAL_WETH = 10 ether;
    uint256 constant INITIAL_DAI = 20000 * 10**18;  // 20000 DAI
    uint256 constant INITIAL_USDC = 20000 * 10**6;  // 20000 USDC (6 decimals)

    function run() public {
        // 使用环境变量中的私钥，或使用默认的测试私钥
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==============================================");
        console.log("Deployer:", deployer);
        console.log("==============================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署测试代币
        console.log("\n1. Deploying test tokens...");
        weth = new WETH9();
        dai = new MockERC20("Dai Stablecoin", "DAI");
        usdc = new MockERC20("USD Coin", "USDC");

        console.log("WETH deployed at:", address(weth));
        console.log("DAI deployed at:", address(dai));
        console.log("USDC deployed at:", address(usdc));

        // 2. 部署 Factory
        console.log("\n2. Deploying UniswapV2Factory...");
        factory = new UniswapV2Factory(deployer); // deployer 作为 feeToSetter
        console.log("UniswapV2Factory deployed at:", address(factory));

        // 3. 验证 init_code_hash
        console.log("\n3. Verifying init_code_hash...");
        bytes32 initCodeHash = keccak256(type(UniswapV2Pair).creationCode);
        console.log("Calculated init_code_hash:");
        console.logBytes32(initCodeHash);
        console.log("Make sure this matches the hash in UniswapV2Library.sol!");

        // 4. 部署 Router
        console.log("\n4. Deploying UniswapV2Router02...");
        router = new UniswapV2Router02(address(factory), address(weth));
        console.log("UniswapV2Router02 deployed at:", address(router));

        // 5. 铸造测试代币
        console.log("\n5. Minting test tokens...");
        dai.mint(deployer, 1000000 * 10**18);  // 1M DAI
        usdc.mint(deployer, 1000000 * 10**6);  // 1M USDC
        console.log("Minted 1M DAI and 1M USDC to deployer");

        // 6. 创建交易对
        console.log("\n6. Creating pairs...");
        address pairWETHDAI = factory.createPair(address(weth), address(dai));
        address pairWETHUSDC = factory.createPair(address(weth), address(usdc));
        address pairDAIUSDC = factory.createPair(address(dai), address(usdc));

        console.log("WETH-DAI pair:", pairWETHDAI);
        console.log("WETH-USDC pair:", pairWETHUSDC);
        console.log("DAI-USDC pair:", pairDAIUSDC);

        // 7. 添加初始流动性（可选）
        console.log("\n7. Adding initial liquidity...");

        // 给 WETH-DAI 添加流动性
        weth.deposit{value: INITIAL_WETH}();
        weth.approve(address(router), INITIAL_WETH);
        dai.approve(address(router), INITIAL_DAI);

        router.addLiquidity(
            address(weth),
            address(dai),
            INITIAL_WETH,
            INITIAL_DAI,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added liquidity to WETH-DAI pair");

        // 给 WETH-USDC 添加流动性
        weth.deposit{value: INITIAL_WETH}();
        weth.approve(address(router), INITIAL_WETH);
        usdc.approve(address(router), INITIAL_USDC);

        router.addLiquidity(
            address(weth),
            address(usdc),
            INITIAL_WETH,
            INITIAL_USDC,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added liquidity to WETH-USDC pair");

        vm.stopBroadcast();

        // 打印部署摘要
        console.log("\n==============================================");
        console.log("Deployment Summary");
        console.log("==============================================");
        console.log("WETH:", address(weth));
        console.log("DAI:", address(dai));
        console.log("USDC:", address(usdc));
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("----------------------------------------------");
        console.log("Pairs:");
        console.log("WETH-DAI:", pairWETHDAI);
        console.log("WETH-USDC:", pairWETHUSDC);
        console.log("DAI-USDC:", pairDAIUSDC);
        console.log("==============================================");
    }
}
