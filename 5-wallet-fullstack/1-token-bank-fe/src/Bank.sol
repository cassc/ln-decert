// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract Bank {
    address public immutable admin;
    mapping(address => uint256) public balances;
    address[3] private topDepositors;

    event Deposit(address indexed account, uint256 amount);
    event UserWithdraw(address indexed account, uint256 amount);
    event AdminWithdraw(address indexed to, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function deposit() external payable {
        _handleDeposit(msg.sender, msg.value);
    }

    receive() external payable {
        _handleDeposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Bank: zero withdraw");
        uint256 balance = balances[msg.sender];
        require(balance >= amount, "Bank: insufficient balance");

        balances[msg.sender] = balance - amount;
        _updateTopDepositors(msg.sender);

        payable(msg.sender).transfer(amount);

        emit UserWithdraw(msg.sender, amount);
    }

    function adminWithdraw(address payable to, uint256 amount) external onlyAdmin {
        require(to != address(0), "Bank: invalid recipient");
        require(amount <= address(this).balance, "Bank: insufficient funds");
        to.transfer(amount);
        emit AdminWithdraw(to, amount);
    }

    function getTopDepositors() external view returns (address[3] memory) {
        return topDepositors;
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
