# 期权代币实验室

[中文](README.zh-CN.md) | [English](README.md)

本项目展示如何使用 Foundry 构建一个简单的欧式看涨期权代币。目标是学习如何通过锁定 ETH 来铸造期权代币，让用户在到期日行权，并在行权窗口关闭后清理头寸。

## 核心思想
- 执行价格和到期日在部署合约时固定。
- 项目所有者（卖方）锁定 ETH 抵押品，每个 ETH 铸造一个期权代币。
- 买家在本合约之外向卖家支付期权权利金（例如通过单独的市场合约），然后卖家向其铸造代币。
- 期权持有者在行权窗口期间支付执行资产（测试中使用模拟稳定币）以接收 ETH。
- 窗口期结束后，卖方可以收回剩余的 ETH，标记市场为已过期，并销毁剩余代币。

## 角色
- **项目所有者**：存入 ETH 以铸造代币，提取执行收益，并在到期后关闭市场。
- **用户**：持有期权代币，在行权窗口期间支付执行资产，并接收 ETH。
- **流动性引导（可选）**：所有者可以以较低的权利金为 `ocETH/USDT` 或 `ocETH/USDC` 池提供种子流动性，使用户可以提前低价购买期权。

## 合约功能
- 欧式风格：仅允许在 `expiry` 和 `expiry + exerciseWindow` 之间行权。
- 全额抵押：每个代币代表锁定在合约中的 1 wei ETH。
- 执行结算：执行金额使用 18 位小数数学运算，因此您可以接入 Chainlink 喂价或自定义报价。
- 到期后清理：结算后转账停止，所有者可以逐个持有者销毁剩余代币。
- 流动性引导：所有者可以通过 `seedLiquidity` 将新铸造的期权和执行代币移至池中。
- 铸造、行权、执行提现、流动性种子和抵押品收回的事件日志使回测和索引变得容易。



### 需要选择的参数
- **执行价格**：在部署时设置一次。在生产环境中，您可以像 Lyra 那样从 Chainlink 读取 ETH/USD。
- **行权窗口**：保持较短（例如 24 小时）以减少闲置抵押品。
- **执行资产**：任何 ERC20 稳定币（USDC/USDT/DAI）。测试使用名为 `mUSD` 的模拟代币。

### 行权数学
- 铸造的代币 = 存入的 ETH（1 ether → 1e18 代币）。
- 应付执行金额 = `amount * strikePrice / 1e18`。
- 如果用户行使其一半余额，合约会为其他持有者保留剩余的抵押品。



## 进阶学习的延伸想法
- 接入 Chainlink ETH/USD 喂价以自动设置执行价格或在预言机数据过时时阻止行权。
- 编写权利金计算器并为 Uniswap V3 池提供种子，类似于 Panoptic。
- 添加对 ERC20 抵押品（WETH）的支持，而不是原始 ETH，以便与金库系统兼容。
- 跟踪每个账户的已行权金额，以支持部分现金结算分析。

## 类似的 DeFi 期权协议
- **Opyn** – 以太坊上的先驱；使用 oTokens 和全额抵押金库（[合约](https://github.com/opynfinance/GammaProtocol/tree/master/contracts)）。
- **Hegic** – 自动化池，出售具有固定到期日的 ETH/WBTC 看涨和看跌期权（[合约](https://github.com/hegic/contracts/tree/main/packages/v8888/contracts)）。
- **Dopex** – Arbitrum 金库（SSOV），卖家锁定抵押品，买家选择执行价格和到期组合（[合约](https://github.com/code-423n4/2023-08-dopex/tree/main/contracts)）。
- **Lyra** – Optimism/Arbitrum AMM，具有 delta 对冲做市商和 Chainlink 定价（[合约](https://github.com/derivexyz/v1-core/tree/master/contracts)）。
- **Premia** – 多链、点对池期权，具有灵活的执行价格和到期日（[合约](https://github.com/Premian-Labs/v3-contracts/tree/master/contracts)）。
- **Ribbon / Aevo** – 出售备兑看涨期权的金库策略和期权订单簿交易所（[合约](https://github.com/ribbon-finance/ribbon-v2/tree/master/contracts)）。
- **PsyOptions** – Solana SPL 期权，提供美式和欧式风格（[合约](https://github.com/mithraiclabs/psyoptions/tree/master/programs/psy_american)）。
- **Zeta Markets** – Solana 交易所，为期权和永续合约提供统一保证金（[合约](https://github.com/zetamarkets/serum-dex/tree/master/dex/src)）。
- **Synquote** – 定制链上期权报价的 RFQ 市场（[合约 – 组织页面](https://github.com/synquote)）。
- **Thales** – Synthetix 生态系统的二元和普通期权，以 sUSD 结算（[合约](https://github.com/thales-markets/contracts/tree/main/contracts)）。
- **Panoptic** – 在 Uniswap V3 流动性之上构建永续期权（[合约](https://github.com/panoptic-labs/panoptic-v1-core/tree/v1.0.x/contracts)）。
- **Friktion（旧版）** – Solana 备兑看涨期权和现金担保看跌期权的自动化策略（[合约 – 旧版工具](https://github.com/Friktion-Labs/captain)）。
