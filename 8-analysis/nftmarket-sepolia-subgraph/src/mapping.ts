// src/mapping.ts
import {
  Listed as ListedEvent,
  Unlisted as UnlistedEvent,
  Purchase as PurchaseEvent,
  NFTMarket as NFTMarketContract
} from "../generated/NFTMarket/NFTMarket";
import { Listing, Sale, Account } from "../generated/schema";
import { Address, BigInt } from "@graphprotocol/graph-ts";

function addrId(a: Address): string { return a.toHexString().toLowerCase(); }
function listingId(nft: Address, tokenId: BigInt): string {
  return nft.toHexString().toLowerCase() + "-" + tokenId.toString();
}

function getOrCreateAccount(id: string): Account {
  let acct = Account.load(id);
  if (acct == null) {
    acct = new Account(id);
    acct.save();
  }
  return acct as Account;
}

function getPaymentToken(addr: Address): Address {
  const contract = NFTMarketContract.bind(addr);
  const result = contract.try_paymentToken();
  if (!result.reverted) {
    return result.value;
  }
  return Address.zero();
}

export function handleListed(e: ListedEvent): void {
  const id = listingId(e.params.nft, e.params.tokenId);
  let l = Listing.load(id);
  const paymentToken = getPaymentToken(e.address);
  if (l == null) {
    l = new Listing(id);
    l.nft = e.params.nft;
    l.tokenId = e.params.tokenId;
    l.createdAtBlock = e.block.number;
    l.createdAtTimestamp = e.block.timestamp;
    l.createdTxHash = e.transaction.hash;
  }
  l.seller = e.params.seller;
  const sellerId = addrId(e.params.seller);
  l.sellerAccount = sellerId;
  getOrCreateAccount(sellerId);

  l.price = e.params.price;
  l.paymentToken = paymentToken;
  l.status = "ACTIVE";
  l.updatedAtBlock = e.block.number;
  l.updatedAtTimestamp = e.block.timestamp;
  l.updatedTxHash = e.transaction.hash;
  l.save();
}

export function handleUnlisted(e: UnlistedEvent): void {
  const id = listingId(e.params.nft, e.params.tokenId);
  let l = Listing.load(id);
  const paymentToken = getPaymentToken(e.address);
  if (l == null) {
    // Defensive: allow Unlisted even if Listed wasn't seen (partial history)
    l = new Listing(id);
    l.nft = e.params.nft;
    l.tokenId = e.params.tokenId;
    l.createdAtBlock = e.block.number;
    l.createdAtTimestamp = e.block.timestamp;
    l.createdTxHash = e.transaction.hash;
    l.seller = e.params.seller;
    const sellerId = addrId(e.params.seller);
    l.sellerAccount = sellerId;
    getOrCreateAccount(sellerId);
    l.price = BigInt.zero();
  }
  l.paymentToken = paymentToken;
  l.status = "CANCELLED";
  l.updatedAtBlock = e.block.number;
  l.updatedAtTimestamp = e.block.timestamp;
  l.updatedTxHash = e.transaction.hash;
  l.save();
}

export function handlePurchase(e: PurchaseEvent): void {
  const id = listingId(e.params.nft, e.params.tokenId);
  let l = Listing.load(id);
  const paymentToken = getPaymentToken(e.address);
  if (l == null) {
    // Defensive: create listing snapshot to keep referential integrity
    l = new Listing(id);
    l.nft = e.params.nft;
    l.tokenId = e.params.tokenId;
    l.createdAtBlock = e.block.number;
    l.createdAtTimestamp = e.block.timestamp;
    l.createdTxHash = e.transaction.hash;
    l.seller = e.params.seller;
    const sId = addrId(e.params.seller);
    l.sellerAccount = sId;
    getOrCreateAccount(sId);
    l.price = e.params.price;
  }
  l.paymentToken = paymentToken;

  // Create sale
  const saleId = e.transaction.hash.toHexString() + "-" + e.logIndex.toString();
  const s = new Sale(saleId);
  s.listing = id;
  s.nft = e.params.nft;
  s.tokenId = e.params.tokenId;
  s.price = e.params.price;
  s.paymentToken = paymentToken;
  s.buyer = e.params.buyer;
  s.seller = e.params.seller;

  const buyerId = addrId(e.params.buyer);
  const sellerId = addrId(e.params.seller);
  s.buyerAccount = buyerId;
  s.sellerAccount = sellerId;
  getOrCreateAccount(buyerId);
  getOrCreateAccount(sellerId);

  s.txHash = e.transaction.hash;
  s.blockNumber = e.block.number;
  s.timestamp = e.block.timestamp;
  s.save();

  // Update listing status
  l.status = "SOLD";
  l.updatedAtBlock = e.block.number;
  l.updatedAtTimestamp = e.block.timestamp;
  l.updatedTxHash = e.transaction.hash;
  l.save();
}
