// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 在该挑战的 Bank 合约基础之上，编写 IBank 接口及 BigBank 合约，使其满足 Bank 实现 IBank，BigBank 继承自 Bank，同时 BigBank 有附加要求：
// 1. 要求存款金额 > 0.001 ether（用 modifier 权限控制）
// 2. BigBank 合约支持转移管理员
// 3. 编写一个 Admin 合约，Admin 合约有自己的 Owner，同时有一个取款函数 adminWithdraw(IBank bank)，
//    adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址。

interface IBank {
    function withdraw(address payable to, uint256 amount) external;
}

contract Admin {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function adminWithdraw(IBank bank) external onlyOwner {
        bank.withdraw(payable(address(this)), address(bank).balance);
    }

    function withdrawAll() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }
}

contract Bank is IBank {
    address public admin;
    mapping(address => uint256) public balances;
    address[3] private topDepositors;

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    receive() external payable virtual {
        deposit();
    }

    function deposit() public payable virtual {
        _handleDeposit(msg.sender, msg.value);
    }

    function withdraw(address payable to, uint256 amount) external virtual onlyAdmin {
        require(to != address(0), "Bank: invalid recipient");
        require(amount <= address(this).balance, "Bank: insufficient funds");
        to.transfer(amount);
        emit Withdraw(to, amount);
    }

    function getTopDepositors() external view returns (address[3] memory) {
        return topDepositors;
    }

    function _transferAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "Bank: invalid admin");
        emit AdminTransferred(admin, newAdmin);
        admin = newAdmin;
    }

    function _handleDeposit(address account, uint256 amount) private {
        require(amount > 0, "Bank: zero deposit");
        balances[account] += amount;
        emit Deposit(account, amount);
        _updateTopDepositors(account);
    }

    function _updateTopDepositors(address account) private {
        uint256 accountBalance = balances[account];
        bool placed = false;

        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i] == account) {
                placed = true;
                break;
            }
        }

        if (!placed) {
            for (uint256 i = 0; i < topDepositors.length; i++) {
                if (topDepositors[i] == address(0)) {
                    topDepositors[i] = account;
                    placed = true;
                    break;
                }
            }
        }

        if (!placed) {
            uint256 lowestIndex = 0;
            uint256 lowestBalance = balances[topDepositors[0]];

            for (uint256 i = 1; i < topDepositors.length; i++) {
                uint256 candidateBalance = balances[topDepositors[i]];
                if (candidateBalance < lowestBalance) {
                    lowestBalance = candidateBalance;
                    lowestIndex = i;
                }
            }

            if (accountBalance > lowestBalance) {
                topDepositors[lowestIndex] = account;
            }
        }

        for (uint256 i = 0; i < topDepositors.length; i++) {
            for (uint256 j = i + 1; j < topDepositors.length; j++) {
                address left = topDepositors[i];
                address right = topDepositors[j];

                if (balances[right] > balances[left]) {
                    (topDepositors[i], topDepositors[j]) = (right, left);
                }
            }
        }
    }
}

contract BigBank is Bank {
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    modifier minDeposit() {
        require(msg.value > MIN_DEPOSIT, "BigBank: deposit too small");
        _;
    }

    function deposit() public payable override minDeposit {
        super.deposit();
    }

    receive() external payable override minDeposit {
        super.deposit();
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        _transferAdmin(newAdmin);
    }
}
