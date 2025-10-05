// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MultiSigWallet.sol";

/**
 * @title InteractWithWallet
 * @notice Example script demonstrating how to interact with the MultiSigWallet
 *
 * Usage examples:
 *
 * 1. Submit a transaction (as owner):
 *    forge script script/InteractWithWallet.s.sol:InteractWithWallet --sig "submitTx(address,address,uint256)" <wallet_address> <recipient> <amount> --broadcast
 *
 * 2. Confirm a transaction (as owner):
 *    forge script script/InteractWithWallet.s.sol:InteractWithWallet --sig "confirmTx(address,uint256)" <wallet_address> <tx_id> --broadcast
 *
 * 3. Execute a transaction (anyone):
 *    forge script script/InteractWithWallet.s.sol:InteractWithWallet --sig "executeTx(address,uint256)" <wallet_address> <tx_id> --broadcast
 */
contract InteractWithWallet is Script {

    /**
     * @notice Submit a new transaction to the wallet
     * @param walletAddress The MultiSigWallet address
     * @param to Recipient address
     * @param value Amount of ETH to send (in wei)
     */
    function submitTx(address walletAddress, address to, uint256 value) external {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        vm.startBroadcast();

        uint256 txId = wallet.submitTransaction(to, value, "");
        console.log("Transaction submitted with ID:", txId);

        vm.stopBroadcast();
    }

    /**
     * @notice Confirm a transaction
     * @param walletAddress The MultiSigWallet address
     * @param txId Transaction ID to confirm
     */
    function confirmTx(address walletAddress, uint256 txId) external {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        vm.startBroadcast();

        wallet.confirmTransaction(txId);
        console.log("Transaction", txId, "confirmed by", msg.sender);

        // Get current confirmation count
        (, , , , uint256 numConfirmations) = wallet.getTransaction(txId);
        console.log("Current confirmations:", numConfirmations);
        console.log("Required confirmations:", wallet.requiredConfirmations());

        vm.stopBroadcast();
    }

    /**
     * @notice Execute a transaction (must have enough confirmations)
     * @param walletAddress The MultiSigWallet address
     * @param txId Transaction ID to execute
     */
    function executeTx(address walletAddress, uint256 txId) external {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        vm.startBroadcast();

        wallet.executeTransaction(txId);
        console.log("Transaction", txId, "executed successfully");

        vm.stopBroadcast();
    }

    /**
     * @notice Revoke confirmation for a transaction
     * @param walletAddress The MultiSigWallet address
     * @param txId Transaction ID
     */
    function revokeTx(address walletAddress, uint256 txId) external {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        vm.startBroadcast();

        wallet.revokeConfirmation(txId);
        console.log("Confirmation revoked for transaction", txId);

        vm.stopBroadcast();
    }

    /**
     * @notice Get information about a transaction
     * @param walletAddress The MultiSigWallet address
     * @param txId Transaction ID
     */
    function getTxInfo(address walletAddress, uint256 txId) external view {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
            = wallet.getTransaction(txId);

        console.log("Transaction ID:", txId);
        console.log("To:", to);
        console.log("Value:", value);
        console.log("Data length:", data.length);
        console.log("Executed:", executed);
        console.log("Confirmations:", numConfirmations);
        console.log("Required:", wallet.requiredConfirmations());
    }

    /**
     * @notice Get wallet information
     * @param walletAddress The MultiSigWallet address
     */
    function getWalletInfo(address walletAddress) external view {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        console.log("=== Wallet Information ===");
        console.log("Address:", walletAddress);
        console.log("Balance:", address(wallet).balance);
        console.log("Required confirmations:", wallet.requiredConfirmations());
        console.log("Transaction count:", wallet.getTransactionCount());

        console.log("\nOwners:");
        address[] memory owners = wallet.getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("  ", i, ":", owners[i]);
        }
    }
}
