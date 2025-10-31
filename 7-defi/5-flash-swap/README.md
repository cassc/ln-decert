## 闪电贷套利练习项目

本项目基于 Foundry 框架，演示如何创建两个价格不同的 Uniswap V2 流动性池，并通过闪电交换进行套利。

### 项目结构
```
.
├── src/
│   ├── MyToken.sol                      # 可铸造的 ERC20 代币，用于向流动性池注资
│   ├── FlashSwapArb.sol                 # 闪电交换合约，实现借款、交易、归还的完整套利流程
│   ├── interfaces/                      # Solidity 0.8 版本的 Uniswap V2 合约 ABI 接口
│   ├── mocks/
│   │   └── MockUniswapV2Factory.sol     # 本地测试用的 Uniswap V2 工厂和交易对模拟合约
│   └── external/
│       └── UniswapV2Artifacts.sol       # 导入真实的 Uniswap V2 合约字节码（Solidity 0.5.16）
├── test/
│   └── FlashSwap.t.sol                  # 演示价格差异套利的测试用例
└── script/
    ├── Deploy.s.sol                     # 部署脚本：代币、工厂、流动性池、套利合约
    └── RunArbitrage.s.sol               # 套利执行脚本：调用已部署合约进行套利交易
```

### 安装依赖
```shell
forge install --no-git
```

### 构建项目
```shell
forge build
```

### 运行测试
```shell
forge test
```

### 部署脚本
使用 Foundry CLI 参数配置钱包（如 `--sender`、`--ledger`、`--mnemonic` 或 `--private-key`），然后执行：
```shell
forge script script/Deploy.s.sol:DeployTokensAndPools \
  --sig "run(address)" <部署者钱包地址> \
  --rpc-url <rpc_url> \
  --account <local_foundry_account_name> \
  --broadcast
```
该脚本通过 `vm.getCode("UniswapV2Factory.sol:UniswapV2Factory")` 部署两个 Uniswap V2 工厂合约，并以不同价格比率向池子注入流动性。

### 链上套利操作
默认配置下，策略目标是赚取更多的代币 B。具体流程：从 1:1 池子借入代币 A → 在 1:2 池子卖出 → 用代币 B 还款 → 保留多余的代币 B 作为利润。

> 若要最大化代币 A 收益, 即赚取代币 A，调换操作方向即可：
> - 从代币 B 较便宜的池子（即 B 充裕的 `PairB`）借入代币 B
> - 用另一个池子（`PairA`）将借来的代币 B 兑换成代币 A
> - 用代币 A 偿还闪电贷，留下多余的代币 A
相应调整参数，将 `token_borrow_address` 设为代币 B，并修改交易对顺序。

使用辅助脚本调用 `FlashSwapArb.startArbitrage`，填入部署后的合约地址：
```shell
forge script script/RunArbitrage.s.sol:RunArbitrage \
  --sig "run(address,address,address,address,address,uint256,address)" \
  <调用者钱包地址> \
  <闪电套利合约地址> \
  <借款池地址> \
  <交易池地址> \
  <借款代币地址> \
  <借款数量_wei> \
  <利润接收地址> \
  --rpc-url <rpc_url> \
  --broadcast
```
参数说明：
- `caller_wallet_address`：`FlashSwapArb` 合约的所有者地址（与 `Deploy.s.sol` 的部署者一致）
- `flash_arb_address`：部署脚本输出的 `FlashSwapArb` 合约地址
- `pair_borrow_address`：借款的流动性池地址。例如：部署后 `PairA` 比率为 1 A : 1 B，可从这里借款
- `pair_swap_address`：交易的流动性池地址。例如：`PairB` 比率为 1 A : 2 B，在这里交易获利
- `token_borrow_address`：借入的代币地址（如 `TokenA (MTA)` 地址）
- `borrow_amount_wei`：借款数量，单位为 wei（可用 `ether` 辅助单位，如 `100 ether` 等于 `100000...`）
- `profit_recipient_address`：利润接收钱包，通常与 `caller_wallet_address` 相同

