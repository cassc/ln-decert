import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import {
  useAccount,
  useBalance,
  useConnect,
  useDisconnect,
  useReadContract,
  useWalletClient,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'
import type { Connector } from 'wagmi'
import { erc20Abi, formatEther, maxUint256, parseEther } from 'viem'
import type { Address } from 'viem'
import { bankAbi } from './abi/bank'
import {
  bankAddress,
  chainId as targetChainId,
  chainName,
  isBankConfigured,
  isPermitDepositConfigured,
  wethAddress,
} from './config'
import './App.css'

const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as const

const toErrorMessage = (error: unknown): string => {
  if (error && typeof error === 'object') {
    const maybeShortMessage = (error as { shortMessage?: unknown }).shortMessage
    if (typeof maybeShortMessage === 'string' && maybeShortMessage.length > 0) {
      return maybeShortMessage
    }
    const maybeMessage = (error as { message?: unknown }).message
    if (typeof maybeMessage === 'string' && maybeMessage.length > 0) {
      return maybeMessage
    }
  }
  if (typeof error === 'string') {
    return error
  }
  return 'Something went wrong.'
}

const createPermitNonce = (): bigint => {
  const nowSeconds = BigInt(Math.floor(Date.now() / 1000))
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const randomByte = new Uint8Array(1)
    crypto.getRandomValues(randomByte)
    return (nowSeconds << 8n) | BigInt(randomByte[0])
  }
  const fallbackByte = BigInt(Math.floor(Math.random() * 256))
  return (nowSeconds << 8n) | fallbackByte
}

