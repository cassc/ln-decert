// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./erc20.sol";
import "./TokenBank.sol";

// 扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

// 继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

// （备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount) external;
}

// ExtendedERC20Token inherits from BaseERC20 and adds transferWithCallback
contract ExtendedERC20Token is BaseERC20 {
    constructor() BaseERC20() {
        name = "ExtendedERC20";
        symbol = "EERC20";
    }

    function transferWithCallback(address to, uint256 amount) external {
        require(transfer(to, amount), "Transfer failed");
        if (isContract(to)) {
            ITokenReceiver(to).tokensReceived(msg.sender, amount);
        }
    }

    // Utility function to check if an address is a contract
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

// TokenBankV2 inherits from TokenBank and implements ITokenReceiver
contract TokenBankV2 is TokenBank, ITokenReceiver {
    constructor(address tokenAddress) TokenBank(tokenAddress) {}

    // Implementation of tokensReceived callback
    // This function is called when tokens are sent via transferWithCallback
    function tokensReceived(address from, uint256 amount) external override {
        // Verify that the caller is the token contract
        require(
            msg.sender == address(token),
            "Only token contract can call this"
        );

        // Update the balance for the sender
        balances[from] += amount;
    }
}
