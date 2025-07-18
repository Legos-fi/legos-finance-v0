const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 Starting Legos Finance Protocol Deployment to Rise Testnet...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", ethers.formatEther(balance), "ETH\n");

    const deployedContracts = {};

    try {
        // 1. Deploy Governance Token (LEGOS)
        console.log("📜 Deploying Governance Token...");
        const LegosToken = await ethers.getContractFactory("LegosToken");
        const legosToken = await LegosToken.deploy(
            deployer.address, // treasury
            deployer.address, // liquidity mining
            deployer.address, // community rewards
            deployer.address  // admin
        );
        await legosToken.waitForDeployment();
        
        const legosTokenAddress = await legosToken.getAddress();
        deployedContracts.legosToken = legosTokenAddress;
        console.log("✅ LEGOS Token deployed to:", legosTokenAddress);

        // 2. Deploy Timelock Controller
        console.log("\n⏰ Deploying Timelock Controller...");
        const TimelockController = await ethers.getContractFactory("TimelockController");
        const timelock = await TimelockController.deploy(
            2 * 24 * 60 * 60, // 2 days
            [deployer.address], // proposers
            [deployer.address], // executors
            deployer.address    // admin
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

        // 4. Deploy CLOB Contract
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

        // 6. Save deployment info
        const deploymentInfo = {
            network: "riseTestnet",
            chainId: 11155931,
            timestamp: new Date().toISOString(),
            deployer: deployer.address,
            contracts: deployedContracts,
            blockNumber: await ethers.provider.getBlockNumber()
        };

        const deploymentsDir = path.join(__dirname, '..', 'deployments');
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        const deploymentFile = path.join(deploymentsDir, 'riseTestnet.json');
        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));

        console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);
        
        // 7. Print summary
        console.log("\n🎉 Legos Finance Protocol Deployment Complete!");
        console.log("=".repeat(60));
        console.log("📋 Deployment Summary:");
        console.log("=".repeat(60));

        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`${name.padEnd(20)}: ${address}`);
        });

        console.log("\n🌐 Rise Testnet Explorer:");
        console.log("https://explorer.testnet.riselabs.xyz");
        
        console.log("\n🔧 Next Steps:");
        console.log("1. Verify contracts on Rise Explorer");
        console.log("2. Initialize the protocol");
        console.log("3. Set up frontend configuration");

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });