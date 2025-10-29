// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import './TestERC20.sol';
import '../interfaces/external/IERC20PermitAllowed.sol';

// 有一个假许可证，仅使用 type(uint256).max 的其他签名类型
contract TestERC20PermitAllowed is TestERC20, IERC20PermitAllowed {
    constructor(uint256 amountToMint) TestERC20(amountToMint) {}

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(this.nonces(holder) == nonce, 'TestERC20PermitAllowed::permit: wrong nonce');
        permit(holder, spender, allowed ? type(uint256).max : 0, expiry, v, r, s);
    }
}
