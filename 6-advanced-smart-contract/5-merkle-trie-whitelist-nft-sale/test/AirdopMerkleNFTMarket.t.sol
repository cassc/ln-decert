// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {SaleToken} from "../src/SaleToken.sol";
import {WhitelistNFT} from "../src/WhitelistNFT.sol";

contract AirdopMerkleNFTMarketTest is Test {
    SaleToken internal token;
    WhitelistNFT internal nft;
    AirdopMerkleNFTMarket internal market;

    address internal constant SELLER = address(0xABCD);

    uint256 internal constant BUYER_KEY = 0xA11CE;
    address internal buyer = vm.addr(BUYER_KEY);
    address internal otherWhitelisted = address(0xBEEF);
    uint256 internal constant NON_WHITELIST_KEY = 0xC0DE;
    address internal nonWhitelisted = vm.addr(NON_WHITELIST_KEY);
    uint256 internal constant CLI_BUYER_KEY = 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20;
    address internal constant CLI_BUYER = 0x6370eF2f4Db3611D657b90667De398a2Cc2a370C;
    bytes32 internal constant CLI_ROOT = 0xb823d514814fcd8a34f3f96caf512598eb7b7a22308db39003c9d0e004bfbb1b;

    uint256 internal listedTokenId;
    uint256 internal constant LISTING_PRICE = 10 ether;
    uint256 internal constant DISCOUNTED_PRICE = LISTING_PRICE / 2;

    function setUp() public {
        assertEq(vm.addr(CLI_BUYER_KEY), CLI_BUYER, "cli key mismatch");
        token = new SaleToken();
        nft = new WhitelistNFT();

        bytes32 root = _hashPair(_leaf(buyer), _leaf(otherWhitelisted));
        market = new AirdopMerkleNFTMarket(token, nft, root);

        token.mint(buyer, 100 ether);
        token.mint(CLI_BUYER, 100 ether);
        listedTokenId = nft.mint(SELLER);

        vm.startPrank(SELLER);
        nft.approve(address(market), listedTokenId);
        market.list(listedTokenId, LISTING_PRICE);
        vm.stopPrank();
    }

    function testWhitelistBuyerClaimsWithMulticallPermit() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(otherWhitelisted);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(buyer, DISCOUNTED_PRICE, deadline);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(market.permitPrePay.selector, DISCOUNTED_PRICE, deadline, v, r, s);
        calls[1] = abi.encodeWithSelector(market.claimNFT.selector, listedTokenId, proof);

        vm.prank(buyer);
        market.multicall(calls);

        assertEq(token.balanceOf(SELLER), DISCOUNTED_PRICE);
        assertEq(token.balanceOf(buyer), 100 ether - DISCOUNTED_PRICE);
        assertEq(nft.ownerOf(listedTokenId), buyer);

        (address seller,, bool active) = market.listings(listedTokenId);
        assertEq(seller, SELLER);
        assertFalse(active);
    }

    function testNonWhitelistedBuyerReverts() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(otherWhitelisted);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(nonWhitelisted, DISCOUNTED_PRICE, deadline);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(market.permitPrePay.selector, DISCOUNTED_PRICE, deadline, v, r, s);
        calls[1] = abi.encodeWithSelector(market.claimNFT.selector, listedTokenId, proof);

        vm.prank(nonWhitelisted);
        vm.expectRevert(AirdopMerkleNFTMarket.InvalidMerkleProof.selector);
        market.multicall(calls);
    }

    function testCliProofAllowsClaim() public {
        market.setMerkleRoot(CLI_ROOT);

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = 0x1468288056310c82aa4c01a7e12a10f8111a0560e72b700555479031b86c357d;
        proof[1] = 0x32ce85405983c392122c7c4869690b8081fc9ecec74276206caea196c6e545cb;
        proof[2] = 0xa876da518a393dbd067dc72abfa08d475ed6447fca96d92ec3f9e7eba503ca61;

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(CLI_BUYER, DISCOUNTED_PRICE, deadline);

        bytes[] memory calls = new bytes[](2);
        // Permit the market to spend `DISCOUNTED_PRICE` tokens, signature valid until `deadline`
        calls[0] = abi.encodeWithSelector(market.permitPrePay.selector, DISCOUNTED_PRICE, deadline, v, r, s);
        // Execute discounted payment and transfer the NFT to CLI_BUYER
        calls[1] = abi.encodeWithSelector(market.claimNFT.selector, listedTokenId, proof);

        vm.prank(CLI_BUYER);
        market.multicall(calls);

        assertEq(token.balanceOf(SELLER), DISCOUNTED_PRICE);
        assertEq(token.balanceOf(CLI_BUYER), 100 ether - DISCOUNTED_PRICE);
        assertEq(nft.ownerOf(listedTokenId), CLI_BUYER);
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _signPermit(address owner, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8, bytes32, bytes32)
    {
        uint256 nonce = token.nonces(owner);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        address(market),
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );

        uint256 key;
        if (owner == buyer) key = BUYER_KEY;
        else if (owner == nonWhitelisted) key = NON_WHITELIST_KEY;
        else if (owner == CLI_BUYER) key = CLI_BUYER_KEY;
        else revert("unknown owner");

        return vm.sign(key, digest);
    }
}
