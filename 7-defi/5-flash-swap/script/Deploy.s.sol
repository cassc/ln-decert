// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MyToken} from "../src/MyToken.sol";
import {FlashSwapArb} from "../src/FlashSwapArb.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";

contract DeployTokensAndPools is Script {
    struct PoolConfig {
        uint256 tokenASeed;
        uint256 tokenBSeed;
    }

    function run(address deployer) public {
        require(deployer != address(0), "DEPLOYER_REQUIRED");

        vm.startBroadcast(deployer);

        MyToken tokenA = new MyToken("MyTokenA", "MTA", 1_000_000 ether, deployer);
        MyToken tokenB = new MyToken("MyTokenB", "MTB", 1_000_000 ether, deployer);

        address factoryA = _deployFactory(deployer);
        address factoryB = _deployFactory(deployer);

        address pairA = IUniswapV2Factory(factoryA).createPair(address(tokenA), address(tokenB));
        address pairB = IUniswapV2Factory(factoryB).createPair(address(tokenA), address(tokenB));

        _seedPool(tokenA, tokenB, pairA, PoolConfig({tokenASeed: 1_000 ether, tokenBSeed: 1_000 ether}), deployer);
        _seedPool(tokenA, tokenB, pairB, PoolConfig({tokenASeed: 500 ether, tokenBSeed: 1_000 ether}), deployer);

        FlashSwapArb flash = new FlashSwapArb();

        vm.stopBroadcast();

        console2.log("Deploy complete");
        console2.log("Deployer          :", deployer);
        console2.log("TokenA (MTA)      :", address(tokenA));
        console2.log("TokenB (MTB)      :", address(tokenB));
        console2.log("Factory PoolA     :", factoryA);
        console2.log("Factory PoolB     :", factoryB);
        console2.log("PairA             :", pairA);
        console2.log("PairB             :", pairB);
        console2.log("FlashSwapArb      :", address(flash));
    }

    function _seedPool(
        MyToken tokenA,
        MyToken tokenB,
        address pair,
        PoolConfig memory config,
        address provider
    ) internal {
        tokenA.transfer(pair, config.tokenASeed);
        tokenB.transfer(pair, config.tokenBSeed);
        IUniswapV2Pair(pair).mint(provider);
    }

    function _deployFactory(address feeToSetter) internal returns (address factory) {
        // todo explain 
        bytes memory bytecode = vm.getCode("UniswapV2Factory.sol:UniswapV2Factory");
        bytes memory initCode = abi.encodePacked(bytecode, abi.encode(feeToSetter));
        assembly {
            factory := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(factory != address(0), "FACTORY_DEPLOY_FAIL");
    }
}
