// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC777Recipient} from "@openzeppelin/contracts/interfaces/IERC777Recipient.sol";
import {IERC1820Registry} from "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentMarketToken} from "./DecentMarketToken.sol";

/// @notice Marketplace that accepts DecentMarketToken for NFT trading and reacts to transferWithData callbacks.
contract NFTMarket is IERC777Recipient, ERC721Holder, ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
    }

    event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
    event Unlisted(address indexed seller, address indexed nft, uint256 indexed tokenId);

    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    IERC1820Registry private constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    DecentMarketToken public immutable paymentToken;

    mapping(address nft => mapping(uint256 tokenId => Listing)) private _listings;

    constructor(DecentMarketToken token) {
        paymentToken = token;
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), _TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    /// @notice List an NFT for sale.
    function list(address nft, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "Price too low");
        require(_listings[nft][tokenId].seller == address(0), "Already listed");

        IERC721 collection = IERC721(nft);
        require(collection.ownerOf(tokenId) == msg.sender, "Not owner");

        collection.safeTransferFrom(msg.sender, address(this), tokenId);
        _listings[nft][tokenId] = Listing({seller: msg.sender, price: price});

        emit Listed(msg.sender, nft, tokenId, price);
    }

    /// @notice Buy a listed NFT by transferring the required tokens.
    function buyNFT(address nft, uint256 tokenId) external nonReentrant {
        Listing memory listing = _consumeListing(nft, tokenId);
        require(listing.seller != msg.sender, "Cannot buy own NFT"); // 不允许卖家自己购买

        bool paid = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(paid, "Token transfer failed");

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Purchase(msg.sender, listing.seller, nft, tokenId, listing.price);
    }

    /// @notice Cancel an active listing and return the NFT to the seller.
    function unlist(address nft, uint256 tokenId) external nonReentrant {
        Listing memory listing = _listings[nft][tokenId];
        require(listing.seller == msg.sender, "Not seller");

        delete _listings[nft][tokenId];

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unlisted(msg.sender, nft, tokenId);
    }

    /// @notice View an active listing.
    function getListing(address nft, uint256 tokenId) external view returns (address seller, uint256 price) {
        Listing memory listing = _listings[nft][tokenId];
        return (listing.seller, listing.price);
    }

    /// @inheritdoc IERC777Recipient
    function tokensReceived(address, address from, address, uint256 amount, bytes calldata userData, bytes calldata)
        external
        override
        nonReentrant
    {
        require(msg.sender == address(paymentToken), "Unsupported token");
        require(from != address(0), "Invalid buyer");
        require(userData.length == 64, "Invalid data");

        (address nft, uint256 tokenId) = abi.decode(userData, (address, uint256));
        Listing memory listing = _consumeListing(nft, tokenId);
        require(listing.seller != from, "Cannot buy own NFT"); // 不允许卖家自己购买
        require(amount == listing.price, "Wrong amount");

        bool forwarded = paymentToken.transfer(listing.seller, amount);
        require(forwarded, "Forward failed");

        IERC721(nft).safeTransferFrom(address(this), from, tokenId);

        emit Purchase(from, listing.seller, nft, tokenId, amount);
    }

    function _consumeListing(address nft, uint256 tokenId) private returns (Listing memory listing) {
        listing = _listings[nft][tokenId];
        require(listing.seller != address(0), "Not listed");
        delete _listings[nft][tokenId];
    }
}
