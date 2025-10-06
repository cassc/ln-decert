// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CommonBase} from "forge-std/Base.sol";

import {DecentMarketNFT} from "../src/DecentMarketNFT.sol";
import {DecentMarketToken} from "../src/DecentMarketToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {ERC1820RegistryMock} from "./utils/ERC1820RegistryMock.sol";

contract NFTMarketHandler is CommonBase {
    NFTMarket private immutable market;
    DecentMarketNFT private immutable nft;
    DecentMarketToken private immutable token;
    address[] private actors;

    constructor(NFTMarket market_, DecentMarketNFT nft_, DecentMarketToken token_, address[] memory actors_) {
        market = market_;
        nft = nft_;
        token = token_;

        for (uint256 i = 0; i < actors_.length; i++) {
            actors.push(actors_[i]);
        }
    }

    function list(uint256 sellerSeed, uint256 tokenSeed, uint256 priceSeed) external {
        address seller = _actor(sellerSeed);
        uint256 minted = nft.nextTokenId();
        if (minted == 0) return;

        uint256 tokenId = tokenSeed % minted;
        if (_ownerOf(tokenId) != seller) return;

        (address activeSeller,) = market.getListing(address(nft), tokenId);
        if (activeSeller != address(0)) return;

        uint256 price = _boundPrice(priceSeed);

        vm.prank(seller);
        market.list(address(nft), tokenId, price);
    }

    function buy(uint256 buyerSeed, uint256 tokenSeed) external {
        address buyer = _actor(buyerSeed);
        uint256 minted = nft.nextTokenId();
        if (minted == 0) return;

        uint256 tokenId = tokenSeed % minted;
        (address listedSeller, uint256 price) = market.getListing(address(nft), tokenId);
        if (listedSeller == address(0) || listedSeller == buyer) return;
        if (token.balanceOf(buyer) < price) return;

        vm.prank(buyer);
        market.buyNFT(address(nft), tokenId);
    }

    function buyViaCallback(uint256 buyerSeed, uint256 tokenSeed) external {
        address buyer = _actor(buyerSeed);
        uint256 minted = nft.nextTokenId();
        if (minted == 0) return;

        uint256 tokenId = tokenSeed % minted;
        (address listedSeller, uint256 price) = market.getListing(address(nft), tokenId);
        if (listedSeller == address(0) || listedSeller == buyer) return;
        if (token.balanceOf(buyer) < price) return;

        bytes memory payload = abi.encode(address(nft), tokenId);

        vm.prank(buyer);
        token.transferWithCallback(address(market), price, payload);
    }

    function unlist(uint256 sellerSeed, uint256 tokenSeed) external {
        address seller = _actor(sellerSeed);
        uint256 minted = nft.nextTokenId();
        if (minted == 0) return;

        uint256 tokenId = tokenSeed % minted;
        (address listedSeller,) = market.getListing(address(nft), tokenId);
        if (listedSeller != seller) return;

        vm.prank(seller);
        market.unlist(address(nft), tokenId);
    }

    function _boundPrice(uint256 priceSeed) private pure returns (uint256) {
        uint256 minPrice = 1e16;
        uint256 maxPrice = 1_000 ether;
        uint256 span = maxPrice - minPrice + 1;
        return minPrice + (priceSeed % span);
    }

    function _ownerOf(uint256 tokenId) private view returns (address) {
        try nft.ownerOf(tokenId) returns (address owner_) {
            return owner_;
        } catch {
            return address(0);
        }
    }

    function _actor(uint256 seed) private view returns (address) {
        if (actors.length == 0) {
            return address(0);
        }
        uint256 index = seed % actors.length;
        return actors[index];
    }
}

contract NFTMarketInvariant is Test {
    address private constant ERC1820 = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;

    DecentMarketNFT private nft;
    DecentMarketToken private token;
    NFTMarket private market;
    NFTMarketHandler private handler;

    function setUp() public {
        vm.etch(ERC1820, type(ERC1820RegistryMock).runtimeCode);

        token = new DecentMarketToken();
        market = new NFTMarket(token);
        nft = new DecentMarketNFT("Decent Market NFT", "DMNFT");

        address[] memory actors = new address[](4);
        actors[0] = makeAddr("alice");
        actors[1] = makeAddr("bob");
        actors[2] = makeAddr("carol");
        actors[3] = makeAddr("dave");

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];

            // Mint two NFTs to each actor so they can list repeatedly across invariant runs.
            nft.mintTo(actor, "ipfs://seed");
            nft.mintTo(actor, "ipfs://seed");
        }

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            token.transfer(actor, 1000 ether);

            vm.prank(actor);
            nft.setApprovalForAll(address(market), true);

            vm.prank(actor);
            token.approve(address(market), type(uint256).max);
        }

        handler = new NFTMarketHandler(market, nft, token, actors);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.list.selector;
        selectors[1] = handler.buy.selector;
        selectors[2] = handler.buyViaCallback.selector;
        selectors[3] = handler.unlist.selector;

        targetSelector(StdInvariant.FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_NoTokenLeftInMarket() public view {
        assertEq(token.balanceOf(address(market)), 0);
    }
}
