'use client'

import { useState } from 'react'

interface CopyButtonProps {
  value: string
  label?: string
}

export function CopyButton({ value, label = 'Copy' }: CopyButtonProps) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch (error) {
      console.error('Failed to copy', error)
    }
  }

  return (
    <button
      onClick={handleCopy}
      className="inline-flex items-center gap-1 rounded border border-gray-300 px-2 py-1 text-xs text-gray-600 transition-colors hover:bg-gray-100 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-800"
      title={copied ? 'Copied!' : 'Copy to clipboard'}
    >
      <span className="material-icons text-sm" aria-hidden="true">
        {copied ? 'check' : 'content_copy'}
      </span>
      <span>{copied ? 'Copied' : label}</span>
    </button>
  )
}
