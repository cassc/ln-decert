# 通缩 Rebase Token 示例

该项目演示一个基于 Foundry 的通缩型 ERC20 代币。合约通过 rebase 方式，在每次触发后把总量和账户余额整体缩减 1%，帮助理解弹性供给代币的实现思路。

## 核心规则

- 初始发行量为 1 亿枚（18 位小数），部署时全部发送给指定的初始地址。
- 只有合约拥有者可以调用 `rebase()`，且两次调用至少间隔一年（一年按 `365 days` 计算）。
- 每次 `rebase()` 会把总供给乘以 `0.99`，所有地址的 `balanceOf` 会同步按比例缩小。

## 项目结构

- `src/RebaseToken.sol`：代币主合约。
- `test/RebaseToken.t.sol`：Foundry 单元测试，覆盖转账、授权和多次通缩。
- `script/RebaseToken.s.sol`：部署脚本，需要提供 `INITIAL_RECIPIENT` 环境变量。

## 使用指引

构建合约：

```bash
forge build
```

运行测试：

```bash
forge test
```

执行部署脚本示例（使用 Foundry 账户别名）：

```bash
forge script script/RebaseToken.s.sol:RebaseTokenScript \
  --rpc-url <rpc_url> \
  --account <foundry_account_name> \
  --broadcast
```

提前设置：

```bash
export INITIAL_RECIPIENT=<初始接收地址>
```

`foundry_account_name` 可以通过 `cast wallet import` 等命令写入 Foundry 钱包。

### Precision loss possible mitigation strategies

- Ampleforth/Nomad ‑ keep gons like we do, but store a running “remainders” pool. Each rebase tracks leftover gons and drips them back to the owner or treasury so supply stays exact.
- OlympusDAO/TIME forks ‑ quote balances in “gons” internally, but when a wallet spends its full balance they transfer every remaining gon to avoid dust. They accept the tiny supply drift that remains.
- Maker’s DSR shares / Compound cTokens ‑ scale by a high‑precision index (ray = 1e27) instead of rebase, then convert with decimals when needed. This avoids truncation at the cost of a different ERC20 feel.
- StETH / rETH style wrappers ‑ no positive/negative rebase; they use an exchange rate (shares vs assets). Wallets read human numbers via off-chain helpers. This dodges the rounding issue entirely but breaks
  strict ERC20 semantics.
