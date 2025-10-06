'use client'

import { useState, useCallback } from 'react'
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWalletClient } from 'wagmi'
import { CONTRACTS } from '../config/contracts'
import { Address } from 'viem'

export function useNFTBalance(address: Address | undefined) {
  return useReadContract({
    ...CONTRACTS.DecentMarketNFT,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })
}

export function useNFTOwner(tokenId: bigint | undefined) {
  return useReadContract({
    ...CONTRACTS.DecentMarketNFT,
    functionName: 'ownerOf',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: tokenId !== undefined,
    },
  })
}

export function useNFTTokenURI(tokenId: bigint | undefined) {
  return useReadContract({
    ...CONTRACTS.DecentMarketNFT,
    functionName: 'tokenURI',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: tokenId !== undefined,
    },
  })
}

export function useNFTApprove() {
  const { address } = useAccount()
  const { data: walletClient } = useWalletClient()

  const [hash, setHash] = useState<`0x${string}` | undefined>(undefined)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
    query: { enabled: !!hash },
  })

  const approve = useCallback(
    async (to: Address, tokenId: bigint) => {
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
          address: CONTRACTS.DecentMarketNFT.address,
          abi: CONTRACTS.DecentMarketNFT.abi,
          functionName: 'approve',
          args: [to, tokenId],
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
    approve,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

export function useNFTApprovalStatus(tokenId: bigint | undefined) {
  return useReadContract({
    ...CONTRACTS.DecentMarketNFT,
    functionName: 'getApproved',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: tokenId !== undefined,
    },
  })
}

export function useNextTokenId() {
  return useReadContract({
    ...CONTRACTS.DecentMarketNFT,
    functionName: 'nextTokenId',
  })
}
