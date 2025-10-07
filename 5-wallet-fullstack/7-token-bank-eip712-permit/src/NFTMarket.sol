// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {PermitToken} from "./PermitToken.sol";

/// @notice Marketplace that accepts PermitToken and restricts purchases to whitelist-signed buyers.
contract NFTMarket is ERC721Holder, ReentrancyGuard, EIP712, Ownable {
    struct Listing {
        address seller;
        uint256 price;
    }

    event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
    event Unlisted(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event WhitelistSignerUpdated(address indexed signer);

    PermitToken public immutable paymentToken;
    address public whitelistSigner;

    bytes32 private constant _PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,address nft,uint256 tokenId,uint256 price,uint256 deadline)");
    mapping(address nft => mapping(uint256 tokenId => Listing)) private _listings;
    mapping(bytes32 digest => bool used) private _consumedPermits;
    
    // Track all listed token IDs per NFT collection for enumeration
    mapping(address nft => uint256[] tokenIds) private _listedTokenIds;
    mapping(address nft => mapping(uint256 tokenId => uint256 index)) private _tokenIdIndex;

    constructor(PermitToken token, address initialSigner)
        EIP712("PermitNFTMarket", "1")
        Ownable(msg.sender)
    {
        paymentToken = token;
        _updateWhitelistSigner(initialSigner);
    }

    /// @notice Admin can rotate the whitelist signer.
    function setWhitelistSigner(address newSigner) external onlyOwner {
        _updateWhitelistSigner(newSigner);
    }

    /// @notice List an NFT for sale.
    function list(address nft, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "NFTMarket: price too low");
        require(_listings[nft][tokenId].seller == address(0), "NFTMarket: already listed");

        IERC721 collection = IERC721(nft);
        require(collection.ownerOf(tokenId) == msg.sender, "NFTMarket: not owner");

        collection.safeTransferFrom(msg.sender, address(this), tokenId);
        _listings[nft][tokenId] = Listing({seller: msg.sender, price: price});

        // Track the token ID for enumeration
        _tokenIdIndex[nft][tokenId] = _listedTokenIds[nft].length;
        _listedTokenIds[nft].push(tokenId);

        emit Listed(msg.sender, nft, tokenId, price);
    }

    /// @notice Cancel a current listing.
    function unlist(address nft, uint256 tokenId) external nonReentrant {
        Listing memory listing = _listings[nft][tokenId];
        require(listing.seller == msg.sender, "NFTMarket: not seller");

        delete _listings[nft][tokenId];
        _removeFromListedTokenIds(nft, tokenId);
        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unlisted(msg.sender, nft, tokenId);
    }

        /// @notice Get all active listings for a given NFT contract.
    /// @param nft The NFT contract address
    /// @return tokenIds Array of listed token IDs
    /// @return listings Array of corresponding listing details
    function getAllListings(address nft) 
        external 
        view 
        returns (uint256[] memory tokenIds, Listing[] memory listings) 
    {
        uint256[] memory allTokenIds = _listedTokenIds[nft];
        uint256 activeCount = 0;
        
        // First pass: count active listings
        for (uint256 i = 0; i < allTokenIds.length; i++) {
            if (_listings[nft][allTokenIds[i]].seller != address(0)) {
                activeCount++;
            }
        }
        
        // Second pass: populate results
        tokenIds = new uint256[](activeCount);
        listings = new Listing[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allTokenIds.length; i++) {
            uint256 tokenId = allTokenIds[i];
            Listing memory listing = _listings[nft][tokenId];
            if (listing.seller != address(0)) {
                tokenIds[currentIndex] = tokenId;
                listings[currentIndex] = listing;
                currentIndex++;
            }
        }
        
        return (tokenIds, listings);
    }

    /// @notice View an active listing.
    function getListing(address nft, uint256 tokenId) external view returns (Listing memory) {
        return _listings[nft][tokenId];
    }

    /// @notice Helper to compute the digest a buyer needs to sign off-chain.
    function hashPermitBuy(
        address buyer,
        address nft,
        uint256 tokenId,
        uint256 price,
        uint256 deadline
    ) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(_PERMIT_BUY_TYPEHASH, buyer, nft, tokenId, price, deadline)));
    }

    /// @notice Buy a listed NFT using a whitelist signature issued off-chain by the project owner.
    function permitBuy(
        address nft,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        Listing memory listing = _listings[nft][tokenId];
        require(listing.seller != address(0), "NFTMarket: not listed");
        require(listing.price == price, "NFTMarket: price changed");
        require(listing.seller != msg.sender, "NFTMarket: cannot buy own NFT");
        require(block.timestamp <= deadline, "NFTMarket: permit expired");

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(_PERMIT_BUY_TYPEHASH, msg.sender, nft, tokenId, price, deadline))
        );
        require(!_consumedPermits[digest], "NFTMarket: permit used");

        address signer = ECDSA.recover(digest, signature);
        require(signer == whitelistSigner, "NFTMarket: invalid signer");

        _consumedPermits[digest] = true;

        delete _listings[nft][tokenId];
        _removeFromListedTokenIds(nft, tokenId);

        bool paid = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(paid, "NFTMarket: payment failed");

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Purchase(msg.sender, listing.seller, nft, tokenId, listing.price);
    }

    function _updateWhitelistSigner(address signer) private {
        require(signer != address(0), "NFTMarket: invalid signer");
        whitelistSigner = signer;
        emit WhitelistSignerUpdated(signer);
    }

    /// @notice Remove a token ID from the listed tokens tracking array.
    /// @dev Uses swap-and-pop for O(1) deletion
    function _removeFromListedTokenIds(address nft, uint256 tokenId) private {
        uint256 index = _tokenIdIndex[nft][tokenId];
        uint256 lastIndex = _listedTokenIds[nft].length - 1;
        
        if (index != lastIndex) {
            uint256 lastTokenId = _listedTokenIds[nft][lastIndex];
            _listedTokenIds[nft][index] = lastTokenId;
            _tokenIdIndex[nft][lastTokenId] = index;
        }
        
        _listedTokenIds[nft].pop();
        delete _tokenIdIndex[nft][tokenId];
    }
}
