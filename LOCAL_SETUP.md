# 🚀 Legos Finance Local Development Setup

This guide will help you run the complete Legos Finance protocol locally with a user interface for testing.

## 📋 Prerequisites

- **Node.js** >= 16.0.0
- **npm** >= 8.0.0  
- **Git**
- **MetaMask** browser extension

## 🔧 Step-by-Step Setup

### 1. Install Dependencies

First, install the backend dependencies:

```bash
# Install Hardhat and contract dependencies
npm install
```

Then install the frontend dependencies:

```bash
# Navigate to frontend directory
cd frontend

# Install React dependencies
npm install

# Return to root directory
cd ..
```

### 2. Compile Contracts

```bash
# Compile all smart contracts
npm run compile
```

### 3. Start Local Blockchain

In **Terminal 1**, start a local Hardhat node:

```bash
# Start local blockchain (keep this running)
npm run node
```

This will:
- Start a local Ethereum blockchain on `http://localhost:8545`
- Create 20 test accounts with 10,000 ETH each
- Display account addresses and private keys

### 4. Deploy Contracts

In **Terminal 2**, deploy the contracts to the local network:

```bash
# Deploy all Legos Finance contracts
npm run deploy:local
```

This will:
- Deploy all protocol contracts (CLOB, Pools, Risk Manager, Governance, Token)
- Set up initial configurations and risk parameters
- Create test USDC and WETH tokens
- Display contract addresses
- Save deployment info to `deployments/localhost.json`

### 5. Start Frontend

In **Terminal 3**, start the React frontend:

```bash
# Navigate to frontend and start development server
cd frontend
npm start
```

The frontend will be available at `http://localhost:3000`

### 6. Configure MetaMask

1. **Add Local Network**:
   - Network Name: `Localhost 8545`
   - New RPC URL: `http://localhost:8545`
   - Chain ID: `31337`
   - Currency Symbol: `ETH`

2. **Import Test Account**:
   - Copy a private key from Terminal 1 (Hardhat node output)
   - In MetaMask: Account menu → Import Account → Private Key
   - Paste the private key

3. **Add Test Tokens**:
   - Get USDC address from deployment output
   - In MetaMask: Assets → Import Tokens → Custom Token
   - Add USDC (6 decimals) and WETH (18 decimals)

## 🎯 Testing the Protocol

### Get Test Tokens

The deployment script gives you initial tokens, but you can mint more:

```bash
# In Hardhat console (Terminal 4)
npx hardhat console --network localhost

# Mint test USDC
const usdc = await ethers.getContractAt("TestERC20", "USDC_ADDRESS_FROM_DEPLOYMENT");
await usdc.mint("YOUR_WALLET_ADDRESS", ethers.parseUnits("10000", 6));

# Mint test WETH  
const weth = await ethers.getContractAt("TestERC20", "WETH_ADDRESS_FROM_DEPLOYMENT");
await weth.mint("YOUR_WALLET_ADDRESS", ethers.parseEther("100"));
```

### Test Protocol Features

1. **Connect Wallet**: Click "Connect Wallet" and approve MetaMask connection

2. **View Protocol Stats**: See your balances and protocol metrics

3. **Test Order Book**:
   - Place a lending order (lend USDC, accept WETH collateral)
   - Place a borrowing order (borrow USDC, provide WETH collateral)
   - Watch orders match automatically

4. **Test Lending Pools**:
   - Deposit USDC/WETH into pools
   - Earn APY automatically
   - Withdraw anytime

5. **Test Governance**:
   - Stake LEGOS tokens
   - View voting power
   - Participate in protocol decisions

## 🛠️ Development Workflow

### Making Changes

**Smart Contracts**:
```bash
# After modifying contracts
npm run compile

# Redeploy (will reset all data)
npm run deploy:local
```

**Frontend**:
```bash
# Changes auto-reload with hot-reloading
# No restart needed for most changes
```

### Running Tests

```bash
# Run contract tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test
npx hardhat test test/LegosProtocol.test.js
```

### Debugging

**Check Contract Events**:
```bash
# Monitor blockchain logs
npx hardhat node --verbose
```

**Frontend Console**:
- Open browser developer tools
- Check console for errors and transaction logs
- Contract interactions are logged

## 📱 UI Features

### Dashboard
- **Protocol Overview**: Total liquidity, APYs, risk metrics
- **Your Balances**: USDC, WETH, LEGOS, pool shares
- **Real-time Updates**: Automatic refresh on transactions

### Order Book
- **Place Orders**: Lending and borrowing with custom rates
- **View Depth**: See all active orders by rate
- **Order Management**: Cancel or modify your orders
- **Auto-matching**: Orders match automatically when rates align

### Lending Pools
- **Deposit/Withdraw**: Simple pool interactions
- **APY Display**: Real-time yield calculations
- **Pool Analytics**: Utilization, your share, estimated earnings

### Risk Dashboard
- **Health Monitoring**: View loan health factors
- **Risk Metrics**: Protocol-wide risk assessment
- **Liquidation Status**: Track at-risk positions

### Governance
- **Token Staking**: Stake LEGOS for voting power
- **Governance Stats**: Your voting power and proposal thresholds
- **Protocol Parameters**: View current governance settings

## 🚨 Troubleshooting

### Common Issues

**MetaMask Issues**:
```bash
# Reset MetaMask account (Settings → Advanced → Reset Account)
# This clears transaction history for the local network
```

**Contract Address Errors**:
```bash
# Check deployment file
cat deployments/localhost.json

# Update frontend config if needed
# Edit frontend/src/config/contracts.js
```

**Transaction Failures**:
- Check you have enough gas (ETH)
- Verify token allowances
- Ensure contracts are deployed correctly

**Frontend Not Loading Contract Data**:
- Check browser console for errors
- Verify MetaMask is connected to localhost:8545
- Ensure contracts are deployed

### Reset Everything

```bash
# Stop all processes (Ctrl+C in all terminals)

# Clean and restart
npm run clean
rm -rf deployments/localhost.json
rm -rf cache/ artifacts/

# Restart from step 2
npm run compile
# ... continue with deployment
```

## 🎉 Success Checklist

- [ ] Local blockchain running on port 8545
- [ ] All contracts deployed successfully  
- [ ] Frontend running on port 3000
- [ ] MetaMask connected to local network
- [ ] Test tokens visible in wallet
- [ ] Can place orders and see them in UI
- [ ] Can deposit/withdraw from pools
- [ ] Protocol stats updating correctly

## 📚 Additional Resources

- **Hardhat Docs**: https://hardhat.org/docs
- **React Docs**: https://reactjs.org/docs
- **MetaMask Docs**: https://docs.metamask.io/
- **Ethers.js Docs**: https://docs.ethers.org/

## 🤝 Need Help?

If you encounter issues:

1. Check the console logs in both terminal and browser
2. Verify all prerequisites are installed correctly
3. Ensure you're using the correct node/npm versions
4. Try the reset procedure above

---

**Happy Testing! 🧱✨**

The modular Legos Finance protocol is now running locally with a full UI for comprehensive testing of all DeFi features. 