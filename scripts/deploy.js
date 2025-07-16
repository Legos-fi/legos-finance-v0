const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 Starting Legos Finance Protocol Deployment...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", ethers.formatEther(balance), "ETH\n");

    const deployedContracts = {};

    try {
        // 1. Deploy Governance Token (LEGOS)
        console.log("📜 Deploying Governance Token...");

        // Placeholder addresses - in production these would be real addresses
        const treasuryAddress = deployer.address; // Temporary treasury
        const liquidityMiningAddress = deployer.address; // Temporary LM address
        const communityRewardsAddress = deployer.address; // Temporary community address

        const LegosToken = await ethers.getContractFactory("LegosToken");
        const legosToken = await LegosToken.deploy(
            treasuryAddress,
            liquidityMiningAddress,
            communityRewardsAddress,
            deployer.address
        );
        await legosToken.waitForDeployment();

        const legosTokenAddress = await legosToken.getAddress();
        deployedContracts.legosToken = legosTokenAddress;
        console.log("✅ LEGOS Token deployed to:", legosTokenAddress);

        // 2. Deploy Timelock Controller for Governance
        console.log("\n⏰ Deploying Timelock Controller...");

        const minDelay = 2 * 24 * 60 * 60; // 2 days
        const proposers = [deployer.address]; // Will be updated to governance contract
        const executors = [deployer.address]; // Will be updated to governance contract
        const admin = deployer.address; // Will renounce after setup

        const TimelockController = await ethers.getContractFactory("TimelockController");
        const timelock = await TimelockController.deploy(
            minDelay,
            proposers,
            executors,
            admin
        );
        await timelock.waitForDeployment();

        const timelockAddress = await timelock.getAddress();
        deployedContracts.timelock = timelockAddress;
        console.log("✅ Timelock Controller deployed to:", timelockAddress);

        // 3. Deploy Governance Contract
        console.log("\n🗳️  Deploying Governance Contract...");

        const LegosGovernance = await ethers.getContractFactory("LegosGovernance");
        const governance = await LegosGovernance.deploy(
            legosTokenAddress,
            timelockAddress
        );
        await governance.waitForDeployment();

        const governanceAddress = await governance.getAddress();
        deployedContracts.governance = governanceAddress;
        console.log("✅ Governance Contract deployed to:", governanceAddress);

        // 4. Deploy Central Limit Order Book (CLOB)
        console.log("\n📊 Deploying CLOB Contract...");

        const LegosCLOB = await ethers.getContractFactory("LegosCLOB");
        const clob = await LegosCLOB.deploy(deployer.address);
        await clob.waitForDeployment();

        const clobAddress = await clob.getAddress();
        deployedContracts.clob = clobAddress;
        console.log("✅ CLOB Contract deployed to:", clobAddress);

        // 5. Deploy Risk Manager
        console.log("\n⚠️  Deploying Risk Manager...");

        const LegosRiskManager = await ethers.getContractFactory("LegosRiskManager");
        const riskManager = await LegosRiskManager.deploy(
            clobAddress,
            deployer.address
        );
        await riskManager.waitForDeployment();

        const riskManagerAddress = await riskManager.getAddress();
        deployedContracts.riskManager = riskManagerAddress;
        console.log("✅ Risk Manager deployed to:", riskManagerAddress);

        // 6. Deploy Sample ERC20 tokens for testing
        console.log("\n🪙 Deploying Test Tokens...");

        const TestToken = await ethers.getContractFactory("contracts/test/TestERC20.sol:TestERC20");

        // Deploy USDC test token
        const usdc = await TestToken.deploy(
            "USD Coin",
            "USDC",
            6, // 6 decimals like real USDC
            ethers.parseUnits("1000000", 6) // 1M USDC
        );
        await usdc.waitForDeployment();

        const usdcAddress = await usdc.getAddress();
        deployedContracts.usdc = usdcAddress;
        console.log("✅ Test USDC deployed to:", usdcAddress);

        // Deploy WETH test token
        const weth = await TestToken.deploy(
            "Wrapped Ether",
            "WETH",
            18,
            ethers.parseEther("10000") // 10K WETH
        );
        await weth.waitForDeployment();

        const wethAddress = await weth.getAddress();
        deployedContracts.weth = wethAddress;
        console.log("✅ Test WETH deployed to:", wethAddress);

        // 7. Deploy Lending Pools
        console.log("\n🏦 Deploying Lending Pools...");

        const LegosLendingPool = await ethers.getContractFactory("LegosLendingPool");

        // Deploy USDC Lending Pool
        const usdcPool = await LegosLendingPool.deploy(
            usdcAddress,
            clobAddress,
            "Legos USDC Pool",
            "legUSDC",
            deployer.address
        );
        await usdcPool.waitForDeployment();

        const usdcPoolAddress = await usdcPool.getAddress();
        deployedContracts.usdcPool = usdcPoolAddress;
        console.log("✅ USDC Lending Pool deployed to:", usdcPoolAddress);

        // Deploy WETH Lending Pool
        const wethPool = await LegosLendingPool.deploy(
            wethAddress,
            clobAddress,
            "Legos WETH Pool",
            "legWETH",
            deployer.address
        );
        await wethPool.waitForDeployment();

        const wethPoolAddress = await wethPool.getAddress();
        deployedContracts.wethPool = wethPoolAddress;
        console.log("✅ WETH Lending Pool deployed to:", wethPoolAddress);

        // 8. Configure Risk Parameters
        console.log("\n⚙️  Configuring Risk Parameters...");

        // Set risk parameters for USDC
        const usdcRiskParams = {
            maxLTV: 8000, // 80%
            liquidationThreshold: 8500, // 85%
            liquidationPenalty: 500, // 5%
            minCollateralRatio: 9000, // 90%
            isEnabled: true
        };

        await riskManager.setAssetRiskParameters(usdcAddress, usdcRiskParams);
        console.log("✅ USDC risk parameters configured");

        // Set risk parameters for WETH
        const wethRiskParams = {
            maxLTV: 7500, // 75%
            liquidationThreshold: 8000, // 80%
            liquidationPenalty: 500, // 5%
            minCollateralRatio: 8500, // 85%
            isEnabled: true
        };

        await riskManager.setAssetRiskParameters(wethAddress, wethRiskParams);
        console.log("✅ WETH risk parameters configured");

        // Set initial prices (simplified - in production use proper oracles)
        await riskManager.updateAssetPrice(usdcAddress, ethers.parseEther("1")); // $1
        await riskManager.updateAssetPrice(wethAddress, ethers.parseEther("2000")); // $2000
        console.log("✅ Initial asset prices set");

        // 9. Skip governance authorization for local testing
        console.log("\n🔐 Skipping governance authorization for local testing...");
        console.log("✅ Contracts remain owned by deployer for easier testing");

        // For production, uncomment the following:
        // await governance.setContractAuthorization(clobAddress, true);
        // await governance.setContractAuthorization(riskManagerAddress, true);
        // await governance.setContractAuthorization(usdcPoolAddress, true);
        // await governance.setContractAuthorization(wethPoolAddress, true);
        // await clob.transferOwnership(timelockAddress);
        // await riskManager.transferOwnership(timelockAddress);
        // await usdcPool.transferOwnership(timelockAddress);
        // await wethPool.transferOwnership(timelockAddress);

        // 11. Distribute initial token allocation
        console.log("\n💰 Distributing Token Allocations...");

        await legosToken.distributeAllocations();
        console.log("✅ Token allocations distributed");

        // 12. Save deployment info
        const deploymentInfo = {
            network: await ethers.provider.getNetwork(),
            timestamp: new Date().toISOString(),
            deployer: deployer.address,
            contracts: deployedContracts,
            gasUsed: "TBD", // Would need to track gas usage
            blockNumber: await ethers.provider.getBlockNumber()
        };

        const deploymentsDir = path.join(__dirname, '..', 'deployments');
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        const networkName = (await ethers.provider.getNetwork()).name;
        const deploymentFile = path.join(deploymentsDir, `${networkName}.json`);
        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));

        console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);

        // 13. Print summary
        console.log("\n🎉 Legos Finance Protocol Deployment Complete!");
        console.log("=".repeat(60));
        console.log("📋 Deployment Summary:");
        console.log("=".repeat(60));

        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`${name.padEnd(20)}: ${address}`);
        });

        console.log("\n🔧 Next Steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Set up proper oracle integration");
        console.log("3. Initialize liquidity pools");
        console.log("4. Configure market maker parameters");
        console.log("5. Set up monitoring and alerting");

        console.log("\n⚠️  Important Notes:");
        console.log("- Current deployment uses test tokens and simplified oracles");
        console.log("- Risk parameters should be reviewed and adjusted for production");
        console.log("- Consider implementing additional security measures");
        console.log("- Test thoroughly before mainnet deployment");

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }
}

// Create test ERC20 token contract inline for deployment
const testTokenSource = `
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, Ownable {
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply);
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
`;

// Write test token contract
const contractsDir = path.join(__dirname, '..', 'contracts', 'test');
if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
}
fs.writeFileSync(path.join(contractsDir, 'TestERC20.sol'), testTokenSource);

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 