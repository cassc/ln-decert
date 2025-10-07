// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PermitToken.sol";
import "../src/PermitNFT.sol";
import "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    PermitToken internal token;
    PermitNFT internal nft;
    NFTMarket internal market;

    address internal seller;
    address internal buyer;
    uint256 internal buyerKey;

    address internal whitelistSigner;
    uint256 internal whitelistKey;

    function setUp() public {
        token = new PermitToken(address(this));
        nft = new PermitNFT(address(this), "PermitNFT", "PNFT");

        (whitelistSigner, whitelistKey) = makeAddrAndKey("signer");
        market = new NFTMarket(token, whitelistSigner);

        seller = makeAddr("seller");
        (buyer, buyerKey) = makeAddrAndKey("buyer");

        token.transfer(seller, 20 ether);
        token.transfer(buyer, 20 ether);
    }

    function testPermitBuyTransfersWhitelistApprovedNFT() public {
        uint256 tokenId = nft.mintTo(seller, "ipfs://permit/1");
        uint256 price = 5 ether;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.list(address(nft), tokenId, price);

        // Generate whitelist signature
        bytes32 whitelistDigest = market.hashPermitBuy(buyer, address(nft), tokenId, price, deadline);
        (uint8 wv, bytes32 wr, bytes32 ws) = vm.sign(whitelistKey, whitelistDigest);
        bytes memory whitelistSignature = abi.encodePacked(wr, ws, wv);

        // Generate EIP-2612 token permit signature
        uint256 nonce = token.nonces(buyer);
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, buyer, address(market), price, nonce, deadline)
        );
        bytes32 permitDigest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerKey, permitDigest);

        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, deadline, whitelistSignature, v, r, s);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), 20 ether + price);
        assertEq(token.balanceOf(buyer), 20 ether - price);
    }

    function testPermitBuyFailsWhenSignatureReused() public {
        uint256 tokenId = nft.mintTo(seller, "ipfs://permit/2");
        uint256 price = 2 ether;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.prank(seller);
        market.list(address(nft), tokenId, price);

        // Generate whitelist signature
        bytes32 whitelistDigest = market.hashPermitBuy(buyer, address(nft), tokenId, price, deadline);
        (uint8 wv, bytes32 wr, bytes32 ws) = vm.sign(whitelistKey, whitelistDigest);
        bytes memory whitelistSignature = abi.encodePacked(wr, ws, wv);

        // Generate EIP-2612 token permit signature
        uint256 nonce = token.nonces(buyer);
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, buyer, address(market), price, nonce, deadline)
        );
        bytes32 permitDigest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerKey, permitDigest);

        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, deadline, whitelistSignature, v, r, s);

        // Transfer NFT back and re-list with same parameters to confirm replay protection.
        vm.prank(buyer);
        nft.safeTransferFrom(buyer, seller, tokenId);
        vm.prank(seller);
        market.list(address(nft), tokenId, price);

        // Generate new token permit signature (nonce increased after first use)
        uint256 nonce2 = token.nonces(buyer);
        bytes32 structHash2 = keccak256(
            abi.encode(permitTypehash, buyer, address(market), price, nonce2, deadline)
        );
        bytes32 permitDigest2 = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash2));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(buyerKey, permitDigest2);

        vm.startPrank(buyer);
        vm.expectRevert("NFTMarket: permit used");
        market.permitBuy(address(nft), tokenId, price, deadline, whitelistSignature, v2, r2, s2);
        vm.stopPrank();
    }

    function testGetAllListings() public {
        // Mint and list multiple NFTs
        uint256 tokenId1 = nft.mintTo(seller, "ipfs://permit/1");
        uint256 tokenId2 = nft.mintTo(seller, "ipfs://permit/2");
        uint256 tokenId3 = nft.mintTo(seller, "ipfs://permit/3");

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.startPrank(seller);
        market.list(address(nft), tokenId1, 1 ether);
        market.list(address(nft), tokenId2, 2 ether);
        market.list(address(nft), tokenId3, 3 ether);
        vm.stopPrank();

        // Get all listings
        (uint256[] memory tokenIds, NFTMarket.Listing[] memory listings) = market.getAllListings(address(nft));

        // Verify we got all 3 listings
        assertEq(tokenIds.length, 3);
        assertEq(listings.length, 3);

        // Verify listing details
        assertEq(tokenIds[0], tokenId1);
        assertEq(listings[0].seller, seller);
        assertEq(listings[0].price, 1 ether);

        assertEq(tokenIds[1], tokenId2);
        assertEq(listings[1].seller, seller);
        assertEq(listings[1].price, 2 ether);

        assertEq(tokenIds[2], tokenId3);
        assertEq(listings[2].seller, seller);
        assertEq(listings[2].price, 3 ether);

        // Unlist one NFT
        vm.prank(seller);
        market.unlist(address(nft), tokenId2);

        // Verify only 2 listings remain
        (tokenIds, listings) = market.getAllListings(address(nft));
        assertEq(tokenIds.length, 2);
        assertEq(listings.length, 2);

        // Verify correct listings remain (tokenId1 and tokenId3)
        bool hasTokenId1 = false;
        bool hasTokenId3 = false;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId1) hasTokenId1 = true;
            if (tokenIds[i] == tokenId3) hasTokenId3 = true;
        }
        assertTrue(hasTokenId1);
        assertTrue(hasTokenId3);
    }
}
