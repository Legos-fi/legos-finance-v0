# 🚀 Quick Start - Run Legos Finance Locally

## Prerequisites
- Node.js v16+ and npm installed
- MetaMask browser extension

## One-Command Setup

```bash
npm run start:local
```

This single command will:
1. ✅ Start a local blockchain
2. ✅ Deploy all smart contracts
3. ✅ Start the frontend application
4. ✅ Open the app in your browser

## Configure MetaMask

1. **Add Local Network**
   - Network Name: `Hardhat Local`
   - RPC URL: `http://localhost:8545`
   - Chain ID: `31337`
   - Currency Symbol: `ETH`

2. **Import Test Account**
   - Copy a private key from the Hardhat console output
   - In MetaMask: Account → Import Account → Paste private key

3. **Add Test Tokens**
   - After deployment, you'll see token addresses in the console
   - In MetaMask: Assets → Import Token → Paste token address

## Manual Setup (Alternative)

If you prefer to run services separately:

### Terminal 1 - Blockchain
```bash
npx hardhat node
```

### Terminal 2 - Deploy & Frontend
```bash
npm run deploy:local
npm run frontend:start
```

## Troubleshooting

**Port already in use?**
```bash
# Kill processes on ports 8545 and 3000
lsof -ti:8545 | xargs kill -9
lsof -ti:3000 | xargs kill -9
```

**Clear everything and start fresh?**
```bash
npm run clean:all
npm run setup:force
npm run start:local
```

## Test the Protocol

1. **Connect Wallet** - Click "Connect Wallet" in the app
2. **Get Test Tokens** - Tokens are pre-minted to test accounts
3. **Try Features**:
   - Place lending/borrowing orders
   - Deposit to liquidity pools
   - Check risk dashboard
   - Participate in governance

## Stop Services

Press `Ctrl+C` in the terminal to stop all services.

---

Need help? Check the [detailed setup guide](./LOCAL_SETUP.md) or [quickstart](./QUICKSTART.md). 