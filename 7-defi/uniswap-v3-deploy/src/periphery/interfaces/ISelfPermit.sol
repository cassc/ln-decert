// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// 标题 自助许可证
/// @notice 调用任何符合 EIP-2612 的令牌的许可以在路由中使用的功能
interface ISelfPermit {
    /// @notice 允许此合约使用来自“msg.sender”的给定代币
    /// @dev “所有者”始终是 msg.sender，“花费者”始终是地址（this）。
    /// 参数 token 花费的token地址
    /// 参数 value 可以花费的代币金额
    /// 参数 Deadline 时间戳，当前出块时间必须小于或等于该时间戳
    /// 参数 v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// 参数 r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// 参数 s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice 允许此合约使用来自“msg.sender”的给定代币
    /// @dev “所有者”始终是 msg.sender，“花费者”始终是地址（this）。
    /// 可以代替 #selfPermit 使用，以防止由于调用 #selfPermit 的抢先运行而导致调用失败
    /// 参数 token 花费的token地址
    /// 参数 value 可以花费的代币金额
    /// 参数 Deadline 时间戳，当前出块时间必须小于或等于该时间戳
    /// 参数 v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// 参数 r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// 参数 s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice 允许此合约使用发送者的代币来获得具有“allowed”参数的许可签名
    /// @dev `owner` 始终是 msg.sender，而 `spender` 始终是 address(this)
    /// 参数 token 花费的token地址
    /// 参数 nonce 所有者当前的随机数
    /// 参数 过期 许可证不再有效的时间戳
    /// 参数 v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// 参数 r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// 参数 s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice 允许此合约使用发送者的代币来获得具有“allowed”参数的许可签名
    /// @dev `owner` 始终是 msg.sender，而 `spender` 始终是 address(this)
    /// 可以用来代替 #selfPermitAllowed 来防止由于调用 #selfPermitAllowed 的抢先运行而导致调用失败。
    /// 参数 token 花费的token地址
    /// 参数 nonce 所有者当前的随机数
    /// 参数 过期 许可证不再有效的时间戳
    /// 参数 v 必须生成持有者的有效 secp256k1 签名以及“r”和“s”
    /// 参数 r 必须生成持有者的有效 secp256k1 签名以及“v”和“s”
    /// 参数 s 必须生成持有者的有效 secp256k1 签名以及“r”和“v”
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}
