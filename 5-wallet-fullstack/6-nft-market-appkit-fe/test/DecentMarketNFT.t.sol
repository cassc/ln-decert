// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";

contract DecentMarketNFTTest is Test {
    DecentMarketNFT private nft;
    address private owner = address(0xABCD);
    address private alice = address(0xBEEF);
    string private constant TOKEN_URI = "ipfs://example";

    function setUp() public {
        vm.prank(owner);
        nft = new DecentMarketNFT("Decent Market NFT", "DMNFT");
    }

    function testOwnerCanMint() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintTo(alice, TOKEN_URI);
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), TOKEN_URI);
    }

    function testNonOwnerCannotMint() public {
        vm.expectRevert();
        nft.mintTo(alice, TOKEN_URI);
    }
}
