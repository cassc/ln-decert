import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { defineChain } from 'viem'
import { mainnet, sepolia } from 'wagmi/chains'
import { chainId, chainName, rpcUrl } from '../config'

const networkSlug = chainName.toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'custom-chain'

console.log(`wagmi uses chainId ${chainId} and chainName ${chainName} and rpcUrl ${rpcUrl} networkSlug ${networkSlug}`)

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

// Include common chains so wagmi can detect when user is on wrong network
const allChains = [appChain, mainnet, sepolia].filter(
  (chain, index, self) => self.findIndex(c => c.id === chain.id) === index
)

export const wagmiConfig = createConfig({
  chains: allChains as [typeof appChain, ...typeof allChains],
  transports: {
    [appChain.id]: http(rpcUrl),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
  connectors: [injected({ shimDisconnect: true })],
})
