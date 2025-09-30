import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import {
  useAccount,
  useBalance,
  useConnect,
  useDisconnect,
  useReadContract,
  useSendTransaction,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'
import { formatEther, parseEther } from 'viem'
import type { Address } from 'viem'
import { bankAbi } from './abi/bank'
import { bankAddress, isBankConfigured } from './config'
import './App.css'

const addressPattern = /^0x[a-fA-F0-9]{40}$/

function App() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, error: connectError, isPending: isConnecting } = useConnect()
  const { disconnect } = useDisconnect()
  const [depositAmount, setDepositAmount] = useState('0.01')
  const [depositFormError, setDepositFormError] = useState('')
  const { sendTransaction, data: depositHash, error: depositError, isPending: isDepositSigning } =
    useSendTransaction()
  const depositReceipt = useWaitForTransactionReceipt({ hash: depositHash })

  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [withdrawRecipient, setWithdrawRecipient] = useState('')
  const [withdrawFormError, setWithdrawFormError] = useState('')
  const { writeContract, data: withdrawHash, error: withdrawError, isPending: isWithdrawSigning } =
    useWriteContract()
  const withdrawReceipt = useWaitForTransactionReceipt({ hash: withdrawHash })

  useEffect(() => {
    if (address && withdrawRecipient.length === 0) {
      setWithdrawRecipient(address)
    }
  }, [address, withdrawRecipient])

  const contractAddress: Address | undefined = isBankConfigured ? (bankAddress as Address) : undefined

  const { data: adminAddress } = useReadContract({
    abi: bankAbi,
    address: contractAddress,
    functionName: 'admin',
    query: {
      enabled: isBankConfigured,
    },
  })

  const isAdmin = useMemo(() => {
    if (!address || !adminAddress) {
      return false
    }
    return address.toLowerCase() === (adminAddress as string).toLowerCase()
  }, [address, adminAddress])

  const {
    data: rawUserBalance,
    refetch: refetchUserBalance,
    isFetching: isUserBalanceLoading,
  } = useReadContract({
    abi: bankAbi,
    address: contractAddress,
    functionName: 'balances',
    args: address ? [address] : undefined,
    query: {
      enabled: isBankConfigured && Boolean(address),
    },
  })

  const {
    data: bankEthBalance,
    refetch: refetchBankBalance,
    isFetching: isBankBalanceLoading,
  } = useBalance({
    address: contractAddress,
    query: {
      enabled: isBankConfigured,
    },
  })

  const userBalance = typeof rawUserBalance === 'bigint' ? rawUserBalance : 0n
  const formattedUserBalance = formatEther(userBalance)
  const formattedBankBalance = bankEthBalance ? bankEthBalance.formatted : '0'

  useEffect(() => {
    if (depositReceipt.isSuccess) {
      setDepositAmount('')
      refetchUserBalance()
      refetchBankBalance()
    }
  }, [depositReceipt.isSuccess, refetchUserBalance, refetchBankBalance])

  useEffect(() => {
    if (withdrawReceipt.isSuccess) {
      setWithdrawAmount('')
      refetchUserBalance()
      refetchBankBalance()
    }
  }, [withdrawReceipt.isSuccess, refetchUserBalance, refetchBankBalance])

  const handleDeposit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setDepositFormError('')
    if (!isConnected || !address) {
      setDepositFormError('Connect wallet first.')
      return
    }
    if (!isBankConfigured || !contractAddress) {
      setDepositFormError('Set bank address in env file.')
      return
    }
    try {
      const value = parseEther(depositAmount)
      if (value <= 0n) {
        setDepositFormError('Enter amount bigger than zero.')
        return
      }
      sendTransaction({
        to: contractAddress,
        value,
      })
    } catch {
      setDepositFormError('Enter a valid number.')
    }
  }

  const handleWithdraw = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setWithdrawFormError('')
    if (!isConnected || !address) {
      setWithdrawFormError('Connect wallet first.')
      return
    }
    if (!isBankConfigured || !contractAddress) {
      setWithdrawFormError('Set bank address in env file.')
      return
    }
    if (!isAdmin) {
      setWithdrawFormError('Only admin can withdraw.')
      return
    }
    if (!addressPattern.test(withdrawRecipient)) {
      setWithdrawFormError('Enter a valid recipient.')
      return
    }
    try {
      const value = parseEther(withdrawAmount)
      if (value <= 0n) {
        setWithdrawFormError('Enter amount bigger than zero.')
        return
      }
      writeContract({
        abi: bankAbi,
        address: contractAddress,
        functionName: 'withdraw',
        args: [withdrawRecipient, value],
      })
    } catch {
      setWithdrawFormError('Enter a valid number.')
    }
  }

  const depositStatusMessage = useMemo(() => {
    if (depositFormError) {
      return depositFormError
    }
    if (depositError) {
      return depositError.message ?? 'Transaction failed.'
    }
    if (depositReceipt.isLoading) {
      return 'Waiting for confirmation...'
    }
    if (depositReceipt.isSuccess) {
      return 'Deposit confirmed.'
    }
    if (isDepositSigning) {
      return 'Confirm in wallet...'
    }
    return ''
  }, [depositError, depositFormError, depositReceipt.isLoading, depositReceipt.isSuccess, isDepositSigning])

  const withdrawStatusMessage = useMemo(() => {
    if (withdrawFormError) {
      return withdrawFormError
    }
    if (withdrawError) {
      return withdrawError.message ?? 'Transaction failed.'
    }
    if (withdrawReceipt.isLoading) {
      return 'Waiting for confirmation...'
    }
    if (withdrawReceipt.isSuccess) {
      return 'Withdraw confirmed.'
    }
    if (isWithdrawSigning) {
      return 'Confirm in wallet...'
    }
    return ''
  }, [
    isWithdrawSigning,
    withdrawError,
    withdrawFormError,
    withdrawReceipt.isLoading,
    withdrawReceipt.isSuccess,
  ])

  return (
    <div className="app">
      <header className="app__header">
        <h1>Token Bank</h1>
        <div className="wallet">
          {isConnected ? (
            <>
              <span className="wallet__address">{address}</span>
              <button className="button" onClick={() => disconnect()}>
                Disconnect
              </button>
            </>
          ) : (
            <button
              className="button"
              onClick={() => connectors.length > 0 && connect({ connector: connectors[0] })}
              disabled={isConnecting || connectors.length === 0}
            >
              {isConnecting ? 'Connecting...' : 'Connect Wallet'}
            </button>
          )}
        </div>
        {connectError && <p className="status status--error">{connectError.message}</p>}
      </header>

      {!isBankConfigured && (
        <div className="status status--warning">Set VITE_BANK_ADDRESS before using the dApp.</div>
      )}

      <section className="card">
        <h2>Your deposit</h2>
        <p className="balance">
          {isUserBalanceLoading ? 'Loading...' : `${formattedUserBalance} ETH`}
        </p>
      </section>

      <section className="card">
        <h2>Bank vault</h2>
        <p className="balance">
          {isBankBalanceLoading ? 'Loading...' : `${formattedBankBalance} ETH`}
        </p>
      </section>

      <section className="card">
        <h2>Deposit</h2>
        <form className="form" onSubmit={handleDeposit}>
          <label className="form__row">
            <span>Amount (ETH)</span>
            <input
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder="0.1"
              type="text"
            />
          </label>
          <button className="button" type="submit" disabled={isDepositSigning || depositReceipt.isLoading}>
            {isDepositSigning || depositReceipt.isLoading ? 'Processing...' : 'Deposit'}
          </button>
        </form>
        {depositStatusMessage && <p className="status">{depositStatusMessage}</p>}
      </section>

      <section className="card">
        <h2>Withdraw (admin only)</h2>
        <form className="form" onSubmit={handleWithdraw}>
          <label className="form__row">
            <span>Recipient</span>
            <input
              value={withdrawRecipient}
              onChange={(event) => setWithdrawRecipient(event.target.value)}
              placeholder="0x..."
              type="text"
            />
          </label>
          <label className="form__row">
            <span>Amount (ETH)</span>
            <input
              value={withdrawAmount}
              onChange={(event) => setWithdrawAmount(event.target.value)}
              placeholder="0.1"
              type="text"
            />
          </label>
          <button
            className="button"
            type="submit"
            disabled={!isAdmin || isWithdrawSigning || withdrawReceipt.isLoading}
            title={isAdmin ? '' : 'Only the admin wallet can run this call.'}
          >
            {isWithdrawSigning || withdrawReceipt.isLoading ? 'Processing...' : 'Withdraw'}
          </button>
        </form>
        {withdrawStatusMessage && <p className="status">{withdrawStatusMessage}</p>}
        {!isAdmin && isConnected && (
          <p className="hint">You are not the admin wallet. Withdraw will fail.</p>
        )}
      </section>
    </div>
  )
}

export default App
