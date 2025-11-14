import { useCallback, useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import {
  useAccount,
  useConnect,
  useDisconnect,
  usePublicClient,
  useReadContract,
  useSignTypedData,
  useWriteContract,
} from 'wagmi';
import type { Address } from 'viem';
import { formatUnits, parseUnits } from 'viem';
import { bankAbi } from './abi/bank';
import { tokenAbi } from './abi/token';
import { bankAddress, chainId, chainName, isAppConfigured, permit2Address, tokenAddress } from './config';
import './App.css';

const shortenAddress = (value?: Address | string) => {
  if (!value) {
    return '';
  }
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
};

const randomUint256 = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    return bytes.reduce((acc, byte) => (acc << 8n) | BigInt(byte), 0n);
  }
  return BigInt(Date.now());
};

function App() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, error: connectError, isPending: isConnecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const { signTypedDataAsync } = useSignTypedData();
  const [connectingConnectorId, setConnectingConnectorId] = useState('');

  const [tokenApprovalAmount, setTokenApprovalAmount] = useState('100');
  const [permitApprovalAmount, setPermitApprovalAmount] = useState('100');
  const [depositAmount, setDepositAmount] = useState('10');
  const [permitDepositAmount, setPermitDepositAmount] = useState('5');
  const [permitMinutes, setPermitMinutes] = useState('10');
  const [depositStatus, setDepositStatus] = useState('');
  const [permitDepositStatus, setPermitDepositStatus] = useState('');
  const [withdrawStatus, setWithdrawStatus] = useState('');
  const [tokenApprovalStatus, setTokenApprovalStatus] = useState('');
  const [permitApprovalStatus, setPermitApprovalStatus] = useState('');

  useEffect(() => {
    if (!isConnecting) {
      setConnectingConnectorId('');
    }
  }, [isConnecting]);

  const decimalsQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'decimals',
    query: { enabled: isAppConfigured && Boolean(tokenAddress) },
  });

  const symbolQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'symbol',
    query: { enabled: isAppConfigured && Boolean(tokenAddress) },
  });

  const walletBalanceQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'balanceOf',
    args: address && tokenAddress ? [address] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && tokenAddress) },
  });

  const bankUserBalanceQuery = useReadContract({
    abi: bankAbi,
    address: bankAddress,
    functionName: 'balances',
    args: address && bankAddress ? [address] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && bankAddress) },
  });

  const bankVaultQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'balanceOf',
    args: bankAddress && tokenAddress ? [bankAddress] : undefined,
    query: { enabled: isAppConfigured && Boolean(bankAddress && tokenAddress) },
  });

  const topDepositorsQuery = useReadContract({
    abi: bankAbi,
    address: bankAddress,
    functionName: 'getTopDepositors',
    query: { enabled: isAppConfigured && Boolean(bankAddress) },
  });

  const bankAllowanceQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'allowance',
    args: address && bankAddress ? [address, bankAddress] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && bankAddress && tokenAddress) },
  });

  const permitAllowanceQuery = useReadContract({
    abi: tokenAbi,
    address: tokenAddress,
    functionName: 'allowance',
    args: address && permit2Address ? [address, permit2Address] : undefined,
    query: { enabled: isAppConfigured && Boolean(address && permit2Address && tokenAddress) },
  });

  const tokenDecimals = useMemo(() => {
    const raw = decimalsQuery.data;
    if (typeof raw === 'number') {
      return raw;
    }
    if (typeof raw === 'bigint') {
      return Number(raw);
    }
    return 18;
  }, [decimalsQuery.data]);

  const tokenSymbol = typeof symbolQuery.data === 'string' ? symbolQuery.data : 'TOKEN';
  const walletTokenBalance = typeof walletBalanceQuery.data === 'bigint' ? walletBalanceQuery.data : 0n;
  const bankUserBalance = typeof bankUserBalanceQuery.data === 'bigint' ? bankUserBalanceQuery.data : 0n;
  const bankVaultBalance = typeof bankVaultQuery.data === 'bigint' ? bankVaultQuery.data : 0n;
  const bankAllowance = typeof bankAllowanceQuery.data === 'bigint' ? bankAllowanceQuery.data : 0n;
  const permitAllowance = typeof permitAllowanceQuery.data === 'bigint' ? permitAllowanceQuery.data : 0n;
  const topDepositors = Array.isArray(topDepositorsQuery.data)
    ? (topDepositorsQuery.data.filter((item) => item !== '0x0000000000000000000000000000000000000000') as Address[])
    : [];

  const refreshData = useCallback(() => {
    walletBalanceQuery.refetch?.();
    bankUserBalanceQuery.refetch?.();
    bankVaultQuery.refetch?.();
    topDepositorsQuery.refetch?.();
    bankAllowanceQuery.refetch?.();
    permitAllowanceQuery.refetch?.();
  }, [
    walletBalanceQuery,
    bankUserBalanceQuery,
    bankVaultQuery,
    topDepositorsQuery,
    bankAllowanceQuery,
    permitAllowanceQuery,
  ]);

  const ensureReady = (setMessage: (value: string) => void) => {
    if (!isConnected || !address) {
      setMessage('Connect wallet first.');
      return false;
    }
    if (!isAppConfigured || !bankAddress || !tokenAddress) {
      setMessage('Fill env settings first.');
      return false;
    }
    if (!publicClient) {
      setMessage('RPC client not ready.');
      return false;
    }
    return true;
  };

  const handleConnect = (connector: typeof connectors[number]) => {
    if (isConnecting) {
      return;
    }
    setConnectingConnectorId(connector.uid);
    connect({ connector });
  };

  const handleApproveBank = async () => {
    setTokenApprovalStatus('');
    if (!ensureReady(setTokenApprovalStatus) || !bankAddress || !tokenAddress) {
      return;
    }
    try {
      const amount = parseUnits(tokenApprovalAmount, tokenDecimals);
      if (amount <= 0n) {
        setTokenApprovalStatus('Enter amount bigger than zero.');
        return;
      }
      setTokenApprovalStatus('Signing approval...');
      const hash = await writeContractAsync({
        abi: tokenAbi,
        address: tokenAddress,
        functionName: 'approve',
        args: [bankAddress, amount],
      });
      setTokenApprovalStatus('Waiting for confirmation...');
      await publicClient!.waitForTransactionReceipt({ hash });
      setTokenApprovalStatus('Bank allowance updated.');
      bankAllowanceQuery.refetch?.();
    } catch (error) {
      setTokenApprovalStatus((error as Error).message ?? 'Approval failed.');
    }
  };

  const handleApprovePermit2 = async () => {
    setPermitApprovalStatus('');
    if (!ensureReady(setPermitApprovalStatus) || !tokenAddress || !permit2Address) {
      return;
    }
    try {
      const amount = parseUnits(permitApprovalAmount, tokenDecimals);
      if (amount <= 0n) {
        setPermitApprovalStatus('Enter amount bigger than zero.');
        return;
      }
      setPermitApprovalStatus('Signing approval...');
      const hash = await writeContractAsync({
        abi: tokenAbi,
        address: tokenAddress,
        functionName: 'approve',
        args: [permit2Address, amount],
      });
      setPermitApprovalStatus('Waiting for confirmation...');
      await publicClient!.waitForTransactionReceipt({ hash });
      setPermitApprovalStatus('Permit2 allowance updated.');
      permitAllowanceQuery.refetch?.();
    } catch (error) {
      setPermitApprovalStatus((error as Error).message ?? 'Approval failed.');
    }
  };

  const handleDeposit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setDepositStatus('');
    if (!ensureReady(setDepositStatus) || !bankAddress) {
      return;
    }
    try {
      const amount = parseUnits(depositAmount, tokenDecimals);
      if (amount <= 0n) {
        setDepositStatus('Enter amount bigger than zero.');
        return;
      }
      if (bankAllowance < amount) {
        setDepositStatus('Approve the bank first.');
        return;
      }
      setDepositStatus('Signing transaction...');
      const hash = await writeContractAsync({
        abi: bankAbi,
        address: bankAddress,
        functionName: 'deposit',
        args: [amount],
      });
      setDepositStatus('Waiting for confirmation...');
      await publicClient!.waitForTransactionReceipt({ hash });
      setDepositStatus('Deposit confirmed.');
      setDepositAmount('');
      refreshData();
    } catch (error) {
      setDepositStatus((error as Error).message ?? 'Deposit failed.');
    }
  };

  const handlePermitDeposit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPermitDepositStatus('');
    if (!ensureReady(setPermitDepositStatus) || !bankAddress || !tokenAddress || !signTypedDataAsync) {
      return;
    }
    try {
      const amount = parseUnits(permitDepositAmount, tokenDecimals);
      if (amount <= 0n) {
        setPermitDepositStatus('Enter amount bigger than zero.');
        return;
      }
      if (permitAllowance < amount) {
        setPermitDepositStatus('Approve Permit2 first.');
        return;
      }
      const minutes = Number.parseInt(permitMinutes, 10);
      const ttl = Number.isNaN(minutes) ? 10 : Math.max(minutes, 1);
      const deadline = BigInt(Math.floor(Date.now() / 1000) + ttl * 60);
      const nonce = randomUint256();

      setPermitDepositStatus('Sign the permit in your wallet...');
      const signature = await signTypedDataAsync({
        domain: {
          name: 'Permit2',
          chainId,
          verifyingContract: permit2Address,
        },
        types: {
          PermitTransferFrom: [
            { name: 'permitted', type: 'TokenPermissions' },
            { name: 'spender', type: 'address' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
          TokenPermissions: [
            { name: 'token', type: 'address' },
            { name: 'amount', type: 'uint256' },
          ],
        },
        primaryType: 'PermitTransferFrom',
        message: {
          permitted: { token: tokenAddress, amount },
          spender: bankAddress,
          nonce,
          deadline,
        },
      });

      setPermitDepositStatus('Sending deposit...');
      const hash = await writeContractAsync({
        abi: bankAbi,
        address: bankAddress,
        functionName: 'depositWithPermit2',
        args: [
          {
            permitted: { token: tokenAddress, amount },
            nonce,
            deadline,
          },
          {
            to: bankAddress,
            requestedAmount: amount,
          },
          address!,
          signature,
        ],
      });
      setPermitDepositStatus('Waiting for confirmation...');
      await publicClient!.waitForTransactionReceipt({ hash });
      setPermitDepositStatus('Permit deposit confirmed.');
      setPermitDepositAmount('');
      refreshData();
    } catch (error) {
      setPermitDepositStatus((error as Error).message ?? 'Permit deposit failed.');
    }
  };

  const handleWithdraw = async () => {
    setWithdrawStatus('');
    if (!ensureReady(setWithdrawStatus) || !bankAddress) {
      return;
    }
    if (bankUserBalance === 0n) {
      setWithdrawStatus('Nothing to withdraw.');
      return;
    }
    try {
      setWithdrawStatus('Signing transaction...');
      const hash = await writeContractAsync({
        abi: bankAbi,
        address: bankAddress,
        functionName: 'withdraw',
        args: [bankUserBalance],
      });
      setWithdrawStatus('Waiting for confirmation...');
      await publicClient!.waitForTransactionReceipt({ hash });
      setWithdrawStatus('Withdraw confirmed.');
      refreshData();
    } catch (error) {
      setWithdrawStatus((error as Error).message ?? 'Withdraw failed.');
    }
  };

  const formattedWallet = formatUnits(walletTokenBalance, tokenDecimals);
  const formattedBankUser = formatUnits(bankUserBalance, tokenDecimals);
  const formattedVault = formatUnits(bankVaultBalance, tokenDecimals);
  const formattedBankAllowance = formatUnits(bankAllowance, tokenDecimals);
  const formattedPermitAllowance = formatUnits(permitAllowance, tokenDecimals);

  return (
    <div className="app">
      <header className="app__header">
        <h1>Token Bank (Permit2)</h1>
        <p className="app__contract">
          Bank:{' '}
          <span>{bankAddress ?? 'not set'}</span>
        </p>
        <p className="app__contract">
          Token:{' '}
          <span>{tokenAddress ?? 'not set'}</span>
        </p>
        <p className="app__contract">
          Permit2:{' '}
          <span>{permit2Address}</span>
        </p>
        <p className="app__contract">
          Chain:{' '}
          <span>{chainName}</span>
        </p>
        <div className="wallet">
          {isConnected ? (
            <>
              <span className="wallet__address">{address}</span>
              <button className="button" onClick={() => disconnect()}>
                Disconnect
              </button>
            </>
          ) : (
            <div className="wallet__connectors">
              {connectors.length === 0 && <span className="hint">No wallet connectors found.</span>}
              {connectors.map((connector) => {
                const isActive = connectingConnectorId === connector.uid && isConnecting;
                return (
                  <div key={connector.uid} className="wallet__connector">
                    <div className="wallet__connector-row">
                      <div className="wallet__connector-meta">
                        <strong>{connector.name}</strong>
                      </div>
                      <button
                        className="button button--outline"
                        onClick={() => handleConnect(connector)}
                        disabled={isConnecting && !isActive}
                      >
                        {isActive ? 'Connecting...' : 'Connect'}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
        {connectError && <p className="status status--error">{connectError.message}</p>}
      </header>

      {!isAppConfigured && (
        <div className="status status--warning">Set VITE_BANK_ADDRESS & VITE_TOKEN_ADDRESS first.</div>
      )}

      <section className="card">
        <h2>Your wallet</h2>
        <p className="balance">{`${formattedWallet} ${tokenSymbol}`}</p>
      </section>

      <section className="card">
        <h2>Your deposit</h2>
        <p className="balance">{`${formattedBankUser} ${tokenSymbol}`}</p>
      </section>

      <section className="card">
        <h2>Bank vault</h2>
        <p className="balance">{`${formattedVault} ${tokenSymbol}`}</p>
      </section>

      <section className="card">
        <h2>Allowances</h2>
        <div className="form__row">
          <div>
            <strong>Bank allowance</strong>
            <p className="hint">{`${formattedBankAllowance} ${tokenSymbol}`}</p>
          </div>
          <div className="form__row">
            <input
              value={tokenApprovalAmount}
              onChange={(event) => setTokenApprovalAmount(event.target.value)}
              type="text"
            />
            <button className="button button--outline" type="button" onClick={handleApproveBank}>
              Approve bank
            </button>
          </div>
        </div>
        {tokenApprovalStatus && <p className="status">{tokenApprovalStatus}</p>}
        <hr />
        <div className="form__row">
          <div>
            <strong>Permit2 allowance</strong>
            <p className="hint">{`${formattedPermitAllowance} ${tokenSymbol}`}</p>
          </div>
          <div className="form__row">
            <input
              value={permitApprovalAmount}
              onChange={(event) => setPermitApprovalAmount(event.target.value)}
              type="text"
            />
            <button className="button button--outline" type="button" onClick={handleApprovePermit2}>
              Approve Permit2
            </button>
          </div>
        </div>
        {permitApprovalStatus && <p className="status">{permitApprovalStatus}</p>}
      </section>

      <section className="card">
        <h2>Direct deposit</h2>
        <form className="form" onSubmit={handleDeposit}>
          <label className="form__row">
            <span>Amount ({tokenSymbol})</span>
            <input
              type="text"
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder="10"
            />
          </label>
          <button className="button" type="submit">
            Deposit with allowance
          </button>
        </form>
        {depositStatus && <p className="status">{depositStatus}</p>}
      </section>

      <section className="card">
        <h2>Permit2 deposit</h2>
        <form className="form" onSubmit={handlePermitDeposit}>
          <label className="form__row">
            <span>Amount ({tokenSymbol})</span>
            <input
              type="text"
              value={permitDepositAmount}
              onChange={(event) => setPermitDepositAmount(event.target.value)}
              placeholder="5"
            />
          </label>
          <label className="form__row">
            <span>Permit expiry (minutes)</span>
            <input
              type="number"
              value={permitMinutes}
              min="1"
              onChange={(event) => setPermitMinutes(event.target.value)}
            />
          </label>
          <button className="button" type="submit">
            Sign and deposit
          </button>
        </form>
        {permitDepositStatus && <p className="status">{permitDepositStatus}</p>}
      </section>

      <section className="card">
        <h2>Withdraw</h2>
        <p className="hint">Withdraw sends your full deposit back to your wallet.</p>
        <button className="button" type="button" onClick={handleWithdraw} disabled={bankUserBalance === 0n}>
          Withdraw {formattedBankUser} {tokenSymbol}
        </button>
        {withdrawStatus && <p className="status">{withdrawStatus}</p>}
      </section>

      <section className="card">
        <h2>Top depositors</h2>
        {topDepositors.length === 0 && <p className="hint">No depositors yet.</p>}
        {topDepositors.length > 0 && (
          <ol>
            {topDepositors.map((account) => (
              <li key={account}>{shortenAddress(account)}</li>
            ))}
          </ol>
        )}
      </section>
    </div>
  );
}

export default App;
