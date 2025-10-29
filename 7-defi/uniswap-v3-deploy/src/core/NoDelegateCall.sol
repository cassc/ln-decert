// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

/// @title 防止委托调用的合约基类
/// @notice 提供修饰符以防止合约方法被委托调用
abstract contract NoDelegateCall {
    /// @dev 合约的原始部署地址
    address private immutable original;

    constructor() {
        // immutable 变量在构造时计算并内联到部署的字节码中
        // 因此该变量在运行时检查时保持不变
        original = address(this);
    }

    /// @dev 使用私有方法而非直接内联到修饰符中,避免修饰符代码在每个使用处重复
    ///      如果直接内联,immutable 地址字节码会在每个使用修饰符的位置都被复制一份
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice 防止函数被委托调用的修饰符
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
