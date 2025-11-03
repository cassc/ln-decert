## 项目概述

本仓库实现一个基于虚拟自动做市商（vAMM）的杠杆去中心化交易所 `SimpleLeverageDEX`。用户可以使用模拟的 USDC 作为保证金，开启多头或空头杠杆仓位，支持主动平仓以及清算逻辑。

核心能力：
- `openPosition(uint256 margin, uint256 level, bool long)`：按指定杠杆倍数开启多空仓位。
- `closePosition()`：结算仓位盈亏并返还剩余保证金。
- `liquidatePosition(address user)`：当亏损超过 80% 保证金时，可由第三方清算并获得结余。
- `calculatePnL(address user)`：根据 vAMM 曲线计算当前仓位盈亏。

## 目录结构

```
.
├── foundry.toml           # Foundry 项目配置
├── README.md              # 项目说明文档
├── script/                # 部署脚本目录
├── src/                   # 合约源码目录
│   ├── SimpleLeverageDEX.sol    # 主合约，维护 vAMM 虚拟资产池、仓位信息以及交易逻辑
│   └── mocks/
│       └── MockUSDC.sol         # 测试用的可铸造 USDC 模拟代币
└── test/                  # 测试目录
    └── SimpleLeverageDEX.t.sol  # Foundry 测试，覆盖多空开平仓、盈利、清算等场景
```

## 环境要求

安装 [Foundry](https://book.getfoundry.sh/getting-started/installation) 工具链。

## 使用说明

### 安装依赖

```bash
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
forge test
```


## 关于本 DEMO 版本说明

### calculatePnL 取整说明

盈亏计算（PnL）、交易和结算均使用相同的向上取整规则。
每笔交易最多可能在池中留下 1 wei 的 USDC 余额。
这些微量余额在小型资金池中会略微影响价格，但无法被套利获利。

### 标记价格说明

当前演示使用 vAMM 储备比例作为标记价格。
真实协议通常会结合外部预言机或时间加权均价，以防止单笔大额交易伪造价格信号。


## 测试说明

测试通过 `MockUSDC` 铸造代币给用户，使用 `SimpleLeverageDEX` 合约模拟多空仓位变化。关键断言包括：
- 开仓后余额扣减、平仓后恢复。
- 市场价格变化导致的多头盈利。
- 条件满足时第三方可执行清算并获得奖励。

通过阅读测试脚本可以快速理解合约交互流程。根据实际需求，可以进一步扩展手续费、资金费率等机制。

## 参考项目

以下是与 vAMM 永续合约及相关 DeFi 协议的优秀参考项目：

### vAMM 与永续合约协议

#### 1. Perpetual Protocol
- **仓库**: [perpetual-protocol/perp-curie-contract](https://github.com/perpetual-protocol/perp-curie-contract)
- **描述**: Perpetual Protocol v2 (Curie) 的核心智能合约，基于 Uniswap v3 的永续合约协议
- **语言**: Solidity
- **适合学习**: 生产级 vAMM 实现、资金费率、清算机制、风险管理

#### 2. dYdX v3 Perpetual (已归档，但仍可学习)
- **仓库**: [dydxprotocol/perpetual](https://github.com/dydxprotocol/perpetual)
- **描述**: dYdX 的永续合约协议（基于订单簿，非 vAMM）
- **语言**: Solidity, TypeScript
- **状态**: 已于 2022年9月 归档为只读，代码仍可学习
- **适合学习**: 保证金系统、清算机制、风险参数设计
- **注意**: dYdX v4 已迁移至基于 Cosmos SDK 的独立链

#### 3. Drift Protocol 
- **仓库**: [drift-labs/protocol-v2](https://github.com/drift-labs/protocol-v2)
- **描述**: Solana 上基于 vAMM 的永续合约协议
- **语言**: Rust (Anchor), TypeScript
- **适合学习**: 现代 vAMM 设计模式、多种流动性机制

#### 4. GMX 
- **仓库**: [gmx-io/gmx-contracts](https://github.com/gmx-io/gmx-contracts)
- **描述**: 去中心化永续合约交易所，基于池化模型（非 vAMM）
- **语言**: Solidity
- **适合学习**: 替代性的永续合约设计、GLP 池模型

### AMM 核心实现

#### 5. Uniswap v2 
- **仓库**: [Uniswap/v2-core](https://github.com/Uniswap/v2-core)
- **描述**: 经典的恒定乘积 AMM (x * y = k)
- **语言**: Solidity
- **适合学习**: 恒定乘积公式、精度处理、向上取整策略

#### 6. Uniswap v3 
- **仓库**: [Uniswap/v3-core](https://github.com/Uniswap/v3-core)
- **描述**: 集中流动性 AMM
- **语言**: Solidity
- **适合学习**: 高级 AMM 数学、基于 tick 的定价、流动性管理

#### 7. Curve Finance 
- **仓库**: [curvefi/curve-contract](https://github.com/curvefi/curve-contract)
- **描述**: 稳定币交换的 StableSwap AMM，低滑点设计
- **语言**: Vyper, Solidity
- **适合学习**: 稳定资产的替代性 AMM 曲线

### 借贷与清算协议

#### 8. Aave v3 
- **仓库**: [aave-dao/aave-v3-origin](https://github.com/aave-dao/aave-v3-origin)
- **描述**: Aave 协议 v3.5 版本（Foundry 项目）
- **语言**: Solidity
- **适合学习**: 抵押品管理、健康因子计算、清算逻辑、利率模型
- **注意**: 这是最新的 v3-origin 仓库，旧的 aave-v3-core 已废弃


### 学习建议

**学习 vAMM 机制**
- 建议优先参考 Drift Protocol
- 其次可参考 Perpetual Protocol Curie

**学习清算逻辑**
- 参考 Aave v3 的健康因子、清算阈值
- 参考 dYdX v3 的保证金要求和维持保证金（虽已归档但代码质量高）

**学习 AMM 数学**
- 基础必学：Uniswap v2 的恒定乘积、精度处理和向上取整
- 进阶：Uniswap v3 的集中流动性和 tick 系统
- 稳定币交易：Curve 的 StableSwap 曲线

**学习安全实践**
- 基础必学：OpenZeppelin 的重入保护、安全数学模式、访问控制
- 进阶提升：阅读 Trail of Bits、Certora 等机构的审计报告
