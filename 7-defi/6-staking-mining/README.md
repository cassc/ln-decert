# 质押池概览

本项目使用 Foundry 实现了一个 KK 代币质押池。用户质押 ETH，以固定的速率（每区块 10 KK）获取 KK 奖励，并可选择将本金通过外部借贷适配器获取额外收益。

## 奖励结算机制

合约采用常见的"每代币奖励"模式。定义如下：

- \( R \) 为固定的奖励发放速率（每区块 10 KK）
- \( T \) 为自上次结算以来经过的区块数
- \( S \) 为当前的质押 ETH 总量
- \( \text{RPT} \) 为累积变量 `rewardPerTokenStored`

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
   - 如果配置了借贷提供者，ETH 会通过 `deposit` 转发到该适配器

2. **领取奖励**
   - `updateReward(msg.sender)` 将奖励累积到当前区块
   - 通过 `IToken.mint` 接口为调用者铸造待领取的 KK

3. **取消质押**
   - 刷新累积变量
   - 从用户和 `totalStaked` 中扣除本金
   - 如果合约 ETH 不足（因为资金在适配器中），会调用借贷提供者的 `withdraw` 来支付取款

4. **借贷集成（可选增益）**
   - 所有者通过 `setLendingProvider` 设置借贷适配器
   - 新进来的质押会转发到适配器，取款时需要时会从中提取流动性

