// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice 模拟 USDC 代币合约，用于测试环境
 * @dev 继承自 OpenZeppelin 的 ERC20 实现，添加了可自由铸造的功能
 *
 * 主要特性：
 * - 任何地址都可以调用 mint 函数铸造代币（仅用于测试）
 * - 支持自定义小数位数（通常 USDC 使用 6 位小数）
 * - 完全兼容 ERC20 标准
 *
 * 注意：此合约仅用于测试和开发环境，不应在生产环境中使用
 */
contract MockUSDC is ERC20 {
    /// @notice 代币的小数位数
    /// @dev 使用 immutable 关键字，在构造时设置后不可更改
    uint8 private immutable _tokenDecimals;

    /**
     * @notice 构造函数，初始化模拟 USDC 代币
     * @param name_ 代币名称（例如："Mock USDC"）
     * @param symbol_ 代币符号（例如："USDC"）
     * @param decimals_ 代币小数位数（真实 USDC 使用 6 位小数）
     *
     * 示例：
     * - 部署真实 USDC 的模拟版本：MockUSDC("USD Coin", "USDC", 6)
     * - 部署测试用代币：MockUSDC("Test Token", "TEST", 18)
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _tokenDecimals = decimals_;
    }

    /**
     * @notice 返回代币的小数位数
     * @dev 重写 ERC20 的 decimals 函数，返回构造时设置的自定义小数位
     * @return 代币的小数位数
     */
    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    /**
     * @notice 铸造新代币
     * @dev 公开的铸造函数，任何人都可以调用（仅用于测试环境）
     * @param to 接收铸造代币的地址
     * @param amount 铸造的代币数量（需考虑小数位，例如 6 位小数的 USDC，1 USDC = 1_000_000）
     *
     * 注意：在生产环境中，铸造函数应该有访问控制（如 Ownable 或 AccessControl）
     * 此处为了测试方便，允许任何人铸造
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
