'use client'

import { useState, useCallback } from 'react'
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWalletClient } from 'wagmi'
import { CONTRACTS } from '../config/contracts'
import { Address, encodeAbiParameters } from 'viem'

export function useTokenBalance(address: Address | undefined) {
  return useReadContract({
    ...CONTRACTS.DecentMarketToken,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })
}

export function useTokenTransferWithCallback() {
  const { address } = useAccount()
  const { data: walletClient } = useWalletClient()

  const [hash, setHash] = useState<`0x${string}` | undefined>(undefined)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
    query: { enabled: !!hash },
  })

  const transferWithCallback = useCallback(
    async (amount: bigint, nftAddress: Address, tokenId: bigint) => {
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
        const userData = encodeAbiParameters(
          [
            { type: 'address' },
            { type: 'uint256' },
          ],
          [nftAddress, tokenId],
        )

        const txHash = await walletClient.writeContract({
          address: CONTRACTS.DecentMarketToken.address,
          abi: CONTRACTS.DecentMarketToken.abi,
          functionName: 'transferWithCallback',
          args: [CONTRACTS.NFTMarket.address, amount, userData],
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
    transferWithCallback,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}
