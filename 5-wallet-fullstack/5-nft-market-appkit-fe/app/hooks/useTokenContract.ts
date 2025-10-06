'use client'

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { CONTRACTS } from '../config/contracts'
import { Address } from 'viem'

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

export function useTokenAllowance(owner: Address | undefined, spender: Address) {
  return useReadContract({
    ...CONTRACTS.DecentMarketToken,
    functionName: 'allowance',
    args: owner ? [owner, spender] : undefined,
    query: {
      enabled: !!owner,
    },
  })
}

export function useTokenApprove() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const approve = (spender: Address, amount: bigint) => {
    writeContract({
      ...CONTRACTS.DecentMarketToken,
      functionName: 'approve',
      args: [spender, amount],
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
