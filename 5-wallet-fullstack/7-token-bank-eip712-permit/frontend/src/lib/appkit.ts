import { createAppKit } from '@reown/appkit/react'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { http } from 'wagmi'
import { defineChain } from 'viem'
import { chainId, chainName, rpcUrl } from '../config'

// Get WalletConnect project ID from environment
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? ''

if (!projectId) {
  console.warn('VITE_WALLETCONNECT_PROJECT_ID is not set. Get one at https://cloud.reown.com')
}

// Define the network
const networkSlug = chainName.toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'custom-chain'

export const appChain = defineChain({
  id: chainId,
  name: chainName,
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [rpcUrl] },
    public: { http: [rpcUrl] },
  },
  network: networkSlug,
})

// Create Wagmi Adapter
export const wagmiAdapter = new WagmiAdapter({
  networks: [appChain],
  projectId,
  transports: {
    [appChain.id]: http(rpcUrl),
  },
})

// AppKit metadata
const metadata = {
  name: 'Token Bank & NFT Market',
  description: 'Permit-based token deposits and NFT marketplace',
  url: typeof window !== 'undefined' ? window.location.origin : 'https://example.com',
  icons: ['https://avatars.githubusercontent.com/u/179229932'],
}

// Create AppKit instance
export const modal = createAppKit({
  // @ts-expect-error - version mismatch in transitive dependency
  adapters: [wagmiAdapter],
  networks: [appChain],
  metadata,
  projectId,
  features: {
    analytics: false,
  },
  themeMode: 'light',
  themeVariables: {
    '--w3m-accent': '#0066ff',
  },
})

// Export wagmi config for use in the app
export const wagmiConfig = wagmiAdapter.wagmiConfig
