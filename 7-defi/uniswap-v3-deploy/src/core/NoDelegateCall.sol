// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

/// @title 防止委托调用合约
/// @notice 基础合约提供了一个修饰符，用于防止委托调用子合约中的方法
abstract contract NoDelegateCall {
    /// @dev 本合同原地址
    address private immutable original;

    constructor() {
        // 不可变在合约的初始化代码中计算，然后内联到部署的字节码中。
        // 换句话说，这个变量在运行时检查时不会改变。
        original = address(this);
    }

    /// @dev 使用私有方法而不是内联到修饰符中，因为修饰符被复制到每个方法中，
    ///     使用不可变意味着地址字节会被复制到使用修饰符的每个位置。
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice 防止委托调用修改后的方法
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
