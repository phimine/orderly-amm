const { network } = require("hardhat");
const { devChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
require("dotenv").config();

module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("Deploying TokenPairFactory contract...");
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log(`deployer is: ${deployer}`);
    const chainId = network.config.chainId;
    console.log(`chainId is: ${chainId}`);

    let factoryContract;
    const args = [];
    if (devChains.includes(network.name)) {
        factoryContract = await deploy("TokenPairFactory", {
            from: deployer,
            args: args,
            log: true,
        });
        log(`--------TokenPairFactory deployed at ${factoryContract.address}`);
    } else if (process.env.ETHERSCAN_API_KEY) {
        // verify contract in test network or main network
        await verify(factoryContract.address, args);
    }
};

module.exports.tags = ["all", "factory"];
