'use client'

import { useState, useEffect } from 'react'
import { useAccount } from 'wagmi'
import { Address } from 'viem'
import { NFTCard } from '../components/NFTCard'
import { useBuyNFT, useMarketplaceEvents } from '../hooks/useMarketContract'
import { useTokenApprove, useTokenAllowance } from '../hooks/useTokenContract'
import { CONTRACTS } from '../config/contracts'

interface ListedNFT {
  nft: Address
  tokenId: bigint
  seller: Address
  price: bigint
}

export default function MarketplacePage() {
  const { address } = useAccount()
  const [listedNFTs, setListedNFTs] = useState<ListedNFT[]>([])
  const [selectedNFT, setSelectedNFT] = useState<ListedNFT | null>(null)

  const { listedEvents, purchaseEvents } = useMarketplaceEvents()
  const { buyNFT, isPending: isBuying, isConfirming: isBuyingConfirming, isSuccess: isBought } = useBuyNFT()
  const { approve, isPending: isApproving, isConfirming: isApprovingConfirming, isSuccess: isApproved } = useTokenApprove()
  const { data: allowance } = useTokenAllowance(address, CONTRACTS.NFTMarket.address)

  // Track listed NFTs from events
  useEffect(() => {
    const listed = listedEvents.map(log => ({
      nft: log.args.nft as Address,
      tokenId: log.args.tokenId as bigint,
      seller: log.args.seller as Address,
      price: log.args.price as bigint,
    }))

    // Remove purchased NFTs
    const purchased = new Set(
      purchaseEvents.map(log => `${log.args.nft}-${log.args.tokenId}`)
    )

    const available = listed.filter(
      item => !purchased.has(`${item.nft}-${item.tokenId}`)
    )

    setListedNFTs(available)
  }, [listedEvents, purchaseEvents])

  const handleApprove = (nft: ListedNFT) => {
    setSelectedNFT(nft)
    approve(CONTRACTS.NFTMarket.address, nft.price)
  }

  const handleBuy = (nft: ListedNFT) => {
    setSelectedNFT(nft)
    buyNFT(nft.nft, nft.tokenId)
  }

  if (!address) {
    return (
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">NFT Marketplace</h1>
        <p className="text-gray-600">Please connect your wallet to browse the marketplace.</p>
      </div>
    )
  }

  const hasEnoughAllowance = (price: bigint) => {
    return allowance !== undefined && allowance >= price
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">NFT Marketplace</h1>

      {listedNFTs.length === 0 ? (
        <p className="text-gray-600">No NFTs listed for sale yet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {listedNFTs.map((nft) => {
            const isOwnListing = nft.seller.toLowerCase() === address.toLowerCase()

            return (
              <NFTCard key={`${nft.nft}-${nft.tokenId}`} tokenId={nft.tokenId}>
                <div className="space-y-2">
                  <div className="text-sm text-gray-600 dark:text-gray-400">
                    Price: <span className="font-semibold">{nft.price.toString()} tokens</span>
                  </div>
                  <div className="text-xs text-gray-500">
                    Seller: {nft.seller.slice(0, 6)}...{nft.seller.slice(-4)}
                  </div>

                  {isOwnListing ? (
                    <div className="text-sm text-blue-600 dark:text-blue-400">
                      Your listing
                    </div>
                  ) : !hasEnoughAllowance(nft.price) ? (
                    <button
                      onClick={() => handleApprove(nft)}
                      disabled={isApproving || isApprovingConfirming}
                      className="w-full px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 disabled:bg-gray-400 transition-colors"
                    >
                      {isApproving || isApprovingConfirming ? 'Approving...' : 'Approve Tokens'}
                    </button>
                  ) : (
                    <button
                      onClick={() => handleBuy(nft)}
                      disabled={isBuying || isBuyingConfirming}
                      className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 transition-colors"
                    >
                      {isBuying || isBuyingConfirming ? 'Buying...' : 'Buy NFT'}
                    </button>
                  )}
                </div>
              </NFTCard>
            )
          })}
        </div>
      )}
    </div>
  )
}
