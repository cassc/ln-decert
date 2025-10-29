// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 用于验证基于合约的帐户签名的接口
/// @notice 验证提供的数据签名的接口
/// @dev EIP-1271 定义的接口
interface IERC1271 {
    /// @notice 返回所提供的签名对于所提供的数据是否有效
    /// @dev 当函数通过时，必须返回 bytes4 魔法值 0x1626ba7e。
    /// 不得修改状态（对于 solc < 0.5 使用 STATICCALL，对于 solc > 0.5 使用视图修改器）。
    /// 必须允许外部调用。
    /// @param hash 待签名数据的哈希值
    /// @param 与 _data 关联的签名字节数组
    /// @return magicValue bytes4 魔法值 0x1626ba7e
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}
