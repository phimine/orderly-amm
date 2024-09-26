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
        let ethUsdtPairAddress = "0xb7e5b2476c24b2235fcd205208e81d9e79b6951e";
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

            // const ethBalanceUserABefore =
            //     await ethers.provider.getBalance(userA);
            const usdtBalanceUserABefore = await usdtContract.balanceOf(userA);

            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                });

            // 1. token pair created correctly
            const pairLength = await factoryContract.allPairsLength();
            assert.equal(pairLength, 1);
            const pair = await factoryContract.allPairs(0);
            assert.equal(pair.toLowerCase(), ethUsdtPairAddress.toLowerCase());

            const balanceAfter =
                await wethContract.balanceOf(ethUsdtPairAddress);
            const usdtBalanceAfter =
                await usdtContract.balanceOf(ethUsdtPairAddress);
            // 2. liquidity in pair increase correctly
            assert.equal(balanceAfter - balanceBefore, 100n);
            assert.equal(usdtBalanceAfter - usdtBalanceBefore, 200000n);

            // 3. mint liquidity token correctly
            const liquidity = await ethUsdtPair.balanceOf(userA);
            assert.equal(liquidity, 3472n); // （√200000 * 100） - 1000

            // 4. userA deposit correctly
            // const ethBalanceUserAAfter =
            //     await ethers.provider.getBalance(userA);
            const usdtBalanceUserAAfter = await usdtContract.balanceOf(userA);
            assert.equal(
                usdtBalanceUserABefore - usdtBalanceUserAAfter,
                200000n,
            );
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
        it("should provide correct liquidity for existing pair", async () => {
            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                }); // 200 000 usdt + 100 weth

            const balanceBefore =
                await wethContract.balanceOf(ethUsdtPairAddress);
            const usdtBalanceBefore =
                await usdtContract.balanceOf(ethUsdtPairAddress);
            await routerContract
                .connect(userB)
                .addLiquidityETH(usdt, 20000, 10000, 5, userB, {
                    value: 20,
                }); // 20 000 usdt + 10 weth
            const balanceAfter =
                await wethContract.balanceOf(ethUsdtPairAddress);
            const usdtBalanceAfter =
                await usdtContract.balanceOf(ethUsdtPairAddress);
            // LP provide correct liquidity to pair
            assert.equal(balanceAfter - balanceBefore, 10n);
            assert.equal(usdtBalanceAfter - usdtBalanceBefore, 20000n);

            // compute liquidity correctly
            const liquidity = await ethUsdtPair.balanceOf(userB);
            assert.equal(liquidity, 447n); // 10 / 100 * 4472
        });
    });

    describe("removeLiquidityETH", async () => {
        let ethUsdtPairAddress = "0xb7e5b2476c24b2235fcd205208e81d9e79b6951e";
        let ethUsdtPair;
        let wethBalanceInPair, usdtBalanceInPair;
        let userALP, userBLP;
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

            ethUsdtPair = await ethers.getContractAt(
                "TokenPair",
                ethUsdtPairAddress,
            );
            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                }); // 200 000 usdt + 100 weth
            userALP = 3472n;
            await routerContract
                .connect(userB)
                .addLiquidityETH(usdt, 20000, 10000, 5, userB, {
                    value: 20,
                }); // 20 000 usdt + 10 weth
            userBLP = 447n;
            wethBalanceInPair =
                await wethContract.balanceOf(ethUsdtPairAddress); // 110 weth
            usdtBalanceInPair =
                await usdtContract.balanceOf(ethUsdtPairAddress); // 220 000usdt

            await ethUsdtPair.connect(userA).approve(routerAddress, userALP);
            await ethUsdtPair.connect(userB).approve(routerAddress, userBLP);
        });
        it("should decrease liquidity correctly after removing", async () => {
            const usdtBalanceUserABefore = await usdtContract.balanceOf(userA);

            await routerContract
                .connect(userA)
                .removeLiquidityETH(usdt, 447, 10000, 5, userA); // remove 1 / 10 liquidity
            // 1. burn liquidity token correctly
            const liquidityAfter = await ethUsdtPair.balanceOf(userA); // 3472 - 447 = 3025
            assert.equal(liquidityAfter, 3025n);

            // 2. remove liquidity correctly
            // 447 * 220 000 / (3472 + 1000 + 447) = 19991。868
            // 447 * 110 / (3472 + 1000 + 447) = 9.995
            wethBalanceInPairAfter =
                await wethContract.balanceOf(ethUsdtPairAddress); // 110 weth
            usdtBalanceInPairAfter =
                await usdtContract.balanceOf(ethUsdtPairAddress); // 220 000usdt
            assert.equal(wethBalanceInPair - wethBalanceInPairAfter, 9n);
            assert.equal(usdtBalanceInPair - usdtBalanceInPairAfter, 19991n);

            const usdtBalanceUserAAfter = await usdtContract.balanceOf(userA);
            assert.equal(
                usdtBalanceUserAAfter - usdtBalanceUserABefore,
                19991n,
            );
        });
        it("should revert with INSUFFICIENT_AMOUNT error if output token is less than min amount", async () => {
            await expect(
                routerContract
                    .connect(userA)
                    .removeLiquidityETH(usdt, 447, 20000, 5, userA),
            ).to.revertedWith("AMMRouter: INSUFFICIENT_A_AMOUNT");

            await expect(
                routerContract
                    .connect(userA)
                    .removeLiquidityETH(usdt, 447, 10000, 10, userA),
            ).to.revertedWith("AMMRouter: INSUFFICIENT_B_AMOUNT");
        });
    });

    describe("swapExactETHForTokens", async () => {
        let ethUsdtPairAddress = "0xb7e5b2476c24b2235fcd205208e81d9e79b6951e";
        let ethUsdtPair;
        let wethBalanceInPair, usdtBalanceInPair;
        let userALP, userBLP;
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

            ethUsdtPair = await ethers.getContractAt(
                "TokenPair",
                ethUsdtPairAddress,
            );
            await routerContract
                .connect(userA)
                .addLiquidityETH(usdt, 200000, 100000, 50, userA, {
                    value: 100,
                }); // 200 000 usdt + 100 weth
            userALP = 3472n;
            await routerContract
                .connect(userB)
                .addLiquidityETH(usdt, 20000, 10000, 5, userB, {
                    value: 20,
                }); // 20 000 usdt + 10 weth
            userBLP = 447n;
            wethBalanceInPair =
                await wethContract.balanceOf(ethUsdtPairAddress); // 110 weth
            usdtBalanceInPair =
                await usdtContract.balanceOf(ethUsdtPairAddress); // 220 000usdt

            await ethUsdtPair.connect(userA).approve(routerAddress, userALP);
            await ethUsdtPair.connect(userB).approve(routerAddress, userBLP);
        });
        it("should revert with INSUFFICIENT_OUTPUT_AMOUNT error if output token is less than amountOutMin", async () => {
            await expect(
                routerContract
                    .connect(userC)
                    .swapExactETHForTokens(3000, usdt, userC, { value: 1 }),
            ).to.revertedWith("AMMRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        });
        it("should swap to get token via exact ETH correctly", async () => {
            const usdtBalanceBefore = await usdtContract.balanceOf(userC);
            const tx = await routerContract
                .connect(userC)
                .swapExactETHForTokens(300, usdt, userC, { value: 1 });
            const receipt = await tx.wait();
            // (1 * 997 * 220 000) / (110 * 1000 + 1 * 997) = 1976
            const usdtBalanceAfter = await usdtContract.balanceOf(userC);
            assert.equal(usdtBalanceAfter - usdtBalanceBefore, 1976n);
        });
    });
    // TODO - swapETHForExactTokens
    describe("swapETHForExactTokens", async () => {
        beforeEach(async () => {});
        it("should swap to get token via exact ETH correctly", async () => {});
    });
    // TODO - swapExactTokensForETH
    describe("swapExactTokensForETH", async () => {
        beforeEach(async () => {});
        it("should swap to get ETH via exact ERC20 correctly", async () => {});
    });
    // TODO - swapTokensForExactETH
    describe("swapTokensForExactETH", async () => {
        beforeEach(async () => {});
        it("should swap to get ETH via exact ERC20 correctly", async () => {});
    });
});
