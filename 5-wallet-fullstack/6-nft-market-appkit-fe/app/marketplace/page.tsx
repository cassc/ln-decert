'use client'

import { useState, useEffect } from 'react'
import { useAccount } from 'wagmi'
import { Address, formatUnits } from 'viem'
import { NFTCard } from '../components/NFTCard'
import { useMarketplaceEvents, useUnlistNFT } from '../hooks/useMarketContract'
import { useTokenTransferWithCallback, useTokenBalance } from '../hooks/useTokenContract'
import { CopyButton } from '../components/CopyButton'

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
  const [pendingAction, setPendingAction] = useState<'buy' | 'unlist' | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  const { listedEvents, purchaseEvents, unlistedEvents } = useMarketplaceEvents()
  const {
    transferWithCallback,
    isPending: isTransferring,
    isConfirming: isTransferringConfirming,
    isSuccess: isTransferred,
    error: transferError,
  } = useTokenTransferWithCallback()
  const {
    unlistNFT,
    isPending: isUnlisting,
    isConfirming: isUnlistingConfirming,
    isSuccess: isUnlisted,
    error: unlistError,
  } = useUnlistNFT()
  const { data: tokenBalance } = useTokenBalance(address)

  // Track listed NFTs from events
  useEffect(() => {
    const allEvents = [
      ...listedEvents.map((log) => ({ type: 'Listed' as const, log })),
      ...purchaseEvents.map((log) => ({ type: 'Purchase' as const, log })),
      ...unlistedEvents.map((log) => ({ type: 'Unlisted' as const, log })),
    ].filter(event => event.log?.args)

    allEvents.sort((a, b) => {
      const aBlock = a.log.blockNumber ?? 0n
      const bBlock = b.log.blockNumber ?? 0n

      if (aBlock !== bBlock) {
        return aBlock < bBlock ? -1 : 1
      }

      const aIndex = BigInt(a.log.logIndex ?? 0)
      const bIndex = BigInt(b.log.logIndex ?? 0)

      if (aIndex === bIndex) return 0
      return aIndex < bIndex ? -1 : 1
    })

    const activeListings = new Map<string, ListedNFT>()

    for (const event of allEvents) {
      const args = event.log.args!
      const key = `${args.nft}-${args.tokenId}`

      if (event.type === 'Listed') {
        activeListings.set(key, {
          nft: args.nft as Address,
          tokenId: args.tokenId as bigint,
          seller: args.seller as Address,
          price: args.price as bigint,
        })
      } else {
        activeListings.delete(key)
      }
    }

    setListedNFTs(Array.from(activeListings.values()))
  }, [listedEvents, purchaseEvents, unlistedEvents])

  const handleBuy = (nft: ListedNFT) => {
    if (!hasEnoughBalance(nft.price)) {
      setActionError(`Insufficient token balance to complete this purchase. You need ${formatTokenAmount(nft.price)} tokens.`)
      return
    }

    setSelectedNFT(nft)
    setPendingAction('buy')
    setActionError(null)
    transferWithCallback(nft.price, nft.nft, nft.tokenId).catch((error) => {
      console.error('Buy transaction failed', error)
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(extractErrorMessage(error))
    })
  }

  const handleUnlist = (nft: ListedNFT) => {
    setSelectedNFT(nft)
    setPendingAction('unlist')
    setActionError(null)
    unlistNFT(nft.nft, nft.tokenId).catch((error) => {
      console.error('Unlist transaction failed', error)
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(extractErrorMessage(error))
    })
  }

  const extractErrorMessage = (error: unknown) => {
    if (!error) return 'Transaction failed.'
    if (typeof error === 'string') return error
    if (error instanceof Error) return error.message
    if (typeof error === 'object' && 'shortMessage' in error && typeof (error as any).shortMessage === 'string') {
      return (error as any).shortMessage
    }
    return 'Transaction failed.'
  }

  useEffect(() => {
    if (isTransferred) {
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(null)
    }
  }, [isTransferred])

  useEffect(() => {
    if (isUnlisted) {
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(null)
    }
  }, [isUnlisted])

  useEffect(() => {
    if (transferError) {
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(extractErrorMessage(transferError))
    }
  }, [transferError])

  useEffect(() => {
    if (unlistError) {
      setPendingAction(null)
      setSelectedNFT(null)
      setActionError(extractErrorMessage(unlistError))
    }
  }, [unlistError])

  if (!address) {
    return (
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">NFT Marketplace</h1>
        <p className="text-gray-600">Please connect your wallet to browse the marketplace.</p>
      </div>
    )
  }

  const hasEnoughBalance = (price: bigint) => {
    return tokenBalance !== undefined && tokenBalance >= price
  }

  const formatTokenAmount = (amount: bigint) => {
    try {
      const formatted = formatUnits(amount, 18)
      return formatted.replace(/\.0+$/, '')
    } catch {
      return amount.toString()
    }
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">NFT Marketplace</h1>
      {actionError && (
        <div className="mb-6 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/40">
          {actionError}
        </div>
      )}

      {listedNFTs.length === 0 ? (
        <p className="text-gray-600">No NFTs listed for sale yet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {listedNFTs.map((nft) => {
            const isOwnListing = nft.seller.toLowerCase() === address.toLowerCase()
            const isSelectedNFT = selectedNFT?.nft === nft.nft && selectedNFT?.tokenId === nft.tokenId
            const isTransferringThisNFT = pendingAction === 'buy' && isSelectedNFT && (isTransferring || isTransferringConfirming)
            const isUnlistingThisNFT = pendingAction === 'unlist' && isSelectedNFT && (isUnlisting || isUnlistingConfirming)

            return (
              <NFTCard key={`${nft.nft}-${nft.tokenId}`} tokenId={nft.tokenId}>
                <div className="space-y-2">
                  <div className="text-sm text-gray-600 dark:text-gray-400">
                    Price: <span className="font-semibold">{formatTokenAmount(nft.price)} tokens</span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span>Seller: {nft.seller.slice(0, 6)}...{nft.seller.slice(-4)}</span>
                    <CopyButton value={nft.seller} label="Copy" />
                  </div>

                  {isOwnListing ? (
                    <div className="space-y-2">
                      <div className="text-sm text-blue-600 dark:text-blue-400">
                        Your listing
                      </div>
                      <button
                        onClick={() => handleUnlist(nft)}
                        disabled={isUnlistingThisNFT}
                        className="w-full px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:bg-gray-400 transition-colors"
                      >
                        {isUnlistingThisNFT ? 'Unlisting...' : 'Unlist NFT'}
                      </button>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <button
                        onClick={() => handleBuy(nft)}
                        disabled={isTransferringThisNFT || !hasEnoughBalance(nft.price)}
                        className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 transition-colors"
                      >
                        {isTransferringThisNFT
                          ? 'Buying...'
                          : !hasEnoughBalance(nft.price)
                            ? 'Insufficient Balance'
                            : 'Buy NFT'}
                      </button>
                      {!hasEnoughBalance(nft.price) && (
                        <div className="text-xs text-red-500 dark:text-red-400">
                          You need at least {formatTokenAmount(nft.price)} tokens to buy this NFT.
                        </div>
                      )}
                    </div>
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
