'use client'

import { useState, useEffect } from 'react'
import { useAccount, useWatchContractEvent } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { parseEther } from 'viem'
import { NFTCard } from '../components/NFTCard'
import { useNFTBalance, useNFTApprove, useNFTApprovalStatus, useNFTOwner, useNextTokenId } from '../hooks/useNFTContract'
import { useListNFT, useListing } from '../hooks/useMarketContract'
import { CONTRACTS } from '../config/contracts'

interface NFTCardWithActionsProps {
  tokenId: bigint
  approvingTokenId: bigint | null
  listingTokenId: bigint | null
  isApproving: boolean
  isApprovingConfirming: boolean
  isListing: boolean
  isListingConfirming: boolean
  price: string
  setPrice: (price: string) => void
  handleApprove: (tokenId: bigint) => void
  handleList: (tokenId: bigint) => void
}

function NFTCardWithActions({
  tokenId,
  approvingTokenId,
  listingTokenId,
  isApproving,
  isApprovingConfirming,
  isListing,
  isListingConfirming,
  price,
  setPrice,
  handleApprove,
  handleList
}: NFTCardWithActionsProps) {
  const { address } = useAccount()
  const { data: approvalStatus } = useNFTApprovalStatus(tokenId)
  const { data: listingData } = useListing(CONTRACTS.DecentMarketNFT.address, tokenId)
  const { data: owner } = useNFTOwner(tokenId)

  const isOwner = owner && address && owner.toLowerCase() === address.toLowerCase()
  const isApprovedForMarket = approvalStatus === CONTRACTS.NFTMarket.address
  const isAlreadyListed = listingData && listingData[0] !== '0x0000000000000000000000000000000000000000'
  const isThisTokenApproving = approvingTokenId === tokenId && (isApproving || isApprovingConfirming)
  const isThisTokenListing = listingTokenId === tokenId && (isListing || isListingConfirming)

  if (!isOwner) {
    return null // Don't render NFTs that aren't owned by the current user
  }

  return (
    <NFTCard tokenId={tokenId}>
      <div className="space-y-2">
        <div className="text-xs text-gray-500">Owner: {owner}</div>
        {isAlreadyListed ? (
          <div className="text-sm text-green-600 dark:text-green-400">
            Listed for {listingData[1]?.toString() || '0'} tokens
          </div>
        ) : (
          <>
            {!isApprovedForMarket ? (
              <button
                onClick={() => handleApprove(tokenId)}
                disabled={isThisTokenApproving}
                className="w-full px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 disabled:bg-gray-400 transition-colors"
              >
                {isThisTokenApproving ? 'Approving...' : 'Approve for Listing'}
              </button>
            ) : (
              <div className="space-y-2">
                <input
                  type="text"
                  placeholder="Price in tokens"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-transparent"
                />
                <button
                  onClick={() => handleList(tokenId)}
                  disabled={isThisTokenListing || !price}
                  className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 transition-colors"
                >
                  {isThisTokenListing ? 'Listing...' : 'List NFT'}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </NFTCard>
  )
}

export default function MyNFTsPage() {
  const { address } = useAccount()
  const queryClient = useQueryClient()
  const { data: nextTokenId } = useNextTokenId()
  const [approvingTokenId, setApprovingTokenId] = useState<bigint | null>(null)
  const [listingTokenId, setListingTokenId] = useState<bigint | null>(null)
  const [price, setPrice] = useState('')

  const { approve, isPending: isApproving, isConfirming: isApprovingConfirming, isSuccess: isApproved } = useNFTApprove()
  const { listNFT, isPending: isListing, isConfirming: isListingConfirming, isSuccess: isListed } = useListNFT()

  // Reset state after successful approval
  useEffect(() => {
    if (isApproved) {
      setApprovingTokenId(null)
      // Invalidate approval status queries to trigger refetch
      queryClient.invalidateQueries({ queryKey: ['readContract'] })
    }
  }, [isApproved, queryClient])

  // Reset state after successful listing
  useEffect(() => {
    if (isListed) {
      setListingTokenId(null)
      setPrice('')
      // Invalidate listing queries to trigger refetch
      queryClient.invalidateQueries({ queryKey: ['readContract'] })
    }
  }, [isListed, queryClient])

  // Watch for NFT approval events to trigger UI updates
  useWatchContractEvent({
    ...CONTRACTS.DecentMarketNFT,
    eventName: 'Approval',
    onLogs() {
      queryClient.invalidateQueries({ queryKey: ['readContract'] })
    },
  })

  // Watch for NFT listing events to trigger UI updates
  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Listed',
    onLogs() {
      queryClient.invalidateQueries({ queryKey: ['readContract'] })
    },
  })

  const handleApprove = (tokenId: bigint) => {
    setApprovingTokenId(tokenId)
    approve(CONTRACTS.NFTMarket.address, tokenId)
  }

  const handleList = (tokenId: bigint) => {
    if (!price) return
    setListingTokenId(tokenId)
    const priceInWei = parseEther(price)
    listNFT(CONTRACTS.DecentMarketNFT.address, tokenId, priceInWei)
  }

  if (!address) {
    return (
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">My NFTs</h1>
        <p className="text-gray-600">Please connect your wallet to view your NFTs.</p>
      </div>
    )
  }

  // Generate all possible token IDs (0 to nextTokenId - 1)
  const allTokenIds = nextTokenId ? Array.from({ length: Number(nextTokenId) }, (_, i) => BigInt(i)) : []

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">My NFTs</h1>
      <p className="text-sm text-gray-500 mb-4">Showing only NFTs you own</p>

      {allTokenIds.length === 0 ? (
        <p className="text-gray-600">No NFTs have been minted yet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {allTokenIds.map((tokenId) => (
            <NFTCardWithActions
              key={tokenId.toString()}
              tokenId={tokenId}
              approvingTokenId={approvingTokenId}
              listingTokenId={listingTokenId}
              isApproving={isApproving}
              isApprovingConfirming={isApprovingConfirming}
              isListing={isListing}
              isListingConfirming={isListingConfirming}
              price={price}
              setPrice={setPrice}
              handleApprove={handleApprove}
              handleList={handleList}
            />
          ))}
        </div>
      )}
    </div>
  )
}
