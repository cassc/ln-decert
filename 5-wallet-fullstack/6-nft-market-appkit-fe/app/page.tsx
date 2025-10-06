import Link from "next/link";

export default function Home() {
  return (
    <div className="container mx-auto px-4 py-16">
      <div className="max-w-4xl mx-auto text-center">
        <h1 className="text-5xl font-bold mb-6">
          Welcome to NFT Market
        </h1>
        <p className="text-xl text-gray-600 dark:text-gray-400 mb-12">
          A decentralized marketplace for trading NFTs with DecentMarket Token
        </p>

        <div className="grid md:grid-cols-2 gap-8 mb-12">
          <div className="border border-gray-300 dark:border-gray-700 rounded-lg p-8">
            <h2 className="text-2xl font-semibold mb-4">List Your NFTs</h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Approve your NFTs and list them for sale at your desired price
            </p>
            <Link
              href="/my-nfts"
              className="inline-block px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Go to My NFTs
            </Link>
          </div>

          <div className="border border-gray-300 dark:border-gray-700 rounded-lg p-8">
            <h2 className="text-2xl font-semibold mb-4">Browse & Buy</h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Explore listed NFTs and purchase them with DecentMarket Tokens
            </p>
            <Link
              href="/marketplace"
              className="inline-block px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              Browse Marketplace
            </Link>
          </div>
        </div>

        <div className="bg-gray-100 dark:bg-gray-900 rounded-lg p-8">
          <h3 className="text-xl font-semibold mb-4">How It Works</h3>
          <ol className="text-left space-y-3 max-w-2xl mx-auto">
            <li className="flex gap-3">
              <span className="font-bold text-blue-600">1.</span>
              <span>Connect your wallet using WalletConnect or browser extension</span>
            </li>
            <li className="flex gap-3">
              <span className="font-bold text-blue-600">2.</span>
              <span>List your NFTs by approving and setting a price in tokens</span>
            </li>
            <li className="flex gap-3">
              <span className="font-bold text-blue-600">3.</span>
              <span>Switch to another account to browse and purchase listed NFTs</span>
            </li>
            <li className="flex gap-3">
              <span className="font-bold text-blue-600">4.</span>
              <span>Approve tokens and buy NFTs from the marketplace</span>
            </li>
          </ol>
        </div>
      </div>
    </div>
  );
}