提示：可直接从部署脚本日志或 `broadcast/Deploy.s.sol/` 目录下的广播 JSON 文件中复制地址。

### 套利原理

#### 基本流程
- 池子 A 初始价格：1 代币 A : 1 代币 B
- 池子 B 初始价格：1 代币 A : 2 代币 B
- 借入在池子 B 中价值更高的代币，在那里完成交易，归还借款后，差价就是利润
- 闪电交换机制确保借款和还款在同一笔交易内完成，无需预付本金

#### 最优交换量计算（以最大化代币 B 收益为例）

假设我们要从池子 A 借入代币 A，在池子 B 交易获得代币 B，然后用代币 B 还款。

**池子状态：**
- 池子 A：储备量 $(R_A^A, R_A^B)$
- 池子 B：储备量 $(R_B^A, R_B^B)$

**交易流程：**
1. 从池子 A 闪电借出 $x$ 数量的代币 A
2. 在池子 B 将 $x$ 代币 A 换成代币 B，根据 Uniswap V2 的 `getAmountOut` 公式（扣除 0.3% 手续费）：

$$
y = R_B^B - \frac{R_B^A \times R_B^B}{R_B^A + 0.997x}
$$

   其中 $y$ 是获得的代币 B 数量。

3. 归还池子 A 的闪电贷。根据 Uniswap V2 的 `getAmountIn` 公式，为了换出 $x$ 数量的代币 A，需要支付的代币 B 数量为：

$$
\text{还款金额} = \left\lceil \frac{R_A^B \times x \times 1000}{(R_A^A - x) \times 997} \right\rceil
$$

   注意：此公式考虑了池子 A 在借出 $x$ 代币 A 后的储备量变化，即 $R_A^A$ 减少了 $x$。

**利润公式：**

$$
\text{利润} = y - \left\lceil \frac{R_A^B \times x \times 1000}{(R_A^A - x) \times 997} \right\rceil
$$

**最优借款量：**

对上述利润函数求导并令其为零，可以求得最优借款量。由于公式较为复杂（涉及两个池子的储备量变化），实际应用中通常采用数值优化方法。

作为近似估算，当两个池子流动性相近且价差不大时，可使用简化公式：

$$
x^* \approx \sqrt{R_B^A \times R_B^B} - R_B^A
$$

但请注意，这是一个粗略估算。准确的最优值需要代入具体的池子储备量，并考虑：
- 池子 A 借出后储备量的变化：$(R_A^A - x, R_A^B)$
- 池子 B 交易后储备量的变化：$(R_B^A + 0.997x, R_B^B - y)$
- 两次交易的 0.3% 手续费

**参考代码：**

可参考 `src/FlashSwapArb.sol` 中第 121 行使用的 `UniswapV2Math.getAmountIn()` 函数：

```solidity
amountToRepay = UniswapV2Math.getAmountIn(amountBorrowed, reserveBorrow1, reserveBorrow0);
```


### 重要说明
⚠️ **关于真实环境中的套利机会：**

本项目为了演示目的，部署了**两个独立的 Uniswap V2 工厂合约**，从而为同一代币对创建两个价格不同的流动性池。然而在实际的区块链网络中，Uniswap V2 每个网络只维护**一个全局工厂合约**，该工厂对每个代币对只允许创建**一个流动性池**。

这意味着：
- 在真实的 Uniswap V2 环境中，同一代币对不可能同时存在两个不同价格的池子
- 真实的套利机会来自于**不同交易平台之间的价差**（如 Uniswap vs Sushiswap、Curve、中心化交易所等）, 尤其是由大额交易导致的**临时价格失衡**


因此本项目主要用于学习闪电交换的技术原理，实际应用时需要在不同 DEX 协议之间寻找套利空间。

### Foundry 文档
<https://book.getfoundry.sh/>
