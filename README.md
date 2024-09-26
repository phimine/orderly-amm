### 合约概述（原需求清单见[篇尾](https://github.com/phimine/orderly-amm/blob/main/README.md#%E8%A6%81%E6%B1%82%E6%B8%85%E5%8D%95)）

一个可升级的AMM Defi协议，允许用户使用自动做市商(AMM)模型在ETH和多个ERC20代币之间进行交换。

### 功能拆解

#### 流动性池-交易对（支持以ETH与其他ERC20代币之间的交易对）

1. 提供流动性时获得LP token
2. 移除流动性时销毁LP token
3. 使用代币兑换其他代币（ERC20->ETH、 ETH->ERC20）

#### 交易对工厂

1. 创建交易对合约

#### 主路由合约

1. 用户质押ETH和ERC20提供流动性
2. 用户以LP Token为凭证移除流动性
3. 用户使用ETH兑换ERC20代币
4. 用户使用ERC20代币兑换ETH

### 状态变量

```
交易对合约 {
   // 交易对基础
   tokenA
   tokenB
   // 代币存量
   tokenA reserve
   tokenB reserve
   // 价格*时间
   tokenA priceCumulativeLast
   tokenB priceCumulativeLast
   // 工厂：只允许通过工厂创建和初始化
   factory
}
```

```
交易对工厂合约 {
    // 现存的交易对: tokenA => tokenB => pair
    getPair
}
```

```
主路由合约 {
    // 工厂：用于创建交易对
    factory
    // WETH：自动兑换ETH和WETH
    WETH
}
```

### 可升级设计

交易对合约和工厂合约作为存储合约，独立部署。
主路由合约作为与用户直接交互的业务逻辑合约，基于UUPS模式设计为可升级合约。

### 权限控制

交易对合约只允许由工厂统一创建管理
主路由合约分配两个管理角色（ADMIN_ROLE, UPGRADE_ROLE），只有角色的管理者可以指定其他管理者。

-   UPGRADE_ROLE: 合约升级角色，只有该角色可以执行升级操作
-   ADMIN_ROLE: 管理员角色，目前没有配置需要管理员操作

### 部署合约

#### 本地网络

```shell
yarn hardhat deploy --tags all --network hardhat
```

#### 测试网

```shell
yarn hardhat deploy --tags all --network sepolia
```

#### 主网

```shell
yarn hardhat deploy --tags all --network mainnet
```

### 单元测试

```shell
yarn hardhat test --network hardhat [--grep]
```

```
AMMRouter
    initialize
      ✔ should set factory and WETH address correctly
      ✔ should initial liquidity pool correctly if pair does not exist
      ✔ should revert with INSUFFICIENT_AMOUNT error if optimal token is less than min amount when provide for existing pair (50ms)
      ✔ should provide correct liquidity for existing pair
      ✔ should decrease liquidity correctly after removing
      ✔ should revert with INSUFFICIENT_AMOUNT error if output token is less than min amount (75ms)
    swapExactETHForTokens
      ✔ should revert with INSUFFICIENT_OUTPUT_AMOUNT error if output token is less than amountOutMin
      ✔ should swap to get token via exact ETH correctly
    swapETHForExactTokens
      ✔ should swap to get token via exact ETH correctly
    swapExactTokensForETH
      ✔ should swap to get ETH via exact ERC20 correctly
    swapTokensForExactETH
      ✔ should swap to get ETH via exact ERC20 correctly

  TokenPairFactory
    constructor
      ✔ should has no pair in initial factory
    createPair
      ✔ should revert with SAME_ADDRESSES error if token pair are the same one
      ✔ should revert with ZERO_ADDRESS error if one token of pair is zero address
      ✔ should create pair correctly
      ✔ should emit PairCreated
      ✔ should revert with PAIR_EXISTS error if pair exists

   17 passing (2s)
```

### 要求清单

##### 自动做市商

-   [x] 支持ETH与多个ETC20代币的兑换
-   [x] 支持用户提供流动性赚取奖励
-   [ ] 基于流动性池储量动态定价
-   [ ] 滑点控制机制

##### 权限控制

-   [x] 角色权限管理合约
-   [ ] 多签管理

##### 安全性

-   [x] 防范常见漏洞，如重入攻击、溢出/下溢、Dos攻击、访问控制等
-   [x] 紧急停止功能
-   [x] 结构化规范代码

##### 可升级性

-   [x] 合约可升级设计
-   [x] 提供升级脚本
-   [x] 永久存储模式将状态存储与业务逻辑隔离

##### Gas优化

-   [x] 优化代码，减少gas消耗
-   [x] 合理的使用事件

##### 测试

-   [x] 编写测试脚本全面覆盖所有功能
-   [ ] 静态分析工具扫描代码漏洞

##### 多环境部署

-   [x] 提供多环境部署脚本

##### 文档

-   [x] 必要的文档，包含架构概述及设计原理
