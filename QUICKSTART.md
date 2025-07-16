# ⚡ Legos Finance Quick Start

Get the complete Legos Finance protocol running locally in under 5 minutes!

## 🚀 One-Command Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd legos-finance

# Install everything and start the protocol
npm run setup
npm run start:all
```

This will:
1. Install all dependencies (backend + frontend)
2. Compile smart contracts
3. Start local blockchain
4. Deploy all contracts  
5. Start the frontend UI

## 🔗 Access Points

- **Frontend UI**: http://localhost:3000
- **Blockchain RPC**: http://localhost:8545
- **Chain ID**: 31337

## 📱 MetaMask Setup (2 minutes)

1. **Add Network**:
   - Network Name: `Legos Finance Local`
   - RPC URL: `http://localhost:8545`
   - Chain ID: `31337`
   - Currency: `ETH`

2. **Import Test Account**:
   - Copy any private key from the terminal output
   - MetaMask → Import Account → Private Key

3. **You're Ready!** 🎉
   - Visit http://localhost:3000
   - Click "Connect Wallet"
   - Start testing the protocol

## 🧪 Test Features

### Order Book (CLOB)
- Place lending orders with custom rates
- Create borrowing orders with collateral
- Watch automatic order matching

### Lending Pools  
- Deposit USDC/WETH to earn yield
- Withdraw anytime
- View real-time APY

### Risk Management
- Monitor loan health factors
- Track protocol risk metrics

### Governance
- Stake LEGOS tokens
- Participate in voting
- View governance parameters

## 🛠️ Development Commands

```bash
# Backend only
npm run node          # Start blockchain
npm run compile      # Compile contracts  
npm run deploy:local # Deploy contracts
npm run test         # Run tests

# Frontend only  
npm run frontend:start # Start React app
npm run frontend:build # Build for production

# Combined
npm run dev          # Start blockchain + frontend
```

## 📚 Full Documentation

For detailed setup and troubleshooting, see [LOCAL_SETUP.md](LOCAL_SETUP.md)

---

**Start building on Legos Finance! 🧱✨** 