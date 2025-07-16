import { ethers } from 'ethers';

// Contract ABIs (simplified for demo - in production, import full ABIs)
export const LEGOS_TOKEN_ABI = [
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function stake(uint256 amount)",
    "function unstake(uint256 amount)",
    "function getVotingPower(address account) view returns (uint256)",
    "function stakingInfo(address user) view returns (tuple(uint256,uint256,uint256,uint256))",
    "event Transfer(address indexed from, address indexed to, uint256 value)",
    "event Staked(address indexed user, uint256 amount)"
];

export const CLOB_ABI = [
    "function placeLendOrder(address asset, uint256 amount, uint256 interestRate, uint256 duration, uint256 maxLTV, address collateralToken, uint256 expiry) returns (uint256)",
    "function placeBorrowOrder(address asset, uint256 amount, uint256 interestRate, uint256 duration, address collateralToken, uint256 collateralAmount, uint256 expiry) returns (uint256)",
    "function cancelOrder(uint256 orderId)",
    "function getBestLendingRate(address asset) view returns (uint256)",
    "function getBestBorrowingRate(address asset) view returns (uint256)",
    "function getOrderBookDepth(address asset, bool isLend) view returns (uint256[], uint256[])",
    "function getUserOrders(address user) view returns (uint256[])",
    "function orders(uint256 orderId) view returns (tuple(uint256,address,uint8,uint8,uint256,uint256,uint256,uint256,uint256,address,uint256,uint256,uint256))",
    "event OrderPlaced(uint256 indexed orderId, address indexed user, uint8 orderType, uint256 amount)",
    "event OrderMatched(uint256 indexed lendOrderId, uint256 indexed borrowOrderId, uint256 amount)"
];

export const LENDING_POOL_ABI = [
    "function deposit(uint256 amount) returns (uint256)",
    "function withdraw(uint256 shares) returns (uint256)",
    "function balanceOf(address account) view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function getSupplyAPY() view returns (uint256)",
    "function getBorrowAPY() view returns (uint256)",
    "function getAvailableLiquidity() view returns (uint256)",
    "function getTotalPoolAssets() view returns (uint256)",
    "event Deposit(address indexed user, uint256 amount, uint256 shares)",
    "event Withdraw(address indexed user, uint256 amount, uint256 shares)"
];

export const RISK_MANAGER_ABI = [
    "function calculateHealthFactor(uint256 loanId) view returns (uint256)",
    "function isLiquidationEligible(uint256 loanId) view returns (bool)",
    "function getLoansAtRisk() view returns (uint256[])",
    "function getRiskMetrics() view returns (uint256, uint256, uint256)",
    "function assetPrices(address asset) view returns (uint256)",
    "function assetRiskParams(address asset) view returns (tuple(uint256,uint256,uint256,uint256,bool))"
];

export const ERC20_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "event Transfer(address indexed from, address indexed to, uint256 value)",
    "event Approval(address indexed owner, address indexed spender, uint256 value)"
];

// Default addresses for local development
// These will be updated when deployment files are available
export const DEFAULT_CONTRACTS = {
    legosToken: "0x9A676e781A523b5d0C0e43731313A708CB607508",
    clob: "0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE",
    usdcPool: "0x59b670e9fA9D0A427751Af201D676719a970857b",
    wethPool: "0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1",
    riskManager: "0x68B1D87F95878fE05B998F19b66F4baba5De1aed",
    governance: "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1",
    usdc: "0x3Aa5ebB10DC797CAC828524e59A333d0A371443c",
    weth: "0xc6e7DF5E7b4f2A278906862b61205850344D4e7d"
};

// Load contract addresses from deployment file if available
export const getContractAddresses = () => {
    try {
        // Try to load from deployment file
        const deployment = require('../../../deployments/localhost.json');
        return deployment.contracts;
    } catch (error) {
        console.warn('Could not load deployment file, using defaults:', error.message);
        return DEFAULT_CONTRACTS;
    }
};

// Helper to get contract instance
export const getContract = (addressOrName, abi, signerOrProvider) => {
    const addresses = getContractAddresses();
    const address = addresses[addressOrName] || addressOrName;
    return new ethers.Contract(address, abi, signerOrProvider);
};

// Network configuration
export const NETWORKS = {
    hardhat: {
        chainId: 31337,
        name: "Hardhat",
        rpcUrl: "http://localhost:8545",
        blockExplorer: null
    },
    localhost: {
        chainId: 31337,
        name: "Localhost",
        rpcUrl: "http://localhost:8545",
        blockExplorer: null
    }
};

// Helper functions
export const formatUnits = (value, decimals = 18) => {
    return ethers.formatUnits(value || 0, decimals);
};

export const parseUnits = (value, decimals = 18) => {
    return ethers.parseUnits(value.toString(), decimals);
};

export const formatAddress = (address) => {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

export const formatAPY = (rate) => {
    // Convert from basis points to percentage
    return (parseFloat(rate) / 100).toFixed(2);
};

export const formatCurrency = (amount, decimals = 18, symbol = '') => {
    const formatted = parseFloat(formatUnits(amount, decimals)).toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
    return symbol ? `${formatted} ${symbol}` : formatted;
}; 