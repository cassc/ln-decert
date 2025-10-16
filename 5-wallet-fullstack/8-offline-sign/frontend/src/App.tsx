import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import {
  useAccount,
  useBalance,
  useConnect,
  useDisconnect,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'
import type { Connector } from 'wagmi'
import { formatEther, parseEther } from 'viem'
import type { Address } from 'viem'
import { bankAbi } from './abi/bank'
import { bankAddress, isBankConfigured } from './config'
import './App.css'

function App() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, error: connectError, isPending: isConnecting } = useConnect()
  const { disconnect } = useDisconnect()
  const [connectingConnectorId, setConnectingConnectorId] = useState('')
  const [depositAmount, setDepositAmount] = useState('0.01')
  const [depositFormError, setDepositFormError] = useState('')
  const {
    writeContract: writeDepositContract,
    data: depositHash,
    error: depositError,
    isPending: isDepositSigning,
  } = useWriteContract()
  const depositReceipt = useWaitForTransactionReceipt({ hash: depositHash })

  const [withdrawFormError, setWithdrawFormError] = useState('')
  const {
    writeContract: writeWithdrawContract,
    data: withdrawHash,
    error: withdrawError,
    isPending: isWithdrawSigning,
  } = useWriteContract()
  const withdrawReceipt = useWaitForTransactionReceipt({ hash: withdrawHash })

  const contractAddress: Address | undefined = isBankConfigured ? (bankAddress as Address) : undefined

  useEffect(() => {
    if (!isConnecting) {
      setConnectingConnectorId('')
    }
  }, [isConnecting])

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
      writeDepositContract({
        abi: bankAbi,
        address: contractAddress,
        functionName: 'deposit',
        value,
      })
    } catch {
      setDepositFormError('Enter a valid number.')
    }
  }

  const handleConnect = (connector: Connector) => {
    if (isConnecting) {
      return
    }
    setConnectingConnectorId(connector.uid)
    connect({ connector })
  }

  const handleWithdraw = () => {
    setWithdrawFormError('')
    if (!isConnected || !address) {
      setWithdrawFormError('Connect wallet first.')
      return
    }
    if (!isBankConfigured || !contractAddress) {
      setWithdrawFormError('Set bank address in env file.')
      return
    }
    if (userBalance === 0n) {
      setWithdrawFormError('No deposit to withdraw.')
      return
    }
    writeWithdrawContract({
      abi: bankAbi,
      address: contractAddress,
      functionName: 'withdraw',
      args: [userBalance],
    })
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
        {isBankConfigured && (
          <p className="app__contract">
            Contract: <span>{contractAddress}</span>
          </p>
        )}
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
                const isActive = connectingConnectorId === connector.uid && isConnecting
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
                )
              })}
            </div>
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
        <h2>Withdraw</h2>
        <p className="hint">Withdraw sends your full deposit back to your wallet.</p>
        <button
          className="button"
          type="button"
          onClick={handleWithdraw}
          disabled={userBalance === 0n || isWithdrawSigning || withdrawReceipt.isLoading}
        >
          {isWithdrawSigning || withdrawReceipt.isLoading ? 'Processing...' : `Withdraw ${formattedUserBalance} ETH`}
        </button>
        {withdrawStatusMessage && <p className="status">{withdrawStatusMessage}</p>}
      </section>
    </div>
  )
}

export default App
