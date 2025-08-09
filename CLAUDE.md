# CLAUDE.md

这个文件为Claude Code (claude.ai/code)在此代码库中工作提供指导。

## 项目概述

这是PancakeSwap Infinity协议的开发工具包，包含两个主要模块：
- **infinity-core**: 核心合约，包含Vault、PoolManager、协议费用控制等基础设施
- **infinity-periphery**: 外围合约，包含Position Manager、Router、Quoter等用户交互接口

## 常用命令

### 构建和测试
```bash
# 在infinity-core目录
cd infinity-core
yarn install          # 安装Node.js依赖
forge install         # 安装Solidity依赖
forge build           # 编译合约
forge test --isolate  # 运行测试（必须使用--isolate标志）
forge fmt             # 格式化代码

# 在infinity-periphery目录
cd infinity-periphery
forge install         # 安装依赖
forge build           # 编译
forge test --isolate  # 运行测试

# 开发模式（监听文件变化）
yarn dev              # 等同于 forge test --isolate -vvv -w --show-progress

# 生成快照
forge snapshot        # 生成Gas使用快照
```

### 部署相关
```bash
# 设置环境变量
export SCRIPT_CONFIG=ethereum-sepolia  # 或其他网络配置
export RPC_URL=https://...
export PRIVATE_KEY=0x...
export ETHERSCAN_API_KEY=xx  # 可选，用于验证合约

# 部署示例
forge script script/01_DeployVault.s.sol:DeployVaultScript -vvv \
    --rpc-url $RPC_URL \
    --broadcast \
    --slow

# 合约验证（因为使用create3部署，需要单独验证）
forge verify-contract <address> Vault --watch --chain <chain_id>
```

## 代码架构

### infinity-core 核心架构
- **Vault.sol**: 资产管理金库，处理代币存取和结算
- **pool-cl/**: Concentrated Liquidity池相关合约
  - `CLPoolManager.sol`: CL池管理器，处理池的创建和操作
  - `libraries/`: 核心数学库（SqrtPriceMath、LiquidityMath等）
- **pool-bin/**: Bin池相关合约
- **interfaces/**: 所有接口定义
- **libraries/**: 共享工具库
- **ProtocolFeeController.sol**: 协议费用控制

### infinity-periphery 外围架构
- **pool-cl/CLPositionManager.sol**: CL位置管理器，用户交互的主要入口
- **pool-cl/CLQuoter.sol**: 报价器，提供swap报价
- **MixedQuoter.sol**: 混合报价器，支持多种池类型
- **base/**: 基础路由器和权限管理
- **libraries/**: 工具库（CalldataDecoder、Actions等）

### 测试架构
- 使用Foundry进行测试，必须使用`--isolate`标志
- 测试文件镜像src目录结构
- helpers/目录包含测试辅助工具
- 支持fuzzing和invariant测试

## 开发规范

### Solidity版本和优化
- 使用Solidity 0.8.26
- core合约优化运行次数: 25,666
- periphery合约优化运行次数: 1,000,000
- CLPositionManager特殊优化: 9,000次
- 启用via_ir优化

### 测试要求
- 所有测试必须使用`--isolate`标志运行
- 本地fuzzing运行5次，CI中运行10,000次
- 使用snapshot测试Gas消耗

### 部署流程
1. 合约通过create3 factory部署到预确定地址
2. 部署配置文件在`script/config/`目录
3. 每个脚本都有对应的验证命令
4. 支持多网络部署（Ethereum、BSC、Base等）

## 重要注意事项

- 项目使用git submodules管理依赖 
- 合约地址通过create3确定性部署
- 测试隔离是必需的，以避免状态干扰
- 使用Cancun EVM版本特性
- Always use English wirte comment and doc