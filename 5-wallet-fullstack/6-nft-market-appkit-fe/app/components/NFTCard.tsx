'use client'

import { useState, useEffect } from 'react'
import { Address } from 'viem'
import { useNFTTokenURI } from '../hooks/useNFTContract'

interface NFTMetadata {
  name?: string
  description?: string
  image?: string
}

interface NFTCardProps {
  tokenId: bigint
  children?: React.ReactNode
}

export function NFTCard({ tokenId, children }: NFTCardProps) {
  const { data: tokenURI } = useNFTTokenURI(tokenId)
  const [metadata, setMetadata] = useState<NFTMetadata | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!tokenURI) return

    const fetchMetadata = async () => {
      try {
        setLoading(true)
        const response = await fetch(tokenURI as string)
        const data = await response.json()
        setMetadata(data)
      } catch (error) {
        console.error('Failed to fetch metadata:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchMetadata()
  }, [tokenURI])

  return (
    <div className="border border-gray-300 dark:border-gray-700 rounded-lg overflow-hidden">
      {loading ? (
        <div className="aspect-square bg-gray-200 dark:bg-gray-800 animate-pulse" />
      ) : metadata?.image ? (
        <img src={metadata.image} alt={metadata.name || `NFT #${tokenId}`} className="w-full aspect-square object-cover" />
      ) : (
        <div className="aspect-square bg-gray-200 dark:bg-gray-800 flex items-center justify-center">
          <span className="text-gray-500">No Image</span>
        </div>
      )}
      <div className="p-4">
        <h3 className="font-semibold text-lg">{metadata?.name || `NFT #${tokenId}`}</h3>
        {metadata?.description && (
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">{metadata.description}</p>
        )}
        <div className="mt-3">
          {children}
        </div>
      </div>
    </div>
  )
}
