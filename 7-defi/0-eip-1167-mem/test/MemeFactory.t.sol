// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory internal factory;
    address internal treasury = address(1);
    address internal issuer = address(2);
    address internal buyer = address(3);

    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant PER_MINT = 10_000 ether;
    uint256 internal constant PRICE = 1 ether;

    function setUp() public {
        factory = new MemeFactory(treasury);
        vm.deal(treasury, 0);
        vm.deal(issuer, 0);
        vm.deal(buyer, 0);
    }

    function testDeploySetsSymbolAndConfig() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        MemeToken token = MemeToken(tokenAddr);

        assertEq(token.symbol(), "DOGE");
        assertEq(token.issuer(), issuer);
        assertEq(token.totalSupplyCap(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.pricePerMint(), PRICE);
        (address issuerFromFactory, uint256 priceFromFactory, uint256 perMintFromFactory) = factory.memeInfo(tokenAddr);
        assertEq(issuerFromFactory, issuer);
        assertEq(priceFromFactory, PRICE);
        assertEq(perMintFromFactory, PER_MINT);
    }

    function testMintMemePaysOutAndMints() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        vm.deal(buyer, PRICE);

        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);

        assertEq(token.balanceOf(buyer), PER_MINT);
        assertEq(token.mintedAmount(), PER_MINT);

        uint256 expectedProjectCut = PRICE / 100;
        uint256 expectedIssuerCut = PRICE - expectedProjectCut;

        assertEq(treasury.balance, expectedProjectCut);
        assertEq(issuer.balance, expectedIssuerCut);
    }

    function testMintCannotExceedSupply() public {
        uint256 totalSupply = PER_MINT * 2;

        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", totalSupply, PER_MINT, PRICE);

        vm.deal(buyer, PRICE * 3);

        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        vm.deal(buyer, PRICE);
        vm.expectRevert(MemeToken.MintExceedsCap.selector);
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);
    }
}
