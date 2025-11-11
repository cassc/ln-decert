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
        uint96 price;
    }

    event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
    event Unlisted(address indexed seller, address indexed nft, uint256 indexed tokenId);

    error PriceTooLow();
    error AlreadyListed();
    error PriceTooHigh();
    error NotOwner();
    error NotSeller();
    error UnsupportedToken();
    error InvalidBuyer();
    error InvalidData();
    error WrongAmount();
    error TokenTransferFailed();
    error ForwardFailed();
    error NotListed();

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
        if (price == 0) revert PriceTooLow();
        if (price > type(uint96).max) revert PriceTooHigh();
        if (_listings[nft][tokenId].seller != address(0)) revert AlreadyListed();

        IERC721 collection = IERC721(nft);
        if (collection.ownerOf(tokenId) != msg.sender) revert NotOwner();

        collection.safeTransferFrom(msg.sender, address(this), tokenId);
        uint96 listingPrice = uint96(price);
        _listings[nft][tokenId] = Listing({seller: msg.sender, price: listingPrice});

        emit Listed(msg.sender, nft, tokenId, listingPrice);
    }

    /// @notice Buy a listed NFT by transferring the required tokens.
    function buyNFT(address nft, uint256 tokenId) external nonReentrant {
        (address seller, uint96 price) = _consumeListing(nft, tokenId);

        if (!paymentToken.transferFrom(msg.sender, seller, price)) revert TokenTransferFailed();

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Purchase(msg.sender, seller, nft, tokenId, price);
    }

    /// @notice Cancel an active listing and return the NFT to the seller.
    function unlist(address nft, uint256 tokenId) external nonReentrant {
        Listing storage listing = _listings[nft][tokenId];
        if (listing.seller != msg.sender) revert NotSeller();

        delete _listings[nft][tokenId];

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unlisted(msg.sender, nft, tokenId);
    }

    /// @notice View an active listing.
    function getListing(address nft, uint256 tokenId) external view returns (address seller, uint256 price) {
        Listing storage listing = _listings[nft][tokenId];
        seller = listing.seller;
        price = listing.price;
    }

    /// @inheritdoc IERC777Recipient
    function tokensReceived(address, address from, address, uint256 amount, bytes calldata userData, bytes calldata)
        external
        override
        nonReentrant
    {
        if (msg.sender != address(paymentToken)) revert UnsupportedToken();
        if (from == address(0)) revert InvalidBuyer();
        if (userData.length != 64) revert InvalidData();

        (address nft, uint256 tokenId) = abi.decode(userData, (address, uint256));
        (address seller, uint96 price) = _consumeListing(nft, tokenId);
        if (amount != uint256(price)) revert WrongAmount();

        if (!paymentToken.transfer(seller, amount)) revert ForwardFailed();

        IERC721(nft).safeTransferFrom(address(this), from, tokenId);

        emit Purchase(from, seller, nft, tokenId, amount);
    }

    function _consumeListing(address nft, uint256 tokenId) private returns (address seller, uint96 price) {
        Listing storage listing = _listings[nft][tokenId];
        seller = listing.seller;
        if (seller == address(0)) revert NotListed();
        price = listing.price;
        delete _listings[nft][tokenId];
    }
}
