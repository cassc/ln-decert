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

### 除法精度损失策略

- Ampleforth/Nomad ‑ 同样采用内部份额机制，但额外维护一个动态"余数池"。每次 rebase 时跟踪剩余的内部份额并将其回流至所有者或金库，以确保供应量精确无误。
- OlympusDAO/TIME 分叉 ‑ 内部以固定份额计价余额，当钱包花费全部余额时转移所有剩余份额以避免产生dust余额。可接受极微小的供应量偏差。
- Maker 的 DSR 份额 / Compound cTokens ‑ 采用高精度索引（ray = 1e27）进行缩放而非 rebase，需要时再转换为小数。这避免了截断问题，但与 ERC20 有更大的使用差异。
- StETH / rETH 样式包装器 ‑ 不使用正负 rebase 机制，而是采用汇率（份额与资产的兑换比率）。钱包通过链下辅助工具读取可读数值。这种方式完全规避了舍入问题，但偏离了严格的 ERC20 标准。
