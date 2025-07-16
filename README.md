# Legos Finance Protocol 🧱

**Modular, Capital-Efficient Lending Protocol on Ethereum**

Legos Finance is a revolutionary DeFi lending protocol built with modular architecture, offering a Central Limit Order Book (CLOB) for transparent price discovery, over-collateralized lending, passive liquidity provision, and automated risk management.

## 🌟 Key Features

### 🔄 Central Limit Order Book (CLOB)
- **Real-time price discovery** through transparent order matching
- **Capital efficiency** with dynamic interest rates based on supply and demand
- **Order types**: Lending and borrowing orders with customizable parameters
- **Automated matching** between lenders and borrowers

### 🏦 Passive Liquidity Pools
- **Set-and-forget lending** for users who prefer passive strategies
- **Dynamic interest rate curves** based on utilization
- **Automatic order placement** on the CLOB
- **Pool tokens** representing shares in the lending pool

### ⚠️ Risk Management & Liquidation
- **Real-time health monitoring** of all loans
- **Automated liquidation** when positions become undercollateralized
- **Configurable risk parameters** per asset
- **Liquidator incentives** to maintain protocol health

### 🗳️ Decentralized Governance
- **DAO governance** with the LEGOS token
- **Timelock controller** for security
- **Parameter updates** through community voting
- **Asset listing** through governance proposals

### 🎯 Modular Architecture
Each component is a "Lego block" that can be upgraded or replaced independently:
- Core CLOB engine
- Lending pools
- Risk management
- Governance system

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Governance    │    │      CLOB       │    │   Risk Manager  │
│                 │    │                 │    │                 │
│ • Voting        │◄──►│ • Order Book    │◄──►│ • Health Check  │
│ • Parameters    │    │ • Matching      │    │ • Liquidation   │
│ • Asset Listing │    │ • Execution     │    │ • Price Feeds   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  LEGOS Token    │    │ Lending Pools   │    │   Libraries     │
│                 │    │                 │    │                 │
│ • Voting Power  │    │ • Auto-Lending  │    │ • Math Utils    │
│ • Staking       │    │ • Pool Tokens   │    │ • Interest Calc │
│ • Rewards       │    │ • Yield Farming │    │ • LTV Ratios    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📦 Project Structure

```
legos-finance/
├── contracts/
│   ├── core/                   # Core protocol contracts
│   │   ├── LegosCLOB.sol      # Central Limit Order Book
│   │   ├── LegosLendingPool.sol # Passive liquidity pools
│   │   └── LegosRiskManager.sol # Risk management & liquidation
│   ├── governance/             # Governance contracts
│   │   └── LegosGovernance.sol # DAO governance with timelock
│   ├── tokens/                 # Token contracts
│   │   └── LegosToken.sol     # Governance token with staking
│   ├── interfaces/             # Contract interfaces
│   │   └── ILegosCore.sol     # Core data structures
│   ├── libraries/              # Utility libraries
│   │   └── LegosMath.sol      # Mathematical calculations
│   └── test/                   # Test contracts
│       └── TestERC20.sol      # Mock ERC20 for testing
├── scripts/
│   └── deploy.js              # Deployment script
├── test/                      # Test files (to be created)
├── deployments/               # Deployment artifacts
├── hardhat.config.js         # Hardhat configuration
├── package.json              # Node.js dependencies
└── README.md                 # This file
```

## 🚀 Quick Start

### Prerequisites

- Node.js >= 16.0.0
- npm >= 8.0.0
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/legos-finance/legos-protocol.git
   cd legos-protocol
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Compile contracts**
   ```bash
   npm run compile
   ```

### Environment Configuration

Create a `.env` file with the following variables:

```bash
# Network RPC URLs
MAINNET_URL=https://eth-mainnet.alchemyapi.io/v2/your-api-key
SEPOLIA_URL=https://eth-sepolia.alchemyapi.io/v2/your-api-key

# Private key for deployment (without 0x prefix)
PRIVATE_KEY=your-private-key-here

# Etherscan API key for contract verification
ETHERSCAN_API_KEY=your-etherscan-api-key

# Optional: Enable gas reporting
REPORT_GAS=true
```

## 🎯 Deployment

### Local Development

1. **Start local Hardhat node**
   ```bash
   npm run node
   ```

2. **Deploy to local network**
   ```bash
   npm run deploy:local
   ```

### Testnet Deployment

1. **Deploy to Sepolia**
   ```bash
   npm run deploy:sepolia
   ```

2. **Verify contracts**
   ```bash
   npx hardhat verify --network sepolia <contract-address>
   ```

### Mainnet Deployment

```bash
npm run deploy:mainnet
```

## 💡 Usage Examples

### 1. Placing a Lending Order

```solidity
// Approve tokens first
IERC20(usdc).approve(clobAddress, amount);

// Place lending order
uint256 orderId = clob.placeLendOrder(
    usdc,                    // Asset to lend
    1000e6,                 // Amount (1000 USDC)
    800,                    // Interest rate (8% APY)
    30 days,                // Duration
    7500,                   // Max LTV (75%)
    weth,                   // Accepted collateral
    block.timestamp + 7 days // Expiry
);
```

