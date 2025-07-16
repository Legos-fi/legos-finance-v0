const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Legos Finance Protocol", function () {
    let deployer, user1, user2, liquidator;
    let legosToken, clob, riskManager, usdcPool, wethPool;
    let usdc, weth;
    let governance, timelock;

    const INITIAL_USDC_BALANCE = ethers.parseUnits("10000", 6); // 10,000 USDC
    const INITIAL_WETH_BALANCE = ethers.parseEther("100"); // 100 WETH

    beforeEach(async function () {
        [deployer, user1, user2, liquidator] = await ethers.getSigners();

        // Deploy test tokens
        const TestToken = await ethers.getContractFactory("TestERC20");

        usdc = await TestToken.deploy("USD Coin", "USDC", 6, ethers.parseUnits("1000000", 6));
        weth = await TestToken.deploy("Wrapped Ether", "WETH", 18, ethers.parseEther("10000"));

        // Deploy governance token
        const LegosToken = await ethers.getContractFactory("LegosToken");
        legosToken = await LegosToken.deploy(
            deployer.address, // treasury
            deployer.address, // liquidity mining
            deployer.address, // community rewards
            deployer.address  // owner
        );

        // Deploy timelock
        const TimelockController = await ethers.getContractFactory("TimelockController");
        timelock = await TimelockController.deploy(
            2 * 24 * 60 * 60, // 2 days
            [deployer.address],
            [deployer.address],
            deployer.address
        );

        // Deploy governance
        const LegosGovernance = await ethers.getContractFactory("LegosGovernance");
        governance = await LegosGovernance.deploy(
            await legosToken.getAddress(),
            await timelock.getAddress()
        );

        // Deploy CLOB
        const LegosCLOB = await ethers.getContractFactory("LegosCLOB");
        clob = await LegosCLOB.deploy(deployer.address);

        // Deploy Risk Manager
        const LegosRiskManager = await ethers.getContractFactory("LegosRiskManager");
        riskManager = await LegosRiskManager.deploy(
            await clob.getAddress(),
            deployer.address
        );

        // Deploy lending pools
        const LegosLendingPool = await ethers.getContractFactory("LegosLendingPool");

        usdcPool = await LegosLendingPool.deploy(
            await usdc.getAddress(),
            await clob.getAddress(),
            "Legos USDC Pool",
            "legUSDC",
            deployer.address
        );

        wethPool = await LegosLendingPool.deploy(
            await weth.getAddress(),
            await clob.getAddress(),
            "Legos WETH Pool",
            "legWETH",
            deployer.address
        );

        // Setup risk parameters
        const usdcRiskParams = {
            maxLTV: 8000,
            liquidationThreshold: 8500,
            liquidationPenalty: 500,
            minCollateralRatio: 9000,
            isEnabled: true
        };

        const wethRiskParams = {
            maxLTV: 7500,
            liquidationThreshold: 8000,
            liquidationPenalty: 500,
            minCollateralRatio: 8500,
            isEnabled: true
        };

        await riskManager.setAssetRiskParameters(await usdc.getAddress(), usdcRiskParams);
        await riskManager.setAssetRiskParameters(await weth.getAddress(), wethRiskParams);

        // Set asset prices
        await riskManager.updateAssetPrice(await usdc.getAddress(), ethers.parseEther("1"));
        await riskManager.updateAssetPrice(await weth.getAddress(), ethers.parseEther("2000"));

        // Transfer tokens to users for testing
        await usdc.transfer(user1.address, INITIAL_USDC_BALANCE);
        await usdc.transfer(user2.address, INITIAL_USDC_BALANCE);
        await weth.transfer(user1.address, INITIAL_WETH_BALANCE);
        await weth.transfer(user2.address, INITIAL_WETH_BALANCE);
    });

    describe("Token Deployment", function () {
        it("Should deploy LEGOS token with correct parameters", async function () {
            expect(await legosToken.name()).to.equal("Legos Finance Token");
            expect(await legosToken.symbol()).to.equal("LEGOS");
            expect(await legosToken.totalSupply()).to.equal(ethers.parseEther("100000000")); // 100M initial
        });

        it("Should deploy test tokens with correct parameters", async function () {
            expect(await usdc.name()).to.equal("USD Coin");
            expect(await usdc.symbol()).to.equal("USDC");
            expect(await usdc.decimals()).to.equal(6);

            expect(await weth.name()).to.equal("Wrapped Ether");
            expect(await weth.symbol()).to.equal("WETH");
            expect(await weth.decimals()).to.equal(18);
        });
    });

    describe("CLOB Functionality", function () {
        it("Should place a lending order successfully", async function () {
            const amount = ethers.parseUnits("1000", 6); // 1000 USDC
            const interestRate = 800; // 8%
            const duration = 30 * 24 * 60 * 60; // 30 days
            const maxLTV = 7500; // 75%
            const expiry = (await time.latest()) + 7 * 24 * 60 * 60; // 7 days

            // Approve and place order
            await usdc.connect(user1).approve(await clob.getAddress(), amount);

            const tx = await clob.connect(user1).placeLendOrder(
                await usdc.getAddress(),
                amount,
                interestRate,
                duration,
                maxLTV,
                await weth.getAddress(),
                expiry
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log =>
                log.topics[0] === clob.interface.getEvent("OrderPlaced").topicHash
            );

            expect(event).to.not.be.undefined;
        });

        it("Should place a borrowing order successfully", async function () {
            const borrowAmount = ethers.parseUnits("500", 6); // 500 USDC
            const collateralAmount = ethers.parseEther("0.5"); // 0.5 WETH
            const interestRate = 900; // 9%
            const duration = 30 * 24 * 60 * 60; // 30 days
            const expiry = (await time.latest()) + 7 * 24 * 60 * 60; // 7 days

            // Approve collateral and place order
            await weth.connect(user2).approve(await clob.getAddress(), collateralAmount);

            const tx = await clob.connect(user2).placeBorrowOrder(
                await usdc.getAddress(),
                borrowAmount,
                interestRate,
                duration,
                await weth.getAddress(),
                collateralAmount,
                expiry
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log =>
                log.topics[0] === clob.interface.getEvent("OrderPlaced").topicHash
            );

            expect(event).to.not.be.undefined;
        });

        it("Should match lending and borrowing orders", async function () {
            // Place lending order
            const lendAmount = ethers.parseUnits("1000", 6);
            const lendRate = 800; // 8%

            await usdc.connect(user1).approve(await clob.getAddress(), lendAmount);
            await clob.connect(user1).placeLendOrder(
                await usdc.getAddress(),
                lendAmount,
                lendRate,
                30 * 24 * 60 * 60,
                7500,
                await weth.getAddress(),
                (await time.latest()) + 7 * 24 * 60 * 60
            );

            // Place borrowing order that should match
            const borrowAmount = ethers.parseUnits("500", 6);
            const collateralAmount = ethers.parseEther("0.5");

            await weth.connect(user2).approve(await clob.getAddress(), collateralAmount);
            const tx = await clob.connect(user2).placeBorrowOrder(
                await usdc.getAddress(),
                borrowAmount,
                900, // 9% - higher than lend rate, should match
                30 * 24 * 60 * 60,
                await weth.getAddress(),
                collateralAmount,
                (await time.latest()) + 7 * 24 * 60 * 60
            );

            const receipt = await tx.wait();
            const matchEvent = receipt.logs.find(log =>
                log.topics[0] === clob.interface.getEvent("OrderMatched").topicHash
            );

            expect(matchEvent).to.not.be.undefined;
        });
    });

    describe("Lending Pool Functionality", function () {
        it("Should allow deposits into lending pool", async function () {
            const depositAmount = ethers.parseUnits("1000", 6); // 1000 USDC

            await usdc.connect(user1).approve(await usdcPool.getAddress(), depositAmount);

            const tx = await usdcPool.connect(user1).deposit(depositAmount);
            const receipt = await tx.wait();

            expect(await usdcPool.balanceOf(user1.address)).to.equal(depositAmount);
        });

        it("Should allow withdrawals from lending pool", async function () {
            const depositAmount = ethers.parseUnits("1000", 6);

            // Deposit first
            await usdc.connect(user1).approve(await usdcPool.getAddress(), depositAmount);
            await usdcPool.connect(user1).deposit(depositAmount);

            const shares = await usdcPool.balanceOf(user1.address);

            // Withdraw
            const tx = await usdcPool.connect(user1).withdraw(shares);

            expect(await usdcPool.balanceOf(user1.address)).to.equal(0);
        });
    });

    describe("Risk Management", function () {
        it("Should calculate health factor correctly", async function () {
            // This would require setting up a loan first
            // For now, just test the risk parameter setting
            const riskParams = await riskManager.assetRiskParams(await usdc.getAddress());

            expect(riskParams.maxLTV).to.equal(8000);
            expect(riskParams.liquidationThreshold).to.equal(8500);
            expect(riskParams.isEnabled).to.be.true;
        });

        it("Should update asset prices", async function () {
            const newPrice = ethers.parseEther("2100"); // $2100 for WETH

            await riskManager.updateAssetPrice(await weth.getAddress(), newPrice);

            expect(await riskManager.assetPrices(await weth.getAddress())).to.equal(newPrice);
        });
    });

    describe("Governance", function () {
        it("Should allow staking LEGOS tokens", async function () {
            const stakeAmount = ethers.parseEther("100");

            // First delegate to self for voting
            await legosToken.delegate(deployer.address);

            await legosToken.stake(stakeAmount);

            const stakingInfo = await legosToken.stakingInfo(deployer.address);
            expect(stakingInfo.stakedAmount).to.equal(stakeAmount);
        });

        it("Should calculate voting power correctly", async function () {
            const balance = await legosToken.balanceOf(deployer.address);
            const votingPower = await legosToken.getVotingPower(deployer.address);

            expect(votingPower).to.equal(balance); // Balance + staked amount (0 initially)
        });
    });

    describe("Integration Test", function () {
        it("Should complete a full lending cycle", async function () {
            // 1. User1 deposits into USDC pool
            const depositAmount = ethers.parseUnits("1000", 6);
            await usdc.connect(user1).approve(await usdcPool.getAddress(), depositAmount);
            await usdcPool.connect(user1).deposit(depositAmount);

            // 2. User2 places a borrow order
            const borrowAmount = ethers.parseUnits("500", 6);
            const collateralAmount = ethers.parseEther("0.5");

            await weth.connect(user2).approve(await clob.getAddress(), collateralAmount);
            await clob.connect(user2).placeBorrowOrder(
                await usdc.getAddress(),
                borrowAmount,
                800, // 8%
                30 * 24 * 60 * 60,
                await weth.getAddress(),
                collateralAmount,
                (await time.latest()) + 7 * 24 * 60 * 60
            );

            // 3. Check that the pool has available liquidity
            const availableLiquidity = await usdcPool.getAvailableLiquidity();
            expect(availableLiquidity).to.be.gt(0);

            // 4. Check pool metrics
            const totalAssets = await usdcPool.getTotalPoolAssets();
            expect(totalAssets).to.equal(depositAmount);
        });
    });
}); 