import type { Metadata } from "next";
import Link from "next/link";
import { Providers } from "./providers";
import { WalletConnect } from "./components/WalletConnect";
import "./globals.css";

export const metadata: Metadata = {
  title: "NFT Marketplace",
  description: "Decentralized NFT Marketplace with AppKit",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <header className="border-b border-gray-200 dark:border-gray-800">
            <nav className="container mx-auto px-4 py-4 flex items-center justify-between">
              <div className="flex items-center gap-8">
                <Link href="/" className="text-xl font-bold">
                  NFT Market
                </Link>
                <div className="flex gap-4">
                  <Link href="/marketplace" className="hover:text-blue-600 transition-colors">
                    Marketplace
                  </Link>
                  <Link href="/my-nfts" className="hover:text-blue-600 transition-colors">
                    My NFTs
                  </Link>
                </div>
              </div>
              <WalletConnect />
            </nav>
          </header>
          <main>{children}</main>
        </Providers>
      </body>
    </html>
  );
}
