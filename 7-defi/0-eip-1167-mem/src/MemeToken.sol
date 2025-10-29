// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title MemeToken
/// @notice ERC20 implementation controlled by a MemeFactory clone.
contract MemeToken is ERC20 {
    address public factory;
    address public issuer;
    uint256 public totalSupplyCap;
    uint256 public perMint;
    uint256 public pricePerMint;
    uint256 public mintedAmount;

    string private _customSymbol;
    bool private _initialized;

    error AlreadyInitialized();
    error OnlyFactory();
    error MintExceedsCap();
    error InvalidSettings();

    constructor() ERC20("Meme Token", "MEME") {}

    function initialize(
        string memory symbol_,
        address issuer_,
        uint256 totalSupply_,
        uint256 perMint_,
        uint256 price_
    ) external {
        if (_initialized) revert AlreadyInitialized();
        if (issuer_ == address(0)) revert InvalidSettings();
        if (bytes(symbol_).length == 0) revert InvalidSettings();
        if (totalSupply_ == 0 || perMint_ == 0 || perMint_ > totalSupply_) revert InvalidSettings();

        factory = msg.sender;
        issuer = issuer_;
        totalSupplyCap = totalSupply_;
        perMint = perMint_;
        pricePerMint = price_;
        _customSymbol = symbol_;
        _initialized = true;
    }

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }

    function mint(address to) external returns (uint256 minted) {
        if (msg.sender != factory) revert OnlyFactory();

        uint256 newMinted = mintedAmount + perMint;
        if (newMinted > totalSupplyCap) revert MintExceedsCap();

        mintedAmount = newMinted;
        _mint(to, perMint);
        return perMint;
    }

    function remainingSupply() external view returns (uint256) {
        return totalSupplyCap - mintedAmount;
    }
}
