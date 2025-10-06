'use client'

import { useAccount, useDisconnect } from 'wagmi'
import { useAppKit } from '@reown/appkit/react'
import { useTokenBalance } from '../hooks/useTokenContract'

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()
  const { open } = useAppKit()
  const { data: balance } = useTokenBalance(address)

  if (!isConnected) {
    return (
      <button
        onClick={() => open()}
        className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
      >
        Connect Wallet
      </button>
    )
  }

  return (
    <div className="flex items-center gap-4">
      <div className="text-sm">
        <div className="text-gray-500">Address:</div>
        <div className="font-mono">{address?.slice(0, 6)}...{address?.slice(-4)}</div>
      </div>
      {balance !== undefined && (
        <div className="text-sm">
          <div className="text-gray-500">Token Balance:</div>
          <div className="font-mono">{balance.toString()}</div>
        </div>
      )}
      <button
        onClick={() => open()}
        className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
      >
        Account
      </button>
    </div>
  )
}
