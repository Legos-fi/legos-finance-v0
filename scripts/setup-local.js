const { spawn } = require('child_process');
const path = require('path');

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runCommand(command, args = [], options = {}) {
    return new Promise((resolve, reject) => {
        const proc = spawn(command, args, {
            stdio: 'inherit',
            shell: true,
            ...options
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`${command} exited with code ${code}`));
            } else {
                resolve();
            }
        });

        proc.on('error', (err) => {
            reject(err);
        });
    });
}

async function main() {
    console.log('🚀 Starting Legos Finance Local Setup...\n');

    try {
        // Step 1: Start Hardhat node in background
        console.log('1️⃣  Starting Hardhat node...');
        const hardhatProcess = spawn('npx', ['hardhat', 'node'], {
            detached: false,
            stdio: ['ignore', 'pipe', 'pipe']
        });

        // Listen for the node to be ready
        let nodeReady = false;
        hardhatProcess.stdout.on('data', (data) => {
            const output = data.toString();
            if (output.includes('Started HTTP and WebSocket JSON-RPC server')) {
                nodeReady = true;
                console.log('✅ Hardhat node is running on http://127.0.0.1:8545/\n');
            }
        });

        // Wait for node to be ready
        let waitTime = 0;
        while (!nodeReady && waitTime < 30000) {
            await sleep(1000);
            waitTime += 1000;
        }

        if (!nodeReady) {
            throw new Error('Hardhat node failed to start');
        }

        // Step 2: Deploy contracts
        console.log('2️⃣  Deploying contracts...');
        await runCommand('npm', ['run', 'deploy:local']);

        // Step 3: Start frontend
        console.log('\n3️⃣  Starting frontend...');
        console.log('The frontend will start in a moment. Please wait...\n');

        const frontendProcess = spawn('npm', ['run', 'frontend:start'], {
            stdio: 'inherit'
        });

        console.log('\n✨ Setup complete! The application should open in your browser automatically.');
        console.log('\n📝 Next steps:');
        console.log('   1. Connect MetaMask to http://localhost:8545');
        console.log('   2. Import test accounts using private keys from Hardhat');
        console.log('   3. Add test tokens to MetaMask using the deployed addresses');
        console.log('\n⚠️  Keep this terminal open to keep the services running.');
        console.log('Press Ctrl+C to stop all services.\n');

        // Handle cleanup
        process.on('SIGINT', () => {
            console.log('\n\n🛑 Shutting down services...');
            hardhatProcess.kill();
            frontendProcess.kill();
            process.exit(0);
        });

    } catch (error) {
        console.error('\n❌ Setup failed:', error.message);
        process.exit(1);
    }
}

main().catch(console.error); 