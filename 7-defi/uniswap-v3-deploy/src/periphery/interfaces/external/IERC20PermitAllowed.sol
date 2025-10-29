// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 许可证接口
/// @notice DAI/CHAI 用于许可的接口
interface IERC20PermitAllowed {
    /// @notice 通过持有者签名批准花费者花费一些代币
    /// @dev 这是 DAI 和 CHAI 使用的许可接口
    /// 参数 holder 代币持有者的地址，即代币所有者
    /// 参数 花费者 代币花费者的地址
    /// 参数 随机数 持有者的随机数，每次调用许可时都会增加
    /// 参数 过期 许可证不再有效的时间戳
    /// 参数 allowed 布尔值，设置批准金额，true 表示 type(uint256).max，false 表示 0
    /// 参数 v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// 参数 r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// 参数 s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
