import { useCallback, useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';

// Declare AppKit web components
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace JSX {
    interface IntrinsicElements {
      'w3m-button': React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
    }
  }
}
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useSignTypedData,
  useWriteContract,
} from 'wagmi';
import type { Address } from 'viem';
import { formatUnits, parseUnits, zeroAddress } from 'viem';

import { bankAbi } from './abi/bank';
import { tokenAbi } from './abi/token';
import { permitNftAbi } from './abi/nft';
import { marketAbi } from './abi/market';
import {
  bankAddress,
  chainId as configuredChainId,
  getAddressUrl,
  isAppConfigured,
  marketAddress,
  nftAddress,
  tokenAddress,
  whitelistSignerAddress,
} from './config';
import './App.css';

type NftItem = {
  tokenId: number;
  owner: Address;
  tokenUri: string;
  listingSeller?: Address;
  listingPrice?: bigint;
};

const signatureToVrs = (signature: `0x${string}`) => {
  if (!signature || signature.length !== 132) {
    throw new Error('Signature must be a 65-byte hex string.');
  }
  const r = `0x${signature.slice(2, 66)}` as `0x${string}`;
  const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
  const v = Number.parseInt(signature.slice(130, 132), 16);
  return { r, s, v };
};

function App() {
  const { address } = useAccount();
  const activeChainId = useChainId();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();
  const { signTypedDataAsync } = useSignTypedData();

  const [depositAmount, setDepositAmount] = useState('1');
  const [depositStatus, setDepositStatus] = useState('');
  const [withdrawStatus, setWithdrawStatus] = useState('');
  const [permitDepositDeadline, setPermitDepositDeadline] = useState('');
  const [tokenApprovalAmount, setTokenApprovalAmount] = useState('5');
  const [tokenApprovalStatus, setTokenApprovalStatus] = useState('');
  const [mintUri, setMintUri] = useState('ipfs://sample-nft.json');
  const [mintStatus, setMintStatus] = useState('');
  const [nftApprovalStatus, setNftApprovalStatus] = useState('');
  const [listTokenId, setListTokenId] = useState('');
  const [listPrice, setListPrice] = useState('1');
  const [listStatus, setListStatus] = useState('');
  const [permitBuyTokenId, setPermitBuyTokenId] = useState('');
  const [permitBuyPrice, setPermitBuyPrice] = useState('');
  const [permitBuyDeadline, setPermitBuyDeadline] = useState('');
  const [permitBuySignature, setPermitBuySignature] = useState('');
  const [permitBuyStatus, setPermitBuyStatus] = useState('');
  const [nftItems, setNftItems] = useState<NftItem[]>([]);
  const [isLoadingNfts, setIsLoadingNfts] = useState(false);
  const [whitelistBuyerAddress, setWhitelistBuyerAddress] = useState('');
  const [whitelistTokenId, setWhitelistTokenId] = useState('');
  const [whitelistPrice, setWhitelistPrice] = useState('');
  const [whitelistDeadline, setWhitelistDeadline] = useState('');
  const [whitelistStatus, setWhitelistStatus] = useState('');
  const [generatedSignature, setGeneratedSignature] = useState('');

  const tokenNameQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'name',
    query: { enabled: isAppConfigured && Boolean(tokenAddress) },
  });

  const tokenSymbolQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'symbol',
    query: { enabled: isAppConfigured && Boolean(tokenAddress) },
  });

  const tokenDecimalsQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'decimals',
    query: { enabled: isAppConfigured && Boolean(tokenAddress) },
  });

  const walletTokenBalanceQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && tokenAddress) },
  });

  const bankBalanceQuery = useReadContract({
    abi: bankAbi,
    address: bankAddress,
    functionName: 'balances',
    args: address ? [address] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && bankAddress) },
  });

  const bankVaultQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'balanceOf',
    args: bankAddress ? [bankAddress] : undefined,
    query: { enabled: isAppConfigured && Boolean(tokenAddress && bankAddress) },
  });

  const topDepositorsQuery = useReadContract({
    abi: bankAbi,
    address: bankAddress,
    functionName: 'getTopDepositors',
    query: { enabled: isAppConfigured && Boolean(bankAddress) },
  });

  const nftNextIdQuery = useReadContract({
    abi: permitNftAbi,
    address: nftAddress,
    functionName: 'nextTokenId',
    query: { enabled: isAppConfigured && Boolean(nftAddress) },
  });

  const nftOwnerQuery = useReadContract({
    abi: permitNftAbi,
    address: nftAddress,
    functionName: 'owner',
    query: { enabled: isAppConfigured && Boolean(nftAddress) },
  });

  const tokenDecimals = useMemo(() => {
    const raw = tokenDecimalsQuery.data;
    if (typeof raw === 'number') {
      return raw;
    }
    if (typeof raw === 'bigint') {
      return Number(raw);
    }
    return 18;
  }, [tokenDecimalsQuery.data]);

  const tokenSymbol = typeof tokenSymbolQuery.data === 'string' ? tokenSymbolQuery.data : 'TOKEN';
  const tokenName = typeof tokenNameQuery.data === 'string' ? tokenNameQuery.data : 'Permit Token';

  const walletTokenBalance = typeof walletTokenBalanceQuery.data === 'bigint' ? walletTokenBalanceQuery.data : 0n;
  const formattedWalletBalance = formatUnits(walletTokenBalance, tokenDecimals);

  const bankUserBalance = typeof bankBalanceQuery.data === 'bigint' ? bankBalanceQuery.data : 0n;
  const formattedBankUserBalance = formatUnits(bankUserBalance, tokenDecimals);

  const bankVaultBalance = typeof bankVaultQuery.data === 'bigint' ? bankVaultQuery.data : 0n;
  const formattedBankVaultBalance = formatUnits(bankVaultBalance, tokenDecimals);

  const topDepositors = Array.isArray(topDepositorsQuery.data)
    ? (topDepositorsQuery.data as Address[])
    : [];

  const nextTokenId = typeof nftNextIdQuery.data === 'bigint' ? Number(nftNextIdQuery.data) : 0;
  const nftOwner = nftOwnerQuery.data as Address | undefined;
  const isNftOwner = Boolean(address && nftOwner && address.toLowerCase() === nftOwner.toLowerCase());
  const isWhitelistSigner = Boolean(
    address && whitelistSignerAddress && address.toLowerCase() === whitelistSignerAddress.toLowerCase()
  );

  const refreshBalances = useCallback(() => {
    walletTokenBalanceQuery.refetch?.();
    bankBalanceQuery.refetch?.();
    bankVaultQuery.refetch?.();
    topDepositorsQuery.refetch?.();
  }, [walletTokenBalanceQuery, bankBalanceQuery, bankVaultQuery, topDepositorsQuery]);

  const refreshNfts = useCallback(() => {
    nftNextIdQuery.refetch?.();
  }, [nftNextIdQuery]);

  useEffect(() => {
    const loadNfts = async () => {
      if (!publicClient || !nftAddress || !marketAddress) {
        setNftItems([]);
        return;
      }
      const total = typeof nftNextIdQuery.data === 'bigint' ? Number(nftNextIdQuery.data) : 0;
      if (total === 0) {
        setNftItems([]);
        return;
      }
      setIsLoadingNfts(true);
      try {
        const items: NftItem[] = [];
        for (let tokenId = 0; tokenId < total; tokenId += 1) {
          const [owner, tokenUri] = await Promise.all([
            publicClient.readContract({
              abi: permitNftAbi,
              address: nftAddress,
              functionName: 'ownerOf',
              args: [BigInt(tokenId)],
            }) as Promise<Address>,
            publicClient.readContract({
              abi: permitNftAbi,
              address: nftAddress,
              functionName: 'tokenURI',
              args: [BigInt(tokenId)],
            }) as Promise<string>,
          ]);

          const listingRaw = (await publicClient.readContract({
            abi: marketAbi,
            address: marketAddress,
            functionName: 'getListing',
            args: [nftAddress, BigInt(tokenId)],
          })) as { seller: Address; price: bigint };
          const seller = listingRaw.seller;
          const price = listingRaw.price;

          items.push({
            tokenId,
            owner,
            tokenUri,
            listingSeller: seller !== zeroAddress ? seller : undefined,
            listingPrice: seller !== zeroAddress ? price : undefined,
          });
        }
        setNftItems(items);
      } catch (error) {
        console.error('Failed to load NFTs', error);
      } finally {
        setIsLoadingNfts(false);
      }
    };

    if (isAppConfigured && nftAddress && marketAddress) {
      loadNfts();
    } else {
      setNftItems([]);
    }
  }, [publicClient, nftNextIdQuery.data]);

  const ensureContext = useCallback(() => {
    if (!isAppConfigured) {
      throw new Error('Set contract addresses in the .env file first.');
    }
    if (!publicClient) {
      throw new Error('Public client not ready.');
    }
    if (!address) {
      throw new Error('Connect wallet first.');
    }
    return {
      rpc: publicClient,
      account: address as Address,
    };
  }, [address, publicClient]);

  const handlePermitDeposit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setDepositStatus('');
    try {
      const { rpc, account } = ensureContext();
      if (!tokenAddress || !bankAddress) {
        throw new Error('Contracts not configured.');
      }
      const amount = parseUnits(depositAmount, tokenDecimals);
      if (amount <= 0n) {
        throw new Error('Enter amount bigger than zero.');
      }
      let deadlineSec: bigint;
      if (permitDepositDeadline.trim().length > 0) {
        const parsed = Number.parseInt(permitDepositDeadline, 10);
        if (Number.isNaN(parsed)) {
          throw new Error('Enter a valid permit deadline.');
        }
        deadlineSec = BigInt(parsed);
      } else {
        deadlineSec = BigInt(Math.floor(Date.now() / 1000) + 3600);
      }

      setDepositStatus('Fetching nonce...');
      const nonce = (await rpc.readContract({
        abi: tokenAbi,
        address: tokenAddress,
        functionName: 'nonces',
        args: [account],
      })) as bigint;

      const domainChainId = activeChainId ?? configuredChainId;

      setDepositStatus('Signing permit...');
      const signature = await signTypedDataAsync({
        domain: {
          name: tokenName,
          version: '1',
          chainId: Number(domainChainId),
          verifyingContract: tokenAddress,
        },
        types: {
          Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        primaryType: 'Permit',
        message: {
          owner: account,
          spender: bankAddress,
          value: amount,
          nonce,
          deadline: deadlineSec,
        },
      });

      const { r, s, v } = signatureToVrs(signature as `0x${string}`);

      setDepositStatus('Submitting deposit transaction...');
      const hash = await writeContractAsync({
        abi: bankAbi,
        address: bankAddress,
        functionName: 'permitDeposit',
        args: [account, amount, deadlineSec, v, r, s],
      });

      setDepositStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });

      setDepositStatus('Deposit confirmed.');
      setDepositAmount('');
      setPermitDepositDeadline('');
      refreshBalances();
    } catch (error) {
      console.error(error);
      setDepositStatus(error instanceof Error ? error.message : 'Permit deposit failed.');
    }
  };

  const handleTokenApproval = async () => {
    setTokenApprovalStatus('');
    try {
      const { rpc } = ensureContext();
      if (!tokenAddress || !marketAddress) {
        throw new Error('Contracts not configured.');
      }
      const value = parseUnits(tokenApprovalAmount, tokenDecimals);
      if (value <= 0n) {
        throw new Error('Enter amount bigger than zero.');
      }
      setTokenApprovalStatus('Submitting approval...');
      const hash = await writeContractAsync({
        abi: tokenAbi,
        address: tokenAddress,
        functionName: 'approve',
        args: [marketAddress, value],
      });
      setTokenApprovalStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setTokenApprovalStatus('Token allowance granted for marketplace.');
    } catch (error) {
      setTokenApprovalStatus(error instanceof Error ? error.message : 'Token approval failed.');
    }
  };

  const handleWithdraw = async () => {
    setWithdrawStatus('');
    try {
      const { rpc } = ensureContext();
      if (!bankAddress) {
        throw new Error('Bank address missing.');
      }
      if (bankUserBalance === 0n) {
        throw new Error('No balance to withdraw.');
      }
      setWithdrawStatus('Submitting withdrawal...');
      const hash = await writeContractAsync({
        abi: bankAbi,
        address: bankAddress,
        functionName: 'withdraw',
        args: [bankUserBalance],
      });
      setWithdrawStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setWithdrawStatus('Withdrawal confirmed.');
      refreshBalances();
    } catch (error) {
      setWithdrawStatus(error instanceof Error ? error.message : 'Withdrawal failed.');
    }
  };

  const handleNftApproval = async () => {
    setNftApprovalStatus('');
    try {
      const { rpc } = ensureContext();
      if (!nftAddress || !marketAddress) {
        throw new Error('Contracts not configured.');
      }
      setNftApprovalStatus('Granting NFT approval...');
      const hash = await writeContractAsync({
        abi: permitNftAbi,
        address: nftAddress,
        functionName: 'setApprovalForAll',
        args: [marketAddress, true],
      });
      setNftApprovalStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setNftApprovalStatus('Marketplace approved to manage your NFTs.');
    } catch (error) {
      setNftApprovalStatus(error instanceof Error ? error.message : 'Approval failed.');
    }
  };

  const handleMintNft = async () => {
    setMintStatus('');
    try {
      const { rpc, account } = ensureContext();
      if (!nftAddress) {
        throw new Error('NFT contract not configured.');
      }
      if (!isNftOwner) {
        throw new Error('Only the NFT contract owner can mint.');
      }
      setMintStatus('Minting NFT...');
      const hash = await writeContractAsync({
        abi: permitNftAbi,
        address: nftAddress,
        functionName: 'mintTo',
        args: [account, mintUri],
      });
      setMintStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setMintStatus('NFT minted.');
      refreshNfts();
    } catch (error) {
      setMintStatus(error instanceof Error ? error.message : 'Mint failed.');
    }
  };

  const handleListNft = async () => {
    setListStatus('');
    try {
      const { rpc } = ensureContext();
      if (!marketAddress || !nftAddress) {
        throw new Error('Marketplace not configured.');
      }
      const tokenIdNumeric = Number.parseInt(listTokenId, 10);
      if (Number.isNaN(tokenIdNumeric)) {
        throw new Error('Enter a valid token id.');
      }
      const price = parseUnits(listPrice, tokenDecimals);
      if (price <= 0n) {
        throw new Error('Enter a price greater than zero.');
      }
      setListStatus('Listing NFT...');
      const hash = await writeContractAsync({
        abi: marketAbi,
        address: marketAddress,
        functionName: 'list',
        args: [nftAddress, BigInt(tokenIdNumeric), price],
      });
      setListStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setListStatus('NFT listed on marketplace.');
      refreshNfts();
    } catch (error) {
      setListStatus(error instanceof Error ? error.message : 'Listing failed.');
    }
  };

  const handlePermitBuy = async () => {
    setPermitBuyStatus('');
    try {
      const { rpc } = ensureContext();
      if (!marketAddress || !nftAddress) {
        throw new Error('Marketplace not configured.');
      }
      const tokenIdNumeric = Number.parseInt(permitBuyTokenId, 10);
      if (Number.isNaN(tokenIdNumeric)) {
        throw new Error('Enter a valid token id.');
      }
      const price = parseUnits(permitBuyPrice, tokenDecimals);
      if (price <= 0n) {
        throw new Error('Enter a price greater than zero.');
      }
      if (permitBuySignature.trim().length === 0) {
        throw new Error('Paste the whitelist signature first.');
      }
      let deadlineSec: bigint;
      if (permitBuyDeadline.trim().length > 0) {
        const parsed = Number.parseInt(permitBuyDeadline, 10);
        if (Number.isNaN(parsed)) {
          throw new Error('Enter a valid permit deadline.');
        }
        deadlineSec = BigInt(parsed);
      } else {
        deadlineSec = BigInt(Math.floor(Date.now() / 1000) + 3600);
      }

      setPermitBuyStatus('Submitting permit buy...');
      const hash = await writeContractAsync({
        abi: marketAbi,
        address: marketAddress,
        functionName: 'permitBuy',
        args: [nftAddress, BigInt(tokenIdNumeric), price, deadlineSec, permitBuySignature as `0x${string}`],
      });
      setPermitBuyStatus('Waiting for confirmation...');
      await rpc.waitForTransactionReceipt({ hash });
      setPermitBuyStatus('NFT purchased!');
      setPermitBuyTokenId('');
      setPermitBuyPrice('');
      setPermitBuyDeadline('');
      setPermitBuySignature('');
      refreshBalances();
      refreshNfts();
    } catch (error) {
      setPermitBuyStatus(error instanceof Error ? error.message : 'Permit buy failed.');
    }
  };

  const handleGenerateWhitelistSignature = async () => {
    setWhitelistStatus('');
    setGeneratedSignature('');
    try {
      ensureContext();
      if (!marketAddress || !nftAddress) {
        throw new Error('Marketplace not configured.');
      }
      if (!isWhitelistSigner) {
        throw new Error('Only the whitelist signer can generate signatures.');
      }
      const addressRegex = /^0x[a-fA-F0-9]{40}$/;
      if (!whitelistBuyerAddress || !addressRegex.test(whitelistBuyerAddress)) {
        throw new Error('Enter a valid buyer address.');
      }
      const tokenIdNumeric = Number.parseInt(whitelistTokenId, 10);
      if (Number.isNaN(tokenIdNumeric)) {
        throw new Error('Enter a valid token id.');
      }
      const price = parseUnits(whitelistPrice, tokenDecimals);
      if (price <= 0n) {
        throw new Error('Enter a price greater than zero.');
      }
      let deadlineSec: bigint;
      if (whitelistDeadline.trim().length > 0) {
        const parsed = Number.parseInt(whitelistDeadline, 10);
        if (Number.isNaN(parsed)) {
          throw new Error('Enter a valid deadline.');
        }
        deadlineSec = BigInt(parsed);
      } else {
        deadlineSec = BigInt(Math.floor(Date.now() / 1000) + 3600);
      }

      const domainChainId = activeChainId ?? configuredChainId;

      setWhitelistStatus('Signing whitelist permit...');
      const signature = await signTypedDataAsync({
        domain: {
          name: 'PermitNFTMarket',
          version: '1',
          chainId: Number(domainChainId),
          verifyingContract: marketAddress,
        },
        types: {
          PermitBuy: [
            { name: 'buyer', type: 'address' },
            { name: 'nft', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'price', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        primaryType: 'PermitBuy',
        message: {
          buyer: whitelistBuyerAddress as Address,
          nft: nftAddress,
          tokenId: BigInt(tokenIdNumeric),
          price,
          deadline: deadlineSec,
        },
      });

      setGeneratedSignature(signature);
      setWhitelistStatus('Signature generated! Copy and share with the buyer.');
    } catch (error) {
      console.error(error);
      setWhitelistStatus(error instanceof Error ? error.message : 'Signature generation failed.');
    }
  };

  const activeChainLabel = useMemo(() => {
    const chain = activeChainId ?? configuredChainId;
    return `Chain ID: ${chain}`;
  }, [activeChainId]);

  return (
    <div className="app">
      <header className="app__hero">
        <div className="app__hero-surface">
          <div className="app__hero-content">
            <div className="app__hero-text">
              <span className="app__hero-badge">{activeChainLabel}</span>
              <h1>Permit Token Bank &amp; NFT Market</h1>
              <p className="app__hero-subtitle">
                Manage deposits, NFT mints, and whitelist purchases from a single dashboard.
              </p>
            </div>
            <div className="app__hero-wallet">
              <w3m-button />
            </div>
          </div>
        </div>
        {isAppConfigured && (
          <div className="app__contract-panel">
            <h2>Deployment details</h2>
            <div className="app__contract-grid">
              <div className="app__contract">
                <span className="app__contract-label">Bank</span>
                <a
                  className="app__contract-value app__contract-link"
                  href={bankAddress ? getAddressUrl(bankAddress) : '#'}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {bankAddress}
                </a>
              </div>
              <div className="app__contract">
                <span className="app__contract-label">Token</span>
                <a
                  className="app__contract-value app__contract-link"
                  href={tokenAddress ? getAddressUrl(tokenAddress) : '#'}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {tokenAddress}
                </a>
              </div>
              <div className="app__contract">
                <span className="app__contract-label">NFT</span>
                <a
                  className="app__contract-value app__contract-link"
                  href={nftAddress ? getAddressUrl(nftAddress) : '#'}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {nftAddress}
                </a>
              </div>
              <div className="app__contract">
                <span className="app__contract-label">Marketplace</span>
                <a
                  className="app__contract-value app__contract-link"
                  href={marketAddress ? getAddressUrl(marketAddress) : '#'}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {marketAddress}
                </a>
              </div>
              {whitelistSignerAddress && (
                <div className="app__contract">
                  <span className="app__contract-label">Whitelist signer</span>
                  <a
                    className="app__contract-value app__contract-link"
                    href={getAddressUrl(whitelistSignerAddress)}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {whitelistSignerAddress}
                  </a>
                </div>
              )}
            </div>
          </div>
        )}
      </header>

      {!isAppConfigured && (
        <div className="status status--warning">
          Configure VITE_BANK_ADDRESS, VITE_TOKEN_ADDRESS, VITE_NFT_ADDRESS and VITE_MARKET_ADDRESS before using the dApp.
        </div>
      )}

      <section className="card">
        <h2>{tokenName} overview</h2>
        <p className="balance">
          Wallet: {formattedWalletBalance} {tokenSymbol}
        </p>
        <p className="balance">
          In bank: {formattedBankUserBalance} {tokenSymbol}
        </p>
        <p className="balance">
          Bank vault: {formattedBankVaultBalance} {tokenSymbol}
        </p>
        <div className="top-depositors">
          <h3>Top depositors</h3>
          <ol>
            {topDepositors.map((depositor, index) => (
              <li key={`${depositor}-${index}`}>
                <span>{index + 1}.</span>
                <span>{depositor === zeroAddress ? '—' : depositor}</span>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="card">
        <h2>Permit deposit</h2>
        <form className="form" onSubmit={handlePermitDeposit}>
          <label className="form__row">
            <span>Amount ({tokenSymbol})</span>
            <input
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder="10"
              type="text"
            />
          </label>
          <label className="form__row">
            <span>Permit deadline (unix seconds, optional)</span>
            <input
              value={permitDepositDeadline}
              onChange={(event) => setPermitDepositDeadline(event.target.value)}
              placeholder="Defaults to +1 hour"
              type="text"
            />
          </label>
          <button className="button" type="submit">
            Sign &amp; deposit
          </button>
        </form>
        {depositStatus && <p className="status">{depositStatus}</p>}
      </section>

      <section className="card">
        <h2>Withdraw</h2>
        <p className="hint">Withdraw sends your full deposit back to your wallet.</p>
        <button
          className="button"
          type="button"
          onClick={handleWithdraw}
          disabled={bankUserBalance === 0n}
        >
          Withdraw {formattedBankUserBalance} {tokenSymbol}
        </button>
        {withdrawStatus && <p className="status">{withdrawStatus}</p>}
      </section>

      <section className="card">
        <h2>NFT marketplace</h2>
        <div className="card__grid">
          <div className="card__column">
            <h3>Your setup</h3>
            <div className="form">
              <label className="form__row">
                <span>Approve tokens for marketplace ({tokenSymbol})</span>
                <input
                  value={tokenApprovalAmount}
                  onChange={(event) => setTokenApprovalAmount(event.target.value)}
                  placeholder="5"
                  type="text"
                />
              </label>
              <button className="button" type="button" onClick={handleTokenApproval}>
                Approve tokens
              </button>
              {tokenApprovalStatus && <p className="status">{tokenApprovalStatus}</p>}
              <button className="button button--outline" type="button" onClick={handleNftApproval}>
                Approve NFT operator
              </button>
              {nftApprovalStatus && <p className="status">{nftApprovalStatus}</p>}
            </div>
            {isNftOwner && (
              <div className="form">
                <h3>Mint (owner only)</h3>
                <label className="form__row">
                  <span>Token URI</span>
                  <input
                    value={mintUri}
                    onChange={(event) => setMintUri(event.target.value)}
                    placeholder="ipfs://..."
                    type="text"
                  />
                </label>
                <button className="button" type="button" onClick={handleMintNft}>
                  Mint NFT
                </button>
                {mintStatus && <p className="status">{mintStatus}</p>}
              </div>
            )}
          </div>
          <div className="card__column">
            <h3>List existing NFT</h3>
            <div className="form">
              <label className="form__row">
                <span>Token ID</span>
                <input
                  value={listTokenId}
                  onChange={(event) => setListTokenId(event.target.value)}
                  placeholder="0"
                  type="text"
                />
              </label>
              <label className="form__row">
                <span>Price ({tokenSymbol})</span>
                <input
                  value={listPrice}
                  onChange={(event) => setListPrice(event.target.value)}
                  placeholder="1"
                  type="text"
                />
              </label>
              <button className="button" type="button" onClick={handleListNft}>
                List NFT
              </button>
              {listStatus && <p className="status">{listStatus}</p>}
            </div>
          </div>
        </div>
      </section>

      <section className="card">
        <h2>Permit buy</h2>
        <div className="form">
          <label className="form__row">
            <span>Token ID</span>
            <input
              value={permitBuyTokenId}
              onChange={(event) => setPermitBuyTokenId(event.target.value)}
              placeholder="0"
              type="text"
            />
          </label>
          <label className="form__row">
            <span>Price ({tokenSymbol})</span>
            <input
              value={permitBuyPrice}
              onChange={(event) => setPermitBuyPrice(event.target.value)}
              placeholder="1"
              type="text"
            />
          </label>
          <label className="form__row">
            <span>Permit deadline (unix seconds, optional)</span>
            <input
              value={permitBuyDeadline}
              onChange={(event) => setPermitBuyDeadline(event.target.value)}
              placeholder="Defaults to +1 hour"
              type="text"
            />
          </label>
          <label className="form__row">
            <span>Whitelist signature (0x…)</span>
            <input
              value={permitBuySignature}
              onChange={(event) => setPermitBuySignature(event.target.value)}
              placeholder="0x"
              type="text"
            />
          </label>
          <button className="button" type="button" onClick={handlePermitBuy}>
            Permit buy NFT
          </button>
          {permitBuyStatus && <p className="status">{permitBuyStatus}</p>}
          <span className="hint">
            Obtain ALL parameters (token ID, price, deadline, signature) from the whitelist signer. All values must match exactly what was signed.
          </span>
        </div>
      </section>

      {isWhitelistSigner && (
        <section className="card">
          <h2>Generate whitelist signature (Signer only)</h2>
          <p className="hint">
            As the whitelist signer, you can generate signatures to authorize specific buyers to purchase NFTs.
          </p>
          <p className="hint" style={{ color: '#f59e0b', fontWeight: 'bold' }}>
            ⚠️ Important: Share ALL parameters (buyer address, token ID, price, deadline) along with the signature. The buyer needs every detail to complete the purchase.
          </p>
          <div className="form">
            <label className="form__row">
              <span>Buyer address</span>
              <input
                value={whitelistBuyerAddress}
                onChange={(event) => setWhitelistBuyerAddress(event.target.value)}
                placeholder="0x..."
                type="text"
              />
            </label>
            <label className="form__row">
              <span>Token ID</span>
              <input
                value={whitelistTokenId}
                onChange={(event) => setWhitelistTokenId(event.target.value)}
                placeholder="0"
                type="text"
              />
            </label>
            <label className="form__row">
              <span>Price ({tokenSymbol})</span>
              <input
                value={whitelistPrice}
                onChange={(event) => setWhitelistPrice(event.target.value)}
                placeholder="1"
                type="text"
              />
            </label>
            <label className="form__row">
              <span>Deadline (unix seconds, optional)</span>
              <input
                value={whitelistDeadline}
                onChange={(event) => setWhitelistDeadline(event.target.value)}
                placeholder="Defaults to +1 hour"
                type="text"
              />
            </label>
            <button className="button" type="button" onClick={handleGenerateWhitelistSignature}>
              Generate signature
            </button>
            {whitelistStatus && <p className="status">{whitelistStatus}</p>}
            {generatedSignature && (
              <div>
                <label className="form__row">
                  <span>Generated signature (share with buyer)</span>
                  <textarea
                    value={generatedSignature}
                    readOnly
                    rows={3}
                    style={{ fontFamily: 'monospace', fontSize: '0.85em' }}
                    onClick={(e) => {
                      e.currentTarget.select();
                      navigator.clipboard.writeText(generatedSignature);
                    }}
                  />
                </label>
                <span className="hint">Click the signature to copy it to clipboard.</span>
              </div>
            )}
          </div>
        </section>
      )}

      <section className="card">
        <h2>Minted NFTs ({nextTokenId})</h2>
        {isLoadingNfts ? (
          <p className="status">Loading NFTs...</p>
        ) : nftItems.length === 0 ? (
          <p className="hint">No NFTs minted yet.</p>
        ) : (
          <ul className="nft-list">
            {nftItems.map((item) => (
              <li key={item.tokenId} className="nft-list__item">
                <div>
                  <strong>ID:</strong> {item.tokenId}
                </div>
                <div>
                  <strong>Owner:</strong> {item.owner}
                </div>
                <div>
                  <strong>URI:</strong> {item.tokenUri}
                </div>
                <div>
                  <strong>Listing:</strong>{' '}
                  {item.listingSeller
                    ? `${formatUnits(item.listingPrice ?? 0n, tokenDecimals)} ${tokenSymbol} (seller: ${item.listingSeller})`
                    : 'Not listed'}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

export default App;
