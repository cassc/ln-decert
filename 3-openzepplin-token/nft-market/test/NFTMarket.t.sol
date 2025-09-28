// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";
import {DecentMarketToken} from "../src/DecentMarketToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {ERC1820RegistryMock} from "./utils/ERC1820RegistryMock.sol";

contract NFTMarketTest is Test {
    address private constant ERC1820 = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;

    DecentMarketNFT private nft;
    DecentMarketToken private token;
    NFTMarket private market;

    address private owner = address(this);
    address private seller = address(0xAA);
    address private buyer = address(0xBB);

    uint256 private constant PRICE = 10 ether;

    function setUp() public {
        vm.etch(ERC1820, type(ERC1820RegistryMock).runtimeCode);

        nft = new DecentMarketNFT("Decent Market NFT", "DMNFT");
        token = new DecentMarketToken("Decent Market Token", "DMT", owner);
        market = new NFTMarket(token);

        token.mint(buyer, 100 ether);
        token.mint(seller, 5 ether);

        vm.prank(owner);
        nft.mintTo(seller, "ipfs://example");

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    function testBuyNFTWithApproval() public {
        uint256 tokenId = 0;
        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.prank(buyer);
        token.approve(address(market), PRICE);

        vm.prank(buyer);
        market.buyNFT(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - PRICE);

        (address sellerAfter, uint256 priceAfter) = market.getListing(address(nft), tokenId);
        assertEq(sellerAfter, address(0));
        assertEq(priceAfter, 0);
    }

    function testBuyNFTViaTokensReceived() public {
        uint256 tokenId = 0;
        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        bytes memory data = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        token.transferWithData(address(market), PRICE, data);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - PRICE);
    }

    function testTokensReceivedRevertsOnWrongAmount() public {
        uint256 tokenId = 0;
        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        bytes memory data = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        vm.expectRevert("Wrong amount");
        token.transferWithData(address(market), PRICE - 1, data);
    }
}
