// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

/**
 * @title UniswapV2Factory
 * @notice Uniswap V2 工厂合约 - 负责创建和管理所有交易对
 * @dev 使用 CREATE2 创建交易对，使得交易对地址可预测
 *
 * 核心功能：
 * 1. 创建交易对：任何人都可以为任意两个 ERC20 代币创建交易对
 * 2. 交易对管理：记录所有已创建的交易对
 * 3. 协议手续费：管理协议手续费接收地址
 */
contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;        // 协议手续费接收地址
    address public feeToSetter;  // 有权修改 feeTo 的地址

    // 通过两个代币地址查询交易对地址
    mapping(address => mapping(address => address)) public getPair;

    // 所有交易对地址数组
    address[] public allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @notice 获取所有交易对数量
     */
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /**
     * @notice 创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 创建的交易对地址
     * @dev 使用 CREATE2 opcode，使得交易对地址可以在链下计算
     *
     * CREATE2 的优势：
     * 1. 地址可预测：可以在不部署合约的情况下计算出地址
     * 2. 节省 gas：Router 可以直接计算地址而不需要查询
     * 3. 确定性：相同的输入总是产生相同的地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');

        // 将代币地址按大小排序，确保 token0 < token1
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');

        // 获取 UniswapV2Pair 合约的 bytecode
        bytes memory bytecode = type(UniswapV2Pair).creationCode;

        // 使用 token0 和 token1 生成 salt
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // 使用 CREATE2 部署合约
        // CREATE2 地址计算公式：
        // keccak256(0xff ++ factory_address ++ salt ++ keccak256(bytecode))[12:]
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // 初始化交易对
        IUniswapV2Pair(pair).initialize(token0, token1);

        // 记录交易对（双向映射）
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @notice 设置协议手续费接收地址
     * @param _feeTo 新的 feeTo 地址
     * @dev 只有 feeToSetter 可以调用
     *
     * 协议手续费机制：
     * - 如果 feeTo 为 address(0)，协议手续费关闭
     * - 如果 feeTo 非零，协议将从 LP 收益中抽取 1/6
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
     * @notice 设置 feeToSetter 地址
     * @param _feeToSetter 新的 feeToSetter 地址
     * @dev 只有当前 feeToSetter 可以调用，这是一个敏感操作
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
