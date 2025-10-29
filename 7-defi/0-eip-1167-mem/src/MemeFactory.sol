// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {MemeToken} from "./MemeToken.sol";

/// @title MemeFactory
/// @notice Deploys MemeToken clones and manages mint payments.
contract MemeFactory is ReentrancyGuard {
    using Clones for address;

    struct MemeInfo {
        address issuer;
        uint256 price;
        uint256 perMint;
    }

    address public immutable implementation;
    address payable public immutable projectTreasury;

    mapping(address => MemeInfo) public memeInfo;

    event MemeDeployed(
        address indexed token,
        address indexed issuer,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    event MemeMinted(address indexed token, address indexed buyer, uint256 amount, uint256 pricePaid);

    error InvalidConfig();
    error MemeNotFound();
    error IncorrectPayment();

    constructor(address projectTreasury_) {
        if (projectTreasury_ == address(0)) revert InvalidConfig();
        projectTreasury = payable(projectTreasury_);
        implementation = address(new MemeToken());
    }

    function deployMeme(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address token) {
        if (bytes(symbol).length == 0) revert InvalidConfig();
        if (totalSupply == 0 || perMint == 0 || perMint > totalSupply) revert InvalidConfig();

        // 使用 EIP-1167 最小代理模式克隆 MemeToken 实现
        token = implementation.clone();
        MemeToken(token).initialize(symbol, msg.sender, totalSupply, perMint, price);

        memeInfo[token] = MemeInfo({issuer: msg.sender, price: price, perMint: perMint});

        emit MemeDeployed(token, msg.sender, symbol, totalSupply, perMint, price);
    }

    function mintMeme(address tokenAddr) external payable nonReentrant {
        MemeInfo memory info = memeInfo[tokenAddr];
        if (info.issuer == address(0)) revert MemeNotFound();
        if (msg.value != info.price) revert IncorrectPayment();

        uint256 minted = MemeToken(tokenAddr).mint(msg.sender);
        emit MemeMinted(tokenAddr, msg.sender, minted, msg.value);

        uint256 projectCut = msg.value / 100;
        uint256 issuerCut = msg.value - projectCut;

        (bool okProject, ) = projectTreasury.call{value: projectCut}("");
        require(okProject, "project payout failed");

        (bool okIssuer, ) = info.issuer.call{value: issuerCut}("");
        require(okIssuer, "issuer payout failed");
    }
}
