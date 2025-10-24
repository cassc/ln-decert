// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

import './interfaces/IUniswapV2ERC20.sol';

/**
 * @title UniswapV2ERC20
 * @notice Uniswap V2 的 LP (流动性提供者) 代币实现
 * @dev 实现了标准 ERC20 功能，并增加了 EIP-2612 的 permit 功能（链下签名授权）
 *
 * 核心功能：
 * 1. 标准 ERC20：转账、授权、余额查询
 * 2. EIP-2612 permit：允许用户通过链下签名进行授权，节省 gas
 *
 * 注意：Solidity 0.8.0+ 内置溢出检查，无需使用 SafeMath
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {

    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';
    uint8 public constant decimals = 18;
    uint  public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    // EIP-2612 相关常量
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces; // 用于防止重放攻击

    constructor() {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        // 构建 EIP-712 域分隔符，用于签名验证
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @notice 铸造新的 LP 代币
     * @param to 接收者地址
     * @param value 铸造数量
     * @dev 内部函数，只能由合约内部调用（如添加流动性时）
     * Solidity 0.8.0+ 自动检查溢出
     */
    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    /**
     * @notice 销毁 LP 代币
     * @param from 销毁代币的地址
     * @param value 销毁数量
     * @dev 内部函数，只能由合约内部调用（如移除流动性时）
     * Solidity 0.8.0+ 自动检查下溢
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @notice 内部授权函数
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权数量
     */
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 内部转账函数
     * @param from 发送者
     * @param to 接收者
     * @param value 转账数量
     */
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    // ERC20 标准函数
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @notice EIP-2612 permit 函数 - 通过链下签名进行授权
     * @dev 允许用户签署链下消息进行授权，避免单独发送授权交易
     *
     * 使用场景：用户可以一次性签名授权并执行操作，节省一笔交易
     *
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权数量
     * @param deadline 签名过期时间
     * @param v 签名参数 v
     * @param r 签名参数 r
     * @param s 签名参数 s
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');

        // 构建符合 EIP-712 标准的消息哈希
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );

        // 使用 ecrecover 恢复签名者地址，验证签名有效性
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');

        _approve(owner, spender, value);
    }
}
