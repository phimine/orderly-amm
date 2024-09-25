const { devChains, WETH } = require("../helper-hardhat-config");

module.exports = async ({
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
}) => {
    const { log } = deployments;
    const contractName = "AMMRouter";

    const router = await ethers.getContractFactory(contractName);
    const tokenAddress = (await deployments.get("TokenPairFactory")).address;
    let weth;
    if (devChains.includes(network.name)) {
        weth = (await deployments.get("MockWETH")).address;
    } else {
        weth = WETH;
    }
    const args = [tokenAddress, weth];

    const contract = await upgrades.deployProxy(router, args, {
        initializer: "initialize",
    });
    await contract.waitForDeployment();

    await deployments.save(contractName, {
        address: contract.target,
        abi: JSON.stringify(contract.interface),
    });
    log("current block number is ", await ethers.provider.getBlockNumber());
    log("AMMRouter deployed to ", contract.target);
    log("weth is ", weth);
};

module.exports.tags = ["all", "router"];
