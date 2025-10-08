import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { defineChain } from 'viem'
import { chainId, chainName, rpcUrl } from '../config'

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

export const wagmiConfig = createConfig({
  chains: [appChain],
  transports: {
    [appChain.id]: http(rpcUrl),
  },
  connectors: [injected({ shimDisconnect: true })],
})
