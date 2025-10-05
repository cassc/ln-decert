# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-10-05

### Added
- Initial implementation of MultiSigWallet contract
- On-chain transaction proposal storage
- Multi-owner confirmation system
- Configurable signature threshold
- Transaction execution once threshold is met
- Confirmation revocation functionality
- Comprehensive test suite (25 tests covering all functionality)
- Deployment script for contract deployment
- Interaction script for wallet operations
- Complete documentation in README

### Features
- Multiple owners can submit transaction proposals
- Owners confirm proposals via on-chain transactions
- Anyone can execute transactions that meet the confirmation threshold
- Owners can revoke confirmations before execution
- Support for both ETH transfers and contract calls with data
- Complete event logging for transparency

### Security
- Prevents duplicate owners during initialization
- Prevents zero address as owner
- Validates threshold is between 1 and number of owners
- Prevents double confirmation by same owner
- Prevents execution without enough confirmations
- Prevents re-execution of already executed transactions