### 2. Placing a Borrowing Order

```solidity
// Approve collateral first
IERC20(weth).approve(clobAddress, collateralAmount);

// Place borrowing order
uint256 orderId = clob.placeBorrowOrder(
    usdc,                    // Asset to borrow
    1000e6,                 // Amount to borrow
    900,                    // Max interest rate (9% APY)
    30 days,                // Duration
    weth,                   // Collateral token
    1 ether,                // Collateral amount (1.5x ratio)
    block.timestamp + 7 days // Expiry
);
```

### 3. Passive Liquidity Provision

```solidity
// Approve tokens for pool
IERC20(usdc).approve(poolAddress, amount);

// Deposit into lending pool
uint256 shares = pool.deposit(1000e6); // Deposit 1000 USDC

// Later: withdraw from pool
uint256 amount = pool.withdraw(shares);
```

### 4. Governance Participation

```solidity
// Stake tokens for voting power
legosToken.stake(100e18);

// Create a proposal
governance.proposeParameterUpdate(
    targetContract,
    encodedData,
    "Update Interest Rate Model",
    "Proposal to update base rate to 3%"
);

// Vote on proposal
governance.castVote(proposalId, 1); // 1 = For, 0 = Against
```

### 5. Risk Management

```solidity
// Check loan health
uint256 healthFactor = riskManager.calculateHealthFactor(loanId);

// Liquidate unhealthy loan
if (healthFactor < 1e18) {
    riskManager.liquidateLoan(loanId, debtToCover);
}
```

## 🧪 Testing

### Run Tests

```bash
npm test
```

### Coverage Report

```bash
npm run test:coverage
```

### Gas Analysis

```bash
npm run size
```

## 📊 Key Metrics & Parameters

### Interest Rate Model
- **Base Rate**: 2% APY
- **Optimal Utilization**: 80%
- **Slope 1**: 4% (below optimal)
- **Slope 2**: 100% (above optimal)

### Risk Parameters
| Asset | Max LTV | Liquidation Threshold | Liquidation Penalty |
|-------|---------|----------------------|-------------------|
| USDC  | 80%     | 85%                  | 5%                |
| WETH  | 75%     | 80%                  | 5%                |

### Governance Parameters
- **Voting Delay**: 1 day
- **Voting Period**: 1 week
- **Proposal Threshold**: 100 LEGOS tokens
- **Quorum**: 4% of total supply
- **Timelock Delay**: 2 days

## 🔒 Security Considerations

### Smart Contract Security
- **OpenZeppelin libraries** for battle-tested implementations
- **Reentrancy guards** on all external functions
- **Access control** with role-based permissions
- **Overflow protection** with Solidity 0.8.x

### Risk Management
- **Health factor monitoring** for all positions
- **Automated liquidations** to prevent bad debt
- **Price oracle integration** (simplified in this version)
- **Emergency pause mechanisms**

### Governance Security
- **Timelock controller** for delayed execution
- **Multi-signature support** for critical operations
- **Proposal validation** to prevent malicious proposals
- **Vote delegation** for secure participation

## 🛠️ Development

### Adding New Features

1. **Create new contract** in appropriate directory
2. **Add interface** in `interfaces/` if needed
3. **Update deployment script** to include new contract
4. **Write comprehensive tests**
5. **Update documentation**

### Code Style

- Follow Solidity style guide
- Use NatSpec documentation
- Run linter before committing: `npm run lint`
- Maintain test coverage above 80%

## 🗺️ Roadmap

### Phase 1: Core Protocol ✅
- [x] CLOB implementation
- [x] Basic lending pools
- [x] Risk management
- [x] Governance framework

### Phase 2: Advanced Features (Q2 2024)
- [ ] Flash loans
- [ ] Cross-chain support
- [ ] Advanced market making
- [ ] Insurance pools

### Phase 3: Ecosystem Growth (Q3 2024)
- [ ] Mobile app
- [ ] Institutional features
- [ ] Analytics dashboard
- [ ] API for integrations

### Phase 4: Scaling (Q4 2024)
- [ ] Layer 2 deployment
- [ ] MEV protection
- [ ] Advanced derivatives
- [ ] DAO treasury management

## 🤝 Contributing

We welcome contributions from the community! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Process
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Website**: https://legos.finance
- **Documentation**: https://docs.legos.finance
- **Twitter**: [@legosfinance](https://twitter.com/legosfinance)
- **Discord**: [Join our community](https://discord.gg/legosfinance)
- **Blog**: https://blog.legos.finance

## ⚠️ Disclaimer

This software is provided as-is and has not been audited. Use at your own risk. Always conduct thorough testing and auditing before deploying to mainnet.

## 🙏 Acknowledgments

- OpenZeppelin for secure contract templates
- Hardhat for development framework
- Ethereum community for inspiration
- All contributors and supporters

---

**Built with 🧱 by the Legos Finance Team** 