### Project Overview

An upgradeable AMM Defi contract, allows users to swap between ETH and multiple ERC20 tokens using an Automated Market Maker (AMM) model.

### Functions Split

#### TokenPair.sol（only support swaping between ETH and ERC20）

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
