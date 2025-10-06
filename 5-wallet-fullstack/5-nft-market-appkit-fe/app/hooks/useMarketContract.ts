'use client'

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useWatchContractEvent } from 'wagmi'
import { CONTRACTS } from '../config/contracts'
import { Address } from 'viem'
import { useEffect, useState } from 'react'

export function useListing(nftAddress: Address | undefined, tokenId: bigint | undefined) {
  return useReadContract({
    ...CONTRACTS.NFTMarket,
    functionName: 'getListing',
    args: nftAddress && tokenId !== undefined ? [nftAddress, tokenId] : undefined,
    query: {
      enabled: !!nftAddress && tokenId !== undefined,
    },
  })
}

export function useListNFT() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const listNFT = (nftAddress: Address, tokenId: bigint, price: bigint) => {
    writeContract({
      ...CONTRACTS.NFTMarket,
      functionName: 'list',
      args: [nftAddress, tokenId, price],
    })
  }

  return {
    listNFT,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

export function useBuyNFT() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const buyNFT = (nftAddress: Address, tokenId: bigint) => {
    writeContract({
      ...CONTRACTS.NFTMarket,
      functionName: 'buyNFT',
      args: [nftAddress, tokenId],
    })
  }

  return {
    buyNFT,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

export function useUnlistNFT() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const unlistNFT = (nftAddress: Address, tokenId: bigint) => {
    writeContract({
      ...CONTRACTS.NFTMarket,
      functionName: 'unlist',
      args: [nftAddress, tokenId],
    })
  }

  return {
    unlistNFT,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Hook to watch marketplace events
export function useMarketplaceEvents() {
  const [listedEvents, setListedEvents] = useState<any[]>([])
  const [purchaseEvents, setPurchaseEvents] = useState<any[]>([])

  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Listed',
    onLogs(logs) {
      setListedEvents(prev => [...prev, ...logs])
    },
  })

  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Purchase',
    onLogs(logs) {
      setPurchaseEvents(prev => [...prev, ...logs])
    },
  })

  return {
    listedEvents,
    purchaseEvents,
  }
}
