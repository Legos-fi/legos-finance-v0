const { ethers } = require("hardhat");

async function main() {
    console.log("🧪 Simple CLOB Test...\n");

    try {
        // Get the first signer
        const [deployer] = await ethers.getSigners();
        console.log("Using account:", deployer.address);

        // Check if we can get the CLOB contract factory
        const CLOBFactory = await ethers.getContractFactory("LegosCLOB");
        console.log("✅ CLOB contract factory loaded successfully");

        // Try to get network info
        const network = await ethers.provider.getNetwork();
        console.log("Connected to network:", network.chainId);

        // Check balance
        const balance = await ethers.provider.getBalance(deployer.address);
        console.log("Account balance:", ethers.formatEther(balance), "ETH");

        console.log("\n🎉 Basic connectivity test passed!");
        
    } catch (error) {
        console.error("❌ Test failed:", error.message);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Error:", error);
        process.exit(1);
    });