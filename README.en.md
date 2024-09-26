### Project Overview (refer to [ending](https://github.com/phimine/orderly-amm/blob/main/README.en.md#requirement-points) for original requirements list)

An upgradeable AMM Defi contract, allows users to swap between ETH and multiple ERC20 tokens using an Automated Market Maker (AMM) model.

### Architectural Overview

See below graph
![architectural graph](/static/img/arch.png "architectural graph")

### Functions Split

#### TokenPair.sol (only support swaping between ETH and ERC20)

1. mint LP token when provide liquidity
2. burn LP token when remove liquidity
3. swap ETH/ERC20（ERC20->ETH、 ETH->ERC20）

#### Factory.sol

1. create pair

#### Router.sol

1. allow user to deposit ETH and ERC20 to provide liquidity - add liquidity
2. allow user to withdraw ETH and ERC20 using LP tokens - remove liquidity
3. allow user to swap ETH using ERC20
4. allow user to swap ERC20 using ETH

### Calculation Formula

#### Liquidity Calculation

-   **Initial Liquidity** `liquidity = (x * y) - min_liquidity`<br>
    _--min_liquidity: locked minimum liquidity;_
-   **Delta Liquidity** `liquidity = min(dx * ts / tx, dy * ts / ty)`<br>
    _--dx/dy: delta amount of token0 and token1;<br>_
    _--tx/ty: reserve of token0 and token1;<br>_
    _--ts: total liquidity;<br>_

#### Swaping Calculation

-   **How many tokenY swap out if pay exact tokenX**

```
(x + dx * 0.997) * (y - dy) = k = x * y
dy = y - ((x * y) / (x + dx * 0.997))
   = (y * (x + dx * 0.997) - x * y) / (x + dx * 0.997)
   = (y * x + y * dx * 0.997 - x * y) / (x + dx * 0.997)
   = (y * dx * 0.997) / (x + dx * 0.997)
   = (y * dx * 997) / (x * 1000 + dx * 997)
```

_--dx: amount of pay tokenX<br>_
_--dy: how many tokenY be output<br>_
_--0.997: 0.3% swap fee<br>_

-   **How many tokenY swap in if intent to receive exact tokenX**

```
(x - dx) * (y + dy * 0.997) = k = x * y
dy = (x * y / (x - dx) - y) / 0.997
   = (x * y - (x - dx) * y) / (x - dx) / 0.997
   = (dx * y) / (x - dx) / 0.997
   = (dx * y) / ((x - dx) * 0.997)
   = (dx * y * 1000) / ((x - dx) * 997)
```

_--dx: expected amount of tokenX<br>_
_--dy: how many tokenY be input<br>_
_--0.997: 0.3% swap fee<br>_

### State Variables

```
TokenPair {
   // tokens in pair
   tokenA
   tokenB
   // reserve of tokens
   tokenA reserve
   tokenB reserve
   // price * timeElapsed
   tokenA priceCumulativeLast
   tokenB priceCumulativeLast
   // only allow factory to initialize pair
   factory
}
```

```
TokenPairFactory {
    // existing pairs: tokenA => tokenB => pair
    getPair
}
```

```
Router {
    // factory to create pair
    factory
    // WETH address: to auto swap between ETH and WETH
    WETH
}
```

### Upgradeability

Token Pair contract and Factory contract are data storage contract, will no change once deployed.
Router contract is the logic to act with user, it's designed as upgradeable contract based on UUPS parttern.

### Access Control

Token Pair contract can only be created and managed by specific Factory contract.
Router contract defines two administration roles (ADMIN_ROLE & UPGRADE_ROLE), only the role user can grant others permissions.

-   UPGRADE_ROLE: Role to upgrade Router contract
-   ADMIN_ROLE: Admin role of Router contract，currently there is no related operations.

### Deploy

#### Localhost

```shell
yarn hardhat deploy --tags all --network hardhat
```

#### Testnet

```shell
yarn hardhat deploy --tags all --network sepolia
```

#### Mainnet

```shell
yarn hardhat deploy --tags all --network mainnet
```

### Unit Test

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

### Requirement Points

##### AMM Implementation

-   [x] supports swapping between ETH and at least two ERC20 tokens
-   [x] allowing users to add/remove liquidity and earn fees
-   [ ] dynamic pricing based on pool reserves
-   [ ] slippage control mechanisms

##### Access Control

-   [x] use role-based access control to manage different permissions within the contract
-   [ ] implement multi-signature requirements for critical

##### Security Features

-   [x] identify and protect against common vulnerabilities
-   [x] implement a circuit breaker or emergency stop function
-   [x] write code that is structured and commented to facilitate third-party audits

##### Upgradeability and Data Migration

-   [x] demonstrate upgrading the contract with changes in the storage structure, ensuring data integrity.
-   [x] provide migration scripts and procedures
-   [ ] utilize the Eternal Storage pattern to manage state separately from logic

##### Gas Optimization

-   [x] optimize functions for minimal gas consumption
-   [x] use events judiciously to balance between necessary logging and gas costs

##### Testing and Quality Assurance

-   [x] write extensive tests covering all functionalities, including unit tests, integration tests, and property-based tests
-   [ ] use static analysis tools to detect potential vulnerabilities

##### Multi-Environment Deployment

-   [x] provide scripts and instructions for deploying to different environments

##### Documentation

-   [x] Include an architectural overview, detailed design rationale
