// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/// @title ERC721 获许可
/// @notice ERC721 的扩展，包括基于签名的批准的许可功能
interface IERC721Permit is IERC721 {
    /// @notice 许可证签名中使用的许可证类型哈希
    /// @return 许可证的类型哈希
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /// @notice 许可签名中使用的域分隔符
    /// @return 许可签名编码中使用的域分隔符
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice 支出者通过签名批准支出的特定代币 ID
    /// @param 支出者 正在批准的账户
    /// @param tokenId 正在批准支出的代币 ID
    /// @param 截止日期 必须在该截止日期之前挖掘调用才能批准工作
    /// @param v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// @param r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// @param s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}
