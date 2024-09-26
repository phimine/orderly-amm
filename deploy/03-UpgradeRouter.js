const {
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
} = require("hardhat");
const { routerProxyAddress } = require("../helper-hardhat-config");

module.exports = async () => {
    const { log } = deployments;
    const CONTRACT_NAME = "AMMRouter";

    const proxyAddress = routerProxyAddress[network.name]; //(await deployments.get(CONTRACT_NAME)).address;
    log("old AMMRouter deployed to ", proxyAddress);
    const contractFactory = await ethers.getContractFactory(CONTRACT_NAME);
    const updated = await upgrades.upgradeProxy(proxyAddress, contractFactory);
    await updated.waitForDeployment();
    await deployments.save(CONTRACT_NAME, {
        address: updated.target,
        abi: JSON.stringify(updated.interface),
    });
    log("new AMMRouter deployed to ", updated.target);
};
module.exports.tags = ["routerupgrade"];
