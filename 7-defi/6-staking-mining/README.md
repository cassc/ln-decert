# 质押池概览

本项目使用 Foundry 实现了一个 KK 代币质押池。用户质押 ETH，以固定的速率（每区块 10 KK）获取 KK 奖励，并可选择将本金通过外部借贷合约获取额外收益。

## 奖励结算机制

合约采用常见的"每代币奖励"模式。定义如下：

- \( R \) 为固定的奖励发放速率（每区块 10 KK）
- \( T \) 为自上次结算以来经过的区块数
- \( S \) 为当前的质押 ETH 总量
- \( RPT \) 为累积变量 `rewardPerTokenStored`

每次状态改变时，合约会计算新产生的奖励：

$$
\Delta \text{RPT} =
\begin{cases}
0, & \text{如果 } S = 0 \\
\dfrac{R \cdot T}{S}, & \text{其他情况}
\end{cases}
$$

全局累积变量更新为：

$$
\text{RPT}_{\text{new}} = \text{RPT}_{\text{old}} + \Delta \text{RPT}.
$$

每个用户保存一个累积变量快照（`userRewardPerTokenPaid`）。当用户余额发生变化（质押/取消质押）或领取奖励时，池子会结算其待领取的 KK：

$$
\text{earned}_u = \text{balance}_u \cdot (\text{RPT}_{\text{new}} - \text{RPT}_{\text{paid}, u}).
$$

### 实际奖励计算示例

假设用户在区块 $B_0$ 质押了 $b_u$ 个 ETH，在区块 $B_n$ 领取奖励。期间其他用户可能质押或取消质押，导致 $S$ 变化。用户的实际奖励为：

$$
\text{reward}_u = b_u \cdot \sum_{i=0}^{n-1} \frac{R \cdot (B_{i+1} - B_i)}{S_i}
$$

其中：
- $B_0, B_1, ..., B_n$ 是所有状态改变的区块号（$B_0$ 是用户质押时的区块号，$B_n$ 是领取时的区块号）
- $S_i$ 是区间 $[B_i, B_{i+1})$ 内的质押总量（即 $B_i$ 区块状态改变后的总质押量）
- $R$ 是每区块奖励（10 KK）

**关键特性**：
- 用户只能获得其质押期间产生的奖励（$B_0$ 之后）
- 在每个时间段内，奖励按质押占比分配：用户份额 = $\frac{b_u}{S_i}$
- 其他用户的质押/取消质押会改变 $S_i$，从而影响后续时段的奖励分配速率
- 但已产生的奖励（通过 RPT 快照机制）会被锁定，不受新质押者影响


## 质押生命周期

1. **质押**
   - 用户向 `stake()` 发送 ETH
   - 执行 `updateReward(msg.sender)`，更新累积变量并记入任何待领取的 KK
   - ETH 被添加到 `totalStaked` 和调用者的余额中
   - 如果配置了借贷提供者，ETH 会通过 `deposit` 转发到该借贷合约

2. **领取奖励**
   - `updateReward(msg.sender)` 将奖励累积到当前区块
   - 通过 `IToken.mint` 接口为调用者铸造待领取的 KK

3. **取消质押**
   - 刷新累积变量
   - 从用户和 `totalStaked` 中扣除本金
   - 如果合约 ETH 不足（因为资金在借贷合约中），会调用借贷提供者的 `withdraw` 来支付取款

4. **借贷集成（可选）**
   - 所有者通过 `setLendingProvider` 设置借贷合约
   - 新的质押会转发到借贷合约，取款时如有需要会从中提取流动性

## 类似模式的项目参考

- [Synthetix – StakingRewards](https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol)
  最早使用 `rewardPerTokenStored` / `userRewardPerTokenPaid` 的实现，奠定了质押奖励模式的范式
- [Uniswap – Liquidity Staker](https://github.com/Uniswap/liquidity-staker/blob/master/contracts/StakingRewards.sol)
  直接复用并改造 Synthetix 的逻辑用于 UNI 流动性挖矿
- [Aave – AaveDistributionManager](https://github.com/aave/aave-stake-v2/blob/master/contracts/stake/AaveDistributionManager.sol)
  使用 `index` 与 `users[user]` 存储同样的奖励累计指标，为 Safety Module 等资产分发奖励
- [Compound – Comptroller](https://github.com/compound-finance/compound-protocol/blob/master/contracts/Comptroller.sol)
  通过 `supplyIndex` / `borrowIndex`（缩放 1e36）向存款人/借款人分配 COMP，采用相同的累积奖励思路

## 可集成的借贷/再质押协议示例

- [Compound cETH (`CEther`)](https://github.com/compound-finance/compound-protocol/blob/master/contracts/CEther.sol)：直接接受原生 ETH，通过 `mint()` 生成 cETH，`redeem()` 赎回 ETH，流程最接近当前测试中的 Mock
- [Aave WrappedTokenGatewayV3](https://github.com/aave/aave-v3-periphery/blob/master/contracts/misc/WrappedTokenGatewayV3.sol)：提供 `depositETH` / `withdrawETH` 封装，自动完成 WETH 包装并与 LendingPool 交互，适合让 ETH 直接获取额外收益
- [Lido stETH](https://docs.lido.fi/contracts/lido/) / [Rocket Pool rETH](https://github.com/rocket-pool/rocketpool/blob/master/contracts/contract/token/RocketTokenRETH.sol)：流动性质押协议，质押 ETH 获得收益凭证，赎回时换回 ETH，虽然不是借贷但符合"托管本金换收益"模式
- [Yearn Vault（v2）](https://github.com/yearn/yearn-vaults/blob/develop/contracts/Vault.vy)：收益聚合金库，接受 (W)ETH 并返回 Vault 份额，赎回时按份额取回底层资产与收益
