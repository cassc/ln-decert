// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";
import {DecentMarketToken} from "../src/DecentMarketToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {ERC1820RegistryMock} from "./utils/ERC1820RegistryMock.sol";

// 此测试文件覆盖 NFTMarket 合约需求，验证上架与购买的成功及失败路径。

contract NFTMarketTest is Test {
    address private constant ERC1820 = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;

    event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);

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
        token = new DecentMarketToken();
        market = new NFTMarket(token);

        token.transfer(buyer, 100 ether);
        token.transfer(seller, 5 ether);

        vm.prank(owner);
        nft.mintTo(seller, "ipfs://example");

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    // 成功用例：买家先授权 ERC20，再购买指定 NFT，验证事件与资金/NFT归属
    function testBuyNFTWithApproval() public {
        uint256 tokenId = 0;
        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit Listed(seller, address(nft), tokenId, PRICE);
        market.list(address(nft), tokenId, PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.prank(buyer);
        token.approve(address(market), PRICE);

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true);
        emit Purchase(buyer, seller, address(nft), tokenId, PRICE);
        market.buyNFT(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - PRICE);

        (address sellerAfter, uint256 priceAfter) = market.getListing(address(nft), tokenId);
        assertEq(sellerAfter, address(0));
        assertEq(priceAfter, 0);
    }

    // 成功上架：记录卖家与价格，同时 NFT 由市场托管
    function testListStoresListing() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit Listed(seller, address(nft), tokenId, PRICE);
        market.list(address(nft), tokenId, PRICE);

        (address listedSeller, uint256 listedPrice) = market.getListing(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    // 失败分支：价格为 0 时应当拒绝上架
    function testListRevertsForZeroPrice() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        vm.expectRevert("Price too low");
        market.list(address(nft), tokenId, 0);
    }

    // 失败分支：非持有人尝试上架应触发 Not owner
    function testListRevertsForNonOwner() public {
        uint256 tokenId = 0;

        vm.prank(buyer);
        vm.expectRevert("Not owner");
        market.list(address(nft), tokenId, PRICE);
    }

    // 失败分支：重复上架同一个 NFT 应触发 Already listed
    function testListRevertsWhenAlreadyListed() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        vm.prank(seller);
        vm.expectRevert("Already listed");
        market.list(address(nft), tokenId, PRICE);
    }

    // 成功用例：通过 transferWithCallback 完成购买，检测事件与余额变化
    function testTokensReceivedCompletesSale() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit Listed(seller, address(nft), tokenId, PRICE);
        market.list(address(nft), tokenId, PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true);
        emit Purchase(buyer, seller, address(nft), tokenId, PRICE);
        token.transferWithCallback(address(market), PRICE, payload);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - PRICE);
        assertEq(token.balanceOf(address(market)), 0);

        (address sellerAfter, uint256 priceAfter) = market.getListing(address(nft), tokenId);
        assertEq(sellerAfter, address(0));
        assertEq(priceAfter, 0);
    }

    // 失败分支：卖家自己购买应被禁止
    function testBuyNFTRevertsForSelfPurchase() public {
        uint256 tokenId = 0;
        token.transfer(seller, PRICE);

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        vm.prank(seller);
        token.approve(address(market), PRICE);

        vm.prank(seller);
        vm.expectRevert("Cannot buy own NFT");
        market.buyNFT(address(nft), tokenId);
    }

    // 失败分支：NFT 已售出后再次购买应报 Not listed
    function testBuyNFTRevertsWhenAlreadySold() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        vm.prank(buyer);
        token.approve(address(market), PRICE);

        vm.prank(buyer);
        market.buyNFT(address(nft), tokenId);

        token.transfer(address(0xCC), PRICE);
        vm.prank(address(0xCC));
        token.approve(address(market), PRICE);

        vm.prank(address(0xCC));
        vm.expectRevert("Not listed");
        market.buyNFT(address(nft), tokenId);
    }

    // 失败分支：回调缺少 userData 时应回滚
    function testTransferWithCallbackRequiresData() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.prank(buyer);
        vm.expectRevert("Invalid data");
        token.transferWithCallback(address(market), PRICE, "");

        (address listedSeller, uint256 listedPrice) = market.getListing(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore);
    }

    // 失败分支：回调路径同样禁止卖家自购
    function testTransferWithCallbackRevertsForSelfPurchase() public {
        uint256 tokenId = 0;
        token.transfer(seller, PRICE);

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(seller);
        vm.expectRevert("Cannot buy own NFT");
        token.transferWithCallback(address(market), PRICE, payload);
    }

    // 失败分支：回调路径下，NFT 再次被购买应报 Not listed
    function testTransferWithCallbackRevertsWhenAlreadySold() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        token.transferWithCallback(address(market), PRICE, payload);

        token.transfer(address(0xCC), PRICE);
        vm.prank(address(0xCC));
        vm.expectRevert("Not listed");
        token.transferWithCallback(address(market), PRICE, payload);
    }

    // 失败分支：回调支付金额不足时应回滚
    function testTransferWithCallbackRevertsForLowerAmount() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        vm.expectRevert("Wrong amount");
        token.transferWithCallback(address(market), PRICE - 1, payload);
    }

    // 失败分支：回调支付金额过高也应回滚
    function testTransferWithCallbackRevertsForHigherAmount() public {
        uint256 tokenId = 0;

        vm.prank(seller);
        market.list(address(nft), tokenId, PRICE);

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        vm.expectRevert("Wrong amount");
        token.transferWithCallback(address(market), PRICE + 1, payload);
    }

    // 模糊测试：0.01-10000 Token 任意价格与随机买家完成上架+购买
    function testFuzz_ListAndBuy(address randomBuyer, uint96 priceSeed) public {
        vm.assume(randomBuyer != address(0));
        vm.assume(randomBuyer != seller);
        vm.assume(randomBuyer != address(market));

        uint256 priceIndex = bound(uint256(priceSeed), 1, 1_000_000); // 映射到 0.01-10000
        uint256 price = priceIndex * 1e16; // 0.01 Token 单位

        uint256 tokenId = 0;

        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit Listed(seller, address(nft), tokenId, price);
        market.list(address(nft), tokenId, price);

        token.transfer(randomBuyer, price);

        vm.startPrank(randomBuyer);
        token.approve(address(market), price);
        vm.expectEmit(true, true, true, true);
        emit Purchase(randomBuyer, seller, address(nft), tokenId, price);
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), randomBuyer);
        assertEq(token.balanceOf(address(market)), 0);
    }


}
