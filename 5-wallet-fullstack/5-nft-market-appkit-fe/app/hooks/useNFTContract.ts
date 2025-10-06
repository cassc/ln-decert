'use client'

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
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
  const { data: hash, writeContract, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const approve = (to: Address, tokenId: bigint) => {
    writeContract({
      ...CONTRACTS.DecentMarketNFT,
      functionName: 'approve',
      args: [to, tokenId],
    })
  }

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
