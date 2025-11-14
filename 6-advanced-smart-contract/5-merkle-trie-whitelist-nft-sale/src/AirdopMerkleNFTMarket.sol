// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarket is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        uint128 price;
        bool active;
    }

    IERC20Permit public immutable paymentToken;
    IERC721 public immutable nft;
    bytes32 public merkleRoot;

    mapping(uint256 => Listing) public listings;

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);
    event Claimed(uint256 indexed tokenId, address indexed buyer, uint256 paid);
    event MerkleRootUpdated(bytes32 newRoot);

    error ListingAlreadyActive(uint256 tokenId);
    error ListingInactive(uint256 tokenId);
    error NotSeller(uint256 tokenId, address caller);
    error InvalidMerkleProof();
    error InvalidPrice();
    error MulticallDelegatecallFailed();

    constructor(IERC20Permit token_, IERC721 nft_, bytes32 root_) Ownable(msg.sender) {
        paymentToken = token_;
        nft = nft_;
        merkleRoot = root_;
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function list(uint256 tokenId, uint256 price) external {
        if (price < 2 || price > type(uint128).max) {
            revert InvalidPrice();
        }
        Listing storage listing = listings[tokenId];
        if (listing.active) {
            revert ListingAlreadyActive(tokenId);
        }

        nft.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({seller: msg.sender, price: uint128(price), active: true});

        emit Listed(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        if (!listing.active) {
            revert ListingInactive(tokenId);
        }
        if (listing.seller != msg.sender) {
            revert NotSeller(tokenId, msg.sender);
        }

        listing.active = false;
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCancelled(tokenId, msg.sender);
    }

    function permitPrePay(uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        paymentToken.permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    function claimNFT(uint256 tokenId, bytes32[] calldata proof) external {
        Listing storage listing = listings[tokenId];
        if (!listing.active) {
            revert ListingInactive(tokenId);
        }
        if (!MerkleProof.verifyCalldata(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))) {
            revert InvalidMerkleProof();
        }

        listing.active = false;

        uint256 discounted = uint256(listing.price) / 2;
        IERC20(address(paymentToken)).safeTransferFrom(msg.sender, listing.seller, discounted);

        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Claimed(tokenId, msg.sender, discounted);
    }

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        uint256 length = data.length;
        results = new bytes[](length);
        for (uint256 i = 0; i < length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            if (!success) {
                _bubbleRevert(result);
            }
            results[i] = result;
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _bubbleRevert(bytes memory revertData) private pure {
        if (revertData.length > 0) {
            assembly {
                revert(add(revertData, 0x20), mload(revertData))
            }
        } else {
            revert MulticallDelegatecallFailed();
        }
    }
}
