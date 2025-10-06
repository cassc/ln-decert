'use client'

import { createAppKit } from '@reown/appkit/react'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { sepolia } from '@reown/appkit/networks'
import { QueryClient } from '@tanstack/react-query'
import { cookieToInitialState, WagmiProvider } from 'wagmi'

// 1. Get projectId from https://cloud.reown.com
export const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || ''

if (!projectId) {
  throw new Error('NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID is not set')
}

// 2. Set up Wagmi adapter
export const networks = [sepolia]

export const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: true
})

export const config = wagmiAdapter.wagmiConfig

// 3. Create modal
createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  features: {
    analytics: true,
  },
  metadata: {
    name: 'NFT Market',
    description: 'Decentralized NFT Marketplace',
    url: 'https://nftmarket.example.com',
    icons: ['https://avatars.githubusercontent.com/u/179229932']
  }
})

export const queryClient = new QueryClient()

export function getInitialState(cookies: string | undefined) {
  return cookieToInitialState(config, cookies)
}
