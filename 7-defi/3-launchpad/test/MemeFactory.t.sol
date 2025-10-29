// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";
import {MockUniswapV2Router} from "./mocks/MockUniswapV2Router.sol";

contract MemeFactoryTest is Test {
    MemeFactory internal factory;
    MockUniswapV2Router internal router;
    address internal treasury = address(1);
    address internal issuer = address(2);
    address internal buyer = address(3);
    address internal constant WETH = address(4);

    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant PER_MINT = 10_000 ether;
    uint256 internal constant PRICE = 1 ether;

    uint256 internal constant TOKENS_PER_ETH_AT_START = (PER_MINT * 1e18) / PRICE;

    // 准备新的 Meme 工厂并清空参与者余额
    function setUp() public {
        router = new MockUniswapV2Router(WETH);
        router.setTokensPerEth(TOKENS_PER_ETH_AT_START);

        factory = new MemeFactory(treasury, address(router));
        vm.deal(treasury, 0);
        vm.deal(issuer, 0);
        vm.deal(buyer, 0);
    }

    // 验证部署出的代币符号和配置与输入一致
    function testDeploySetsSymbolAndConfig() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        MemeToken token = MemeToken(tokenAddr);

        assertEq(token.symbol(), "DOGE");
        assertEq(token.issuer(), issuer);
        assertEq(token.totalSupplyCap(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.pricePerMint(), PRICE);
        (address issuerFromFactory, uint256 priceFromFactory, uint256 perMintFromFactory, bool liquidityAdded) =
            factory.memeInfo(tokenAddr);
        assertEq(issuerFromFactory, issuer);
        assertEq(priceFromFactory, PRICE);
        assertEq(perMintFromFactory, PER_MINT);
        assertFalse(liquidityAdded);
    }

    // 检查 mint 行为是否会铸造代币并正确分配费用
    function testMintMemePaysOutAndMints() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        vm.deal(buyer, PRICE);

        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);

        uint256 liquidityShare = (PER_MINT * 5) / 100;
        uint256 buyerShare = PER_MINT - liquidityShare;

        assertEq(token.balanceOf(buyer), buyerShare);
        assertEq(token.mintedAmount(), PER_MINT);

        assertEq(token.balanceOf(address(factory)), 0);
        assertEq(token.balanceOf(address(router)), liquidityShare);
        assertEq(factory.pendingLiquidityTokens(tokenAddr), 0);

        uint256 expectedIssuerCut = PRICE - (PRICE / 20);

        assertEq(treasury.balance, 0);
        assertEq(issuer.balance, expectedIssuerCut);

        (, , , bool liquidityAdded) = factory.memeInfo(tokenAddr);
        assertTrue(liquidityAdded);

        assertEq(router.lastLiquidityToken(), tokenAddr);
        assertEq(router.lastAmountToken(), liquidityShare);
        assertEq(router.lastAmountEth(), PRICE / 20);
        assertEq(router.lastLiquidityRecipient(), treasury);
    }

    // 确保铸造量不会超过上限
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

    function testBuyMemeWhenPriceBetter() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        vm.deal(buyer, PRICE);
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        // 设置更优价格
        router.setTokensPerEth(TOKENS_PER_ETH_AT_START * 12 / 10);

        address swapBuyer = address(5);
        vm.deal(swapBuyer, 0.01 ether);

        vm.prank(swapBuyer);
        factory.buyMeme{value: 0.01 ether}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        uint256 expectedBaseline = (0.01 ether * PER_MINT) / PRICE;
        uint256 expectedReceived = (0.01 ether * router.tokensPerEth()) / 1e18;

        assertEq(token.balanceOf(swapBuyer), expectedReceived);
        assertEq(expectedReceived, expectedBaseline * 12 / 10);
    }

    function testBuyMemeRevertsWhenPriceNotBetter() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        vm.deal(buyer, PRICE);
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);

        address swapBuyer = address(6);
        vm.deal(swapBuyer, 0.01 ether);

        vm.expectRevert(MemeFactory.PriceNotBetter.selector);
        vm.prank(swapBuyer);
        factory.buyMeme{value: 0.01 ether}(tokenAddr);
    }
}
