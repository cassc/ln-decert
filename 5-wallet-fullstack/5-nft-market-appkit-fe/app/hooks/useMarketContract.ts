'use client'

import { useReadContract, useWaitForTransactionReceipt, useWatchContractEvent, usePublicClient, useAccount, useWalletClient } from 'wagmi'
import { CONTRACTS } from '../config/contracts'
import { Address } from 'viem'
import { useCallback, useEffect, useState } from 'react'

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
  const { address } = useAccount()
  const { data: walletClient } = useWalletClient()

  const [hash, setHash] = useState<`0x${string}` | undefined>(undefined)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
    query: { enabled: !!hash },
  })

  const listNFT = useCallback(
    async (nftAddress: Address, tokenId: bigint, price: bigint) => {
      if (!address) {
        throw new Error('Wallet not connected')
      }
      if (!walletClient) {
        throw new Error('Wallet client unavailable')
      }

      setIsPending(true)
      setError(null)
      setHash(undefined)

      try {
        const txHash = await walletClient.writeContract({
          address: CONTRACTS.NFTMarket.address,
          abi: CONTRACTS.NFTMarket.abi,
          functionName: 'list',
          args: [nftAddress, tokenId, price],
          account: address as Address,
        })

        setHash(txHash)
        return txHash
      } catch (err) {
        setError(err as Error)
        throw err
      } finally {
        setIsPending(false)
      }
    },
    [address, walletClient],
  )

  return {
    listNFT,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

export function useUnlistNFT() {
  const { address } = useAccount()
  const { data: walletClient } = useWalletClient()

  const [hash, setHash] = useState<`0x${string}` | undefined>(undefined)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
    query: { enabled: !!hash },
  })

  const unlistNFT = useCallback(
    async (nftAddress: Address, tokenId: bigint) => {
      if (!address) {
        throw new Error('Wallet not connected')
      }
      if (!walletClient) {
        throw new Error('Wallet client unavailable')
      }

      setIsPending(true)
      setError(null)
      setHash(undefined)

      try {
        const txHash = await walletClient.writeContract({
          address: CONTRACTS.NFTMarket.address,
          abi: CONTRACTS.NFTMarket.abi,
          functionName: 'unlist',
          args: [nftAddress, tokenId],
          account: address as Address,
        })

        setHash(txHash)
        return txHash
      } catch (err) {
        setError(err as Error)
        throw err
      } finally {
        setIsPending(false)
      }
    },
    [address, walletClient],
  )

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
  const publicClient = usePublicClient()
  const [listedEvents, setListedEvents] = useState<any[]>([])
  const [purchaseEvents, setPurchaseEvents] = useState<any[]>([])
  const [unlistedEvents, setUnlistedEvents] = useState<any[]>([])

  const mergeLogs = (prev: any[], incoming: any[]) => {
    if (incoming.length === 0) return prev

    const seen = new Set<string>()
    const deduped: any[] = []

    for (const log of [...prev, ...incoming]) {
      const key = `${log.transactionHash ?? ''}-${String(log.logIndex ?? '')}`
      if (!seen.has(key)) {
        seen.add(key)
        deduped.push(log)
      }
    }

    return deduped
  }

  useEffect(() => {
    if (!publicClient) return

    let isCancelled = false

    const fromBlockEnv = process.env.NEXT_PUBLIC_MARKET_START_BLOCK || '0'
    let fromBlock: bigint

    try {
      fromBlock = BigInt(fromBlockEnv)
    } catch {
      fromBlock = 0n
    }

    const fetchHistoricalLogs = async () => {
      try {
        const [listedLogs, purchaseLogs, unlistedLogs] = await Promise.all([
          publicClient.getContractEvents({
            address: CONTRACTS.NFTMarket.address,
            abi: CONTRACTS.NFTMarket.abi,
            eventName: 'Listed',
            fromBlock,
          }),
          publicClient.getContractEvents({
            address: CONTRACTS.NFTMarket.address,
            abi: CONTRACTS.NFTMarket.abi,
            eventName: 'Purchase',
            fromBlock,
          }),
          publicClient.getContractEvents({
            address: CONTRACTS.NFTMarket.address,
            abi: CONTRACTS.NFTMarket.abi,
            eventName: 'Unlisted',
            fromBlock,
          }),
        ])

        if (isCancelled) return

        setListedEvents(prev => mergeLogs(prev, listedLogs as any[]))
        setPurchaseEvents(prev => mergeLogs(prev, purchaseLogs as any[]))
        setUnlistedEvents(prev => mergeLogs(prev, unlistedLogs as any[]))
      } catch (error) {
        console.error('Failed to load marketplace events', error)
      }
    }

    fetchHistoricalLogs()

    return () => {
      isCancelled = true
    }
  }, [publicClient])

  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Listed',
    onLogs(logs) {
      setListedEvents(prev => mergeLogs(prev, logs))
    },
  })

  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Purchase',
    onLogs(logs) {
      setPurchaseEvents(prev => mergeLogs(prev, logs))
    },
  })

  useWatchContractEvent({
    ...CONTRACTS.NFTMarket,
    eventName: 'Unlisted',
    onLogs(logs) {
      setUnlistedEvents(prev => mergeLogs(prev, logs))
    },
  })

  return {
    listedEvents,
    purchaseEvents,
    unlistedEvents,
  }
}
