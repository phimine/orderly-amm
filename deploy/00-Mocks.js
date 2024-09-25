const { getNamedAccounts, deployments, ethers, network } = require("hardhat");
const { devChains } = require("../helper-hardhat-config");

module.exports = async () => {
    // 本地网络执行mocks
    if (devChains.includes(network.name)) {
        console.log("Deploying mocks...");

        const { deploy, log } = deployments;
        const { deployer } = await getNamedAccounts();

        const mockWETH = await deploy("MockWETH", {
            from: deployer,
            args: [],
            log: true,
        });
        log("mockWETH contract deployed at ", mockWETH.address);

        const mockUSDT = await deploy("MockUSDT", {
            from: deployer,
            args: [],
            log: true,
        });
        log("mockUSDT contract deployed at ", mockUSDT.address);
    }
};

module.exports.tags = ["all", "mocks"];