function App() {
  const { address, chainId: connectedChainId, isConnected } = useAccount()
  const { data: walletClient } = useWalletClient()
  const { connect, connectors, error: connectError, isPending: isConnecting } = useConnect()
  const { disconnect } = useDisconnect()
  const [connectingConnectorId, setConnectingConnectorId] = useState('')
  const [depositAmount, setDepositAmount] = useState('0.01')
  const [depositFormError, setDepositFormError] = useState('')
  const [allowanceFormMessage, setAllowanceFormMessage] = useState('')
  const [isPermitSignaturePending, setIsPermitSignaturePending] = useState(false)
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
  const {
    writeContract: writeApproveContract,
    data: approveHash,
    error: approveError,
    isPending: isApproveSigning,
  } = useWriteContract()
  const withdrawReceipt = useWaitForTransactionReceipt({ hash: withdrawHash })
  const approveReceipt = useWaitForTransactionReceipt({ hash: approveHash })

  const contractAddress: Address | undefined = isBankConfigured ? (bankAddress as Address) : undefined
  const wethTokenAddress: Address | undefined = isPermitDepositConfigured
    ? (wethAddress as Address)
    : undefined

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

  const handleApprove = () => {
    setAllowanceFormMessage('')
    if (!isConnected || !address) {
      setAllowanceFormMessage('Connect wallet first.')
      return
    }
    if (!isPermitDepositConfigured || !wethTokenAddress) {
      setAllowanceFormMessage('Set VITE_BANK_ADDRESS and VITE_WETH_ADDRESS before approving.')
      return
    }
    if (connectedChainId && connectedChainId !== targetChainId) {
      setAllowanceFormMessage(`Switch wallet to ${chainName}.`)
      return
    }
    try {
      writeApproveContract({
        abi: erc20Abi,
        address: wethTokenAddress,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS as Address, maxUint256],
      })
    } catch (error) {
      setAllowanceFormMessage(toErrorMessage(error))
    }
  }

  const handleDeposit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setDepositFormError('')
    if (!isConnected || !address) {
      setDepositFormError('Connect wallet first.')
      return
    }
    if (!isPermitDepositConfigured || !contractAddress || !wethTokenAddress) {
      setDepositFormError('Set VITE_BANK_ADDRESS and VITE_WETH_ADDRESS before using the dApp.')
      return
    }
    const currentChainId = walletClient?.chain?.id ?? connectedChainId
    if (currentChainId && currentChainId !== targetChainId) {
      setDepositFormError(`Switch wallet to ${chainName}.`)
      return
    }
    if (!walletClient) {
      setDepositFormError('Wallet client not ready.')
      return
    }

    let value: bigint
    try {
      value = parseEther(depositAmount)
    } catch {
      setDepositFormError('Enter a valid number.')
      return
    }

    if (value <= 0n) {
      setDepositFormError('Enter amount bigger than zero.')
      return
    }

    const nonce = createPermitNonce()
    const deadlineSeconds = BigInt(Math.floor(Date.now() / 1000) + 15 * 60)
    const permit = {
      permitted: {
        token: wethTokenAddress,
        amount: value,
      },
      nonce,
      deadline: deadlineSeconds,
    }
    const transferDetails = {
      to: contractAddress,
      requestedAmount: value,
    }

    let signature: `0x${string}` | undefined
    try {
      setIsPermitSignaturePending(true)
      signature = await walletClient.signTypedData({
        account: address,
        primaryType: 'PermitTransferFrom',
        domain: {
          name: 'Permit2',
          chainId: targetChainId,
          verifyingContract: PERMIT2_ADDRESS,
        },
        types: {
          TokenPermissions: [
            { name: 'token', type: 'address' },
            { name: 'amount', type: 'uint256' },
          ],
          PermitTransferFrom: [
            { name: 'permitted', type: 'TokenPermissions' },
            { name: 'spender', type: 'address' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        message: {
          permitted: {
            token: wethTokenAddress,
            amount: value,
          },
          spender: contractAddress,
          nonce,
          deadline: deadlineSeconds,
        },
      })
    } catch (error) {
      setDepositFormError(toErrorMessage(error))
      return
    } finally {
      setIsPermitSignaturePending(false)
    }

    if (!signature) {
      return
    }

    try {
      writeDepositContract({
        abi: bankAbi,
        address: contractAddress,
        functionName: 'depositWithPermit2',
        args: [permit, transferDetails, address, signature],
      })
    } catch (error) {
      setDepositFormError(toErrorMessage(error))
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
    if (isPermitSignaturePending) {
      return 'Sign the Permit2 message in your wallet...'
    }
    if (isDepositSigning) {
      return 'Confirm the deposit transaction in your wallet...'
    }
    if (depositReceipt.isLoading) {
      return 'Waiting for confirmation...'
    }
    if (depositReceipt.isSuccess) {
      return 'Deposit confirmed.'
    }
    if (depositError) {
      return toErrorMessage(depositError)
    }
    return ''
  }, [
    depositError,
    depositFormError,
    depositReceipt.isLoading,
    depositReceipt.isSuccess,
    isDepositSigning,
    isPermitSignaturePending,
  ])

  const allowanceStatusMessage = useMemo(() => {
    if (allowanceFormMessage) {
      return allowanceFormMessage
    }
    if (isApproveSigning) {
      return 'Confirm the approval in your wallet...'
    }
    if (approveReceipt.isLoading) {
      return 'Waiting for approval confirmation...'
    }
    if (approveReceipt.isSuccess) {
      return 'Permit2 allowance updated.'
    }
    if (approveError) {
      return toErrorMessage(approveError)
    }
    return ''
  }, [
    allowanceFormMessage,
    approveError,
    approveReceipt.isLoading,
    approveReceipt.isSuccess,
    isApproveSigning,
  ])

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
      {isBankConfigured && !isPermitDepositConfigured && (
        <div className="status status--warning">Set VITE_WETH_ADDRESS to enable Permit2 deposits.</div>
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
        <p className="hint">
          Deposit pulls your WETH into the Bank through Permit2 and unwraps it to ETH.
        </p>
        <div className="form">
          <button
            className="button button--outline"
            type="button"
            onClick={handleApprove}
            disabled={
              !isPermitDepositConfigured || isApproveSigning || approveReceipt.isLoading || !isConnected
            }
          >
            {isApproveSigning || approveReceipt.isLoading ? 'Processing...' : 'Approve Permit2 on WETH'}
          </button>
        </div>
        {allowanceStatusMessage && <p className="status">{allowanceStatusMessage}</p>}
        <form className="form" onSubmit={handleDeposit}>
          <label className="form__row">
            <span>Amount (WETH)</span>
            <input
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder="0.1"
              type="text"
            />
          </label>
          <button
            className="button"
            type="submit"
            disabled={
              !isPermitDepositConfigured ||
              isPermitSignaturePending ||
              isDepositSigning ||
              depositReceipt.isLoading ||
              !isConnected
            }
          >
            {isPermitSignaturePending || isDepositSigning || depositReceipt.isLoading
              ? 'Processing...'
              : 'Deposit with Permit2'}
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
