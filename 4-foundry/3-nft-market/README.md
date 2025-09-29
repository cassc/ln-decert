# NFT 市场合约示例

本项目基于 Foundry，包含一个使用自定义 ERC20 代币进行结算的 NFT 市场合约，并附带完整的单元测试与模糊测试。

## 功能概览
- `NFTMarket` 支持卖家以任意价格上架任意 ERC721 资产。
- 买家可以通过普通 `transferFrom` 或自带回调的 `transferWithCallback` 使用 `DecentMarketToken` 购买 NFT。
- 市场阻止卖家自购，并确保交易完成后合约中没有多余代币残留。

## 主要合约
- `src/DecentMarketNFT.sol`：用于演示的 ERC721 NFT。
- `src/DecentMarketToken.sol`：带回调能力的 ERC20 代币。
- `src/NFTMarket.sol`：NFT 市场核心逻辑，包含上架、购买、取消等功能。

## 开发环境准备
1. 安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)。
2. 进入项目目录后执行 `forge install` 安装依赖（若仓库未自带 `lib` 目录）。

## 常用命令
```bash
# 编译合约
forge build

# 运行测试（含模糊测试）
forge test

# 查看 gas 报告
forge test --gas-report
```

## 测试说明
`test/NFTMarket.t.sol` 覆盖以下场景：
- 上架成功与失败（零价、非持有人、重复上架），并断言 `Listed` 事件。
- 购买成功、卖家自购、重复购买、支付金额异常（过多/过少）等情况，并断言 `Purchase` 事件与错误信息。
- `transferWithCallback` 回调流程的成功与失败路径。
- 模糊测试：随机价格（0.01-10000 Token）与随机买家地址完成上架与购买，确保市场不会持有多余代币。

## 后续扩展建议
- 添加不可变性测试，验证市场在任意交易序列后仍不持有 `DecentMarketToken`。
- 接入更完整的前端或脚本以演示链上交互流程。
