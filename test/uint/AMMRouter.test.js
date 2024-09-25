const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { assert, expect } = require("chai");
const { WETH, USDT, UNI } = require("../../helper-hardhat-config");

const CONTRACT_NAME = "AMMRouter";
describe(CONTRACT_NAME, async () => {
    let routerContract, routerAddress;
    let factoryContract, factoryAddress;
    let wethContract, weth;
    let usdtContract, usdt;
    let deployer, userA, userB, userC;
    beforeEach(async () => {
        [deployer, userA, userB, userC] = await ethers.getSigners();

        await deployments.fixture(["mocks", "factory", "router"]);
        routerAddress = (await deployments.get(CONTRACT_NAME)).address;
        routerContract = await ethers.getContractAt(
            CONTRACT_NAME,
            routerAddress,
        );

        factoryAddress = (await deployments.get("TokenPairFactory")).address;
        factoryContract = await ethers.getContractAt(
            "TokenPairFactory",
            factoryAddress,
        );

        weth = (await deployments.get("MockWETH")).address;
        wethContract = await ethers.getContractAt("MockWETH", weth);

        usdt = (await deployments.get("MockUSDT")).address;
        usdtContract = await ethers.getContractAt("MockUSDT", usdt);
    });

    describe("initialize", async () => {
        it("should set factory and WETH address correctly", async () => {
            const _factory = await routerContract.factory();
            const _weth = await routerContract.WETH();
            assert.equal(_factory, factoryAddress);
            assert.equal(_weth, weth);
        });
    });

    describe("addLiquidityETH", async () => {
        let ethUsdtPairAddress = "0xe6cba1ab0fbfa93c7e91d25b11898ddd874a88c4";
        let ethUsdtPair;
        beforeEach(async () => {
            await wethContract.connect(userC).deposit({ value: 999 });

            await usdtContract.mint(userA, ethers.parseUnits("1", 18));
            await usdtContract.mint(userB, ethers.parseUnits("1", 18));
            await usdtContract.mint(userC, ethers.parseUnits("1", 18));

            await usdtContract
                .connect(userA)
                .approve(routerAddress, ethers.parseUnits("1", 18));
            await usdtContract
                .connect(userB)
                .approve(routerAddress, ethers.parseUnits("1", 18));
            await usdtContract
                .connect(userC)
                .approve(routerAddress, ethers.parseUnits("1", 18));
        });
        it("should initial liquidity pool correctly if pair does not exist", async () => {
            ethUsdtPair = await ethers.getContractAt(
                "TokenPair",
                ethUsdtPairAddress,
            );
            const balanceBefore =
                await wethContract.balanceOf(ethUsdtPairAddress);
            const usdtBalanceBefore =
                await usdtContract.balanceOf(ethUsdtPairAddress);

            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                });

            // token pair created correctly
            const pairLength = await factoryContract.allPairsLength();
            assert.equal(pairLength, 1);
            const pair = await factoryContract.allPairs(0);
            assert.equal(pair.toLowerCase(), ethUsdtPairAddress.toLowerCase());

            const balanceAfter =
                await wethContract.balanceOf(ethUsdtPairAddress);
            const usdtBalanceAfter =
                await usdtContract.balanceOf(ethUsdtPairAddress);
            // LP provide correct liquidity to pair
            assert.equal(balanceAfter - balanceBefore, 100n);
            assert.equal(usdtBalanceAfter - usdtBalanceBefore, 200000n);

            // compute liquidity correctly
            const liquidity = await ethUsdtPair.balanceOf(userA);
            assert.equal(liquidity, 3472n); // （√200000 * 100） - 1000
        });
        it("should revert with INSUFFICIENT_AMOUNT error if optimal token is less than min amount when provide for existing pair", async () => {
            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                });

            await expect(
                routerContract
                    .connect(userB)
                    .addLiquidityETH(usdt, 200000, 100000, 1, userB, {
                        value: 2,
                    }),
            ).to.revertedWith("AMMRouter: INSUFFICIENT_A_AMOUNT");

            await expect(
                routerContract
                    .connect(userC)
                    .addLiquidityETH(usdt, 2000, 1000, 50, userC, {
                        value: 100,
                    }),
            ).to.revertedWith("AMMRouter: INSUFFICIENT_B_AMOUNT");
        });
    });
});
