// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISignatureTransfer {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}

contract Bank {
    address public immutable admin;
    mapping(address => uint256) public balances;
    address[3] private topDepositors;
    ISignatureTransfer public constant PERMIT2 =
        ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3); // public deployed Permit2 address
    IWETH public immutable weth;

    event Deposit(address indexed account, uint256 amount);
    event UserWithdraw(address indexed account, uint256 amount);
    event AdminWithdraw(address indexed to, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not admin");
        _;
    }

    constructor(address wethAddress) {
        require(wethAddress != address(0), "Bank: invalid WETH");
        admin = msg.sender;
        weth = IWETH(wethAddress);
    }

    function deposit() external payable {
        _handleDeposit(msg.sender, msg.value);
    }

    receive() external payable {
        if (msg.sender != address(weth)) {
            _handleDeposit(msg.sender, msg.value);
        }
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

    function depositWithPermit2(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        require(owner != address(0), "Bank: invalid owner");
        require(transferDetails.requestedAmount > 0, "Bank: zero deposit");
        require(transferDetails.to == address(this), "Bank: invalid recipient");
        require(permit.permitted.token == address(weth), "Bank: invalid token");

        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);
        weth.withdraw(transferDetails.requestedAmount);
        _handleDeposit(owner, transferDetails.requestedAmount);
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
