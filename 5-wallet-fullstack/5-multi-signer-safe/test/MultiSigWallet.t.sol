// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract TestReceiver {
    uint256 public value;
    bytes public data;

    function execute(uint256 _value) external payable {
        value = _value;
        data = msg.data;
    }

    receive() external payable {}
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    address[] public owners;
    uint256 public requiredConfirmations;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address nonOwner = address(0x4);

    event TransactionSubmitted(
        uint256 indexed txId,
        address indexed owner,
        address indexed to,
        uint256 value,
        bytes data
    );
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    event ConfirmationRevoked(uint256 indexed txId, address indexed owner);
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);
        requiredConfirmations = 2;

        wallet = new MultiSigWallet(owners, requiredConfirmations);

        // Fund the wallet
        vm.deal(address(wallet), 10 ether);
    }

    function testConstructorInitializesOwnersCorrectly() public view {
        assertEq(wallet.getOwners().length, 3);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }

    function testConstructorSetsRequiredConfirmations() public view{
        assertEq(wallet.requiredConfirmations(), 2);
    }

    function testConstructorRevertsWithNoOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert("Owners required");
        new MultiSigWallet(emptyOwners, 1);
    }

    function testConstructorRevertsWithZeroConfirmations() public {
        vm.expectRevert("Invalid number of required confirmations");
        new MultiSigWallet(owners, 0);
    }

    function testConstructorRevertsWithTooManyConfirmations() public {
        vm.expectRevert("Invalid number of required confirmations");
        new MultiSigWallet(owners, 4);
    }

    function testConstructorRevertsWithZeroAddress() public {
        address[] memory invalidOwners = new address[](2);
        invalidOwners[0] = owner1;
        invalidOwners[1] = address(0);

        vm.expectRevert("Invalid owner");
        new MultiSigWallet(invalidOwners, 1);
    }

    function testConstructorRevertsWithDuplicateOwners() public {
        address[] memory duplicateOwners = new address[](2);
        duplicateOwners[0] = owner1;
        duplicateOwners[1] = owner1;

        vm.expectRevert("Duplicate owner");
        new MultiSigWallet(duplicateOwners, 1);
    }

    function testReceiveETH() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = address(wallet).balance;

        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), amount, initialBalance + amount);

        (bool success, ) = address(wallet).call{value: amount}("");
        assertTrue(success);
        assertEq(address(wallet).balance, initialBalance + amount);
    }

    function testSubmitTransaction() public {
        address recipient = address(0x999);
        uint256 value = 1 ether;
        bytes memory data = "";

        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit TransactionSubmitted(0, owner1, recipient, value, data);

        uint256 txId = wallet.submitTransaction(recipient, value, data);

        assertEq(txId, 0);
        assertEq(wallet.getTransactionCount(), 1);

        (address to, uint256 val, bytes memory txData, bool executed, uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(to, recipient);
        assertEq(val, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionRevertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not an owner");
        wallet.submitTransaction(address(0x999), 1 ether, "");
    }

    function testConfirmTransaction() public {
        // Submit transaction
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        // Confirm transaction
        vm.prank(owner2);
        vm.expectEmit(true, true, false, true);
        emit TransactionConfirmed(txId, owner2);

        wallet.confirmTransaction(txId);

        assertTrue(wallet.isConfirmed(txId, owner2));
        (, , , , uint256 numConfirmations) = wallet.getTransaction(txId);
        assertEq(numConfirmations, 1);
    }

    function testConfirmTransactionRevertsForNonOwner() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("Not an owner");
        wallet.confirmTransaction(txId);
    }

    function testConfirmTransactionRevertsForNonExistentTx() public {
        vm.prank(owner1);
        vm.expectRevert("Transaction does not exist");
        wallet.confirmTransaction(999);
    }

    function testConfirmTransactionRevertsForDuplicateConfirmation() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert("Transaction already confirmed");
        wallet.confirmTransaction(txId);
    }

    function testExecuteTransaction() public {
        address recipient = address(0x999);
        uint256 value = 1 ether;

        // Submit transaction
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, value, "");

        // Confirm by owner1 and owner2 (reaches threshold of 2)
        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        uint256 recipientBalanceBefore = recipient.balance;

        // Execute (can be done by anyone)
        vm.expectEmit(true, false, false, true);
        emit TransactionExecuted(txId);

        wallet.executeTransaction(txId);

        assertEq(recipient.balance, recipientBalanceBefore + value);
        (, , , bool executed, ) = wallet.getTransaction(txId);
        assertTrue(executed);
    }

    function testExecuteTransactionWithData() public {
        TestReceiver receiver = new TestReceiver();
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("execute(uint256)", 123);

        // Submit transaction
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), value, data);

        // Confirm
        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        // Execute
        wallet.executeTransaction(txId);

        assertEq(receiver.value(), 123);
        assertEq(address(receiver).balance, value);
    }

    function testExecuteTransactionRevertsWithoutEnoughConfirmations() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        // Only 1 confirmation (need 2)
        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.expectRevert("Not enough confirmations");
        wallet.executeTransaction(txId);
    }

    function testExecuteTransactionRevertsForNonExistentTx() public {
        vm.expectRevert("Transaction does not exist");
        wallet.executeTransaction(999);
    }

    function testExecuteTransactionRevertsIfAlreadyExecuted() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        wallet.executeTransaction(txId);

        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(txId);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, true);
        emit ConfirmationRevoked(txId, owner2);

        wallet.revokeConfirmation(txId);

        assertFalse(wallet.isConfirmed(txId, owner2));
        (, , , , uint256 numConfirmations) = wallet.getTransaction(txId);
        assertEq(numConfirmations, 0);
    }

    function testRevokeConfirmationRevertsForNonOwner() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("Not an owner");
        wallet.revokeConfirmation(txId);
    }

    function testRevokeConfirmationRevertsIfNotConfirmed() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner2);
        vm.expectRevert("Transaction not confirmed");
        wallet.revokeConfirmation(txId);
    }

    function testRevokeConfirmationRevertsForExecutedTx() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        wallet.executeTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert("Transaction already executed");
        wallet.revokeConfirmation(txId);
    }

    function testMultipleTransactions() public {
        // Submit multiple transactions
        vm.startPrank(owner1);
        uint256 txId1 = wallet.submitTransaction(address(0x111), 1 ether, "");
        uint256 txId2 = wallet.submitTransaction(address(0x222), 2 ether, "");
        uint256 txId3 = wallet.submitTransaction(address(0x333), 3 ether, "");
        vm.stopPrank();

        assertEq(wallet.getTransactionCount(), 3);
        assertEq(txId1, 0);
        assertEq(txId2, 1);
        assertEq(txId3, 2);

        // Confirm and execute txId2 only
        vm.prank(owner1);
        wallet.confirmTransaction(txId2);

        vm.prank(owner2);
        wallet.confirmTransaction(txId2);

        wallet.executeTransaction(txId2);

        // Check states
        (, , , bool executed1, ) = wallet.getTransaction(txId1);
        (, , , bool executed2, ) = wallet.getTransaction(txId2);
        (, , , bool executed3, ) = wallet.getTransaction(txId3);

        assertFalse(executed1);
        assertTrue(executed2);
        assertFalse(executed3);
    }

    function testGetOwners() public view{
        address[] memory retrievedOwners = wallet.getOwners();
        assertEq(retrievedOwners.length, 3);
        assertEq(retrievedOwners[0], owner1);
        assertEq(retrievedOwners[1], owner2);
        assertEq(retrievedOwners[2], owner3);
    }
}
