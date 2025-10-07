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

    address internal whitelistSigner;
    uint256 internal whitelistKey;

    function setUp() public {
        token = new PermitToken(address(this));
        nft = new PermitNFT(address(this), "PermitNFT", "PNFT");

        (whitelistSigner, whitelistKey) = makeAddrAndKey("signer");
        market = new NFTMarket(token, whitelistSigner);

        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

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

        bytes32 digest = market.hashPermitBuy(buyer, address(nft), tokenId, price, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(buyer);
        token.approve(address(market), price);

        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, deadline, signature);

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

        bytes32 digest = market.hashPermitBuy(buyer, address(nft), tokenId, price, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(buyer);
        token.approve(address(market), price);
        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, deadline, signature);

        // Transfer NFT back and re-list with same parameters to confirm replay protection.
        vm.prank(buyer);
        nft.safeTransferFrom(buyer, seller, tokenId);
        vm.prank(seller);
        market.list(address(nft), tokenId, price);

        vm.startPrank(buyer);
        token.approve(address(market), price);
        vm.expectRevert("NFTMarket: permit used");
        market.permitBuy(address(nft), tokenId, price, deadline, signature);
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
