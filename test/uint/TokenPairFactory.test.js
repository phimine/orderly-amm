const { getNamedAccounts, deployments, ethers } = require("hardhat");
const { assert, expect } = require("chai");

describe("TokenPairFactory", async function () {
    let factoryContract;
    let deployer;
    let userA, userB, userC;
    beforeEach(async function () {
        // deploy contract using hardhat-deploy
        const accounts = await getNamedAccounts();
        // [, userA, userB, userC] = await ethers.getSigners();
        deployer = accounts.deployer;
        await deployments.fixture("factory");
        factoryContract = await deployments.get("TokenPairFactory");
        factoryContract = await ethers.getContractAt(
            factoryContract.abi,
            factoryContract.address,
        );
    });

    describe("constructor", async function () {
        it("should has no pair in initial factory", async function () {
            const response = await factoryContract.allPairsLength();
            assert.equal(response, 0);
        });
    });

    describe("createPair", async function () {
        let tokenA = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
        let WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH

        it("should revert with SAME_ADDRESSES error if token pair are the same one", async function () {
            await expect(
                factoryContract.createPair(tokenA, tokenA),
            ).to.revertedWith("TokenPairFactory: SAME_ADDRESSES");
        });
        it("should revert with ZERO_ADDRESS error if one token of pair is zero address", async function () {
            await expect(
                factoryContract.createPair(ethers.ZeroAddress, tokenA),
            ).to.revertedWith("TokenPairFactory: ZERO_ADDRESS");
        });
        it("should create pair correctly", async function () {
            await factoryContract.createPair(WETH, tokenA);

            const pairLength = await factoryContract.allPairsLength();
            assert.equal(pairLength, 1);

            const pair = await factoryContract.allPairs(0);
            assert.equal(pair, "0xad5AAeA22D55FaE8F93Cc496C7211f2AEAC5Cc26");

            const pair1 = await factoryContract.getPair(WETH, tokenA);
            const pair2 = await factoryContract.getPair(tokenA, WETH);
            assert.equal(pair, pair1);
            assert.equal(pair, pair2);
        });
        it("should emit PairCreated", async function () {
            await expect(factoryContract.createPair(WETH, tokenA))
                .to.emit(factoryContract, "PairCreated")
                .withArgs(
                    WETH,
                    tokenA,
                    "0xad5AAeA22D55FaE8F93Cc496C7211f2AEAC5Cc26",
                    1,
                );
        });
        it("should revert with PAIR_EXISTS error if pair exists", async function () {
            await factoryContract.createPair(WETH, tokenA);
            await expect(
                factoryContract.createPair(tokenA, WETH),
            ).to.revertedWith("TokenPairFactory: PAIR_EXISTS");
        });
    });
});
