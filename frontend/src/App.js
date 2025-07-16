import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import toast, { Toaster } from 'react-hot-toast';
import {
    Wallet,
    TrendingUp,
    Shield,
    BarChart3,
    Vote,
    Coins,
    ArrowUpDown,
    AlertTriangle,
    Zap
} from 'lucide-react';
import './index.css';

import {
    getContract,
    getContractAddresses,
    LEGOS_TOKEN_ABI,
    CLOB_ABI,
    LENDING_POOL_ABI,
    RISK_MANAGER_ABI,
    ERC20_ABI,
    formatUnits,
    parseUnits,
    formatAddress,
    formatAPY,
    formatCurrency
} from './config/contracts';

// Components
import WalletConnection from './components/WalletConnection';
import ProtocolStats from './components/ProtocolStats';
import OrderBook from './components/OrderBook';
import LendingPools from './components/LendingPools';
import RiskDashboard from './components/RiskDashboard';
import GovernancePanel from './components/GovernancePanel';

function App() {
    const [provider, setProvider] = useState(null);
    const [signer, setSigner] = useState(null);
    const [account, setAccount] = useState('');
    const [network, setNetwork] = useState(null);
    const [loading, setLoading] = useState(false);
    const [activeTab, setActiveTab] = useState('orderbook');
    const [contracts, setContracts] = useState({});
    const [balances, setBalances] = useState({});
    const [protocolData, setProtocolData] = useState({});

    // Initialize provider and contracts
    useEffect(() => {
        initializeProvider();
    }, []);

    // Load user data when account changes
    useEffect(() => {
        if (account && signer) {
            loadUserData();
            loadProtocolData();
        }
    }, [account, signer]);

    const initializeProvider = async () => {
        try {
            if (window.ethereum) {
                const provider = new ethers.BrowserProvider(window.ethereum);
                setProvider(provider);

                // Listen for account changes
                window.ethereum.on('accountsChanged', handleAccountsChanged);
                window.ethereum.on('chainChanged', handleChainChanged);

                // Try to connect if already authorized
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                if (accounts.length > 0) {
                    await connectWallet();
                }
            } else {
                toast.error('Please install MetaMask!');
            }
        } catch (error) {
            console.error('Error initializing provider:', error);
            toast.error('Failed to initialize wallet connection');
        }
    };

    const connectWallet = async () => {
        try {
            setLoading(true);

            const accounts = await window.ethereum.request({
                method: 'eth_requestAccounts',
            });

            const signer = await provider.getSigner();
            const network = await provider.getNetwork();

            setAccount(accounts[0]);
            setSigner(signer);
            setNetwork(network);

            // Initialize contracts
            const addresses = getContractAddresses();
            const contractInstances = {
                legosToken: getContract('legosToken', LEGOS_TOKEN_ABI, signer),
                clob: getContract('clob', CLOB_ABI, signer),
                usdcPool: getContract('usdcPool', LENDING_POOL_ABI, signer),
                wethPool: getContract('wethPool', LENDING_POOL_ABI, signer),
                riskManager: getContract('riskManager', RISK_MANAGER_ABI, signer),
                usdc: getContract('usdc', ERC20_ABI, signer),
                weth: getContract('weth', ERC20_ABI, signer)
            };

            setContracts(contractInstances);

            toast.success(`Connected to ${formatAddress(accounts[0])}`);
        } catch (error) {
            console.error('Error connecting wallet:', error);
            toast.error('Failed to connect wallet');
        } finally {
            setLoading(false);
        }
    };

    const loadUserData = async () => {
        try {
            if (!contracts.usdc || !contracts.weth || !contracts.legosToken) return;

            const [
                usdcBalance,
                wethBalance,
                legosBalance,
                usdcPoolShares,
                wethPoolShares
            ] = await Promise.all([
                contracts.usdc.balanceOf(account),
                contracts.weth.balanceOf(account),
                contracts.legosToken.balanceOf(account),
                contracts.usdcPool.balanceOf(account),
                contracts.wethPool.balanceOf(account)
            ]);

            setBalances({
                usdc: usdcBalance,
                weth: wethBalance,
                legos: legosBalance,
                usdcPool: usdcPoolShares,
                wethPool: wethPoolShares
            });
        } catch (error) {
            console.error('Error loading user data:', error);
        }
    };

    const loadProtocolData = async () => {
        try {
            if (!contracts.usdcPool || !contracts.wethPool || !contracts.riskManager) return;

            const [
                usdcSupplyAPY,
                usdcBorrowAPY,
                wethSupplyAPY,
                wethBorrowAPY,
                usdcLiquidity,
                wethLiquidity,
                riskMetrics
            ] = await Promise.all([
                contracts.usdcPool.getSupplyAPY().catch(() => 0),
                contracts.usdcPool.getBorrowAPY().catch(() => 0),
                contracts.wethPool.getSupplyAPY().catch(() => 0),
                contracts.wethPool.getBorrowAPY().catch(() => 0),
                contracts.usdcPool.getAvailableLiquidity().catch(() => 0),
                contracts.wethPool.getAvailableLiquidity().catch(() => 0),
                contracts.riskManager.getRiskMetrics().catch(() => [0, 0, 0])
            ]);

            setProtocolData({
                usdcSupplyAPY,
                usdcBorrowAPY,
                wethSupplyAPY,
                wethBorrowAPY,
                usdcLiquidity,
                wethLiquidity,
                totalLoans: riskMetrics[0],
                loansAtRisk: riskMetrics[1],
                avgHealthFactor: riskMetrics[2]
            });
        } catch (error) {
            console.error('Error loading protocol data:', error);
        }
    };

    const handleAccountsChanged = (accounts) => {
        if (accounts.length === 0) {
            setAccount('');
            setSigner(null);
            setContracts({});
            setBalances({});
        } else {
            setAccount(accounts[0]);
            connectWallet();
        }
    };

    const handleChainChanged = () => {
        window.location.reload();
    };

    const disconnectWallet = () => {
        setAccount('');
        setSigner(null);
        setContracts({});
        setBalances({});
        setProtocolData({});
        toast.success('Wallet disconnected');
    };

    const tabs = [
        { id: 'orderbook', name: 'Order Book', icon: BarChart3 },
        { id: 'pools', name: 'Lending Pools', icon: TrendingUp },
        { id: 'risk', name: 'Risk Dashboard', icon: Shield },
        { id: 'governance', name: 'Governance', icon: Vote }
    ];

    return (
        <div className="min-h-screen bg-gray-50">
            <Toaster position="top-right" />

            {/* Header */}
            <header className="bg-white shadow-sm border-b">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between items-center h-16">
                        <div className="flex items-center">
                            <div className="flex items-center space-x-2">
                                <Zap className="h-8 w-8 text-primary-600" />
                                <h1 className="text-2xl font-bold text-gray-900">Legos Finance</h1>
                            </div>
                            <span className="ml-2 text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded">
                                Testnet
                            </span>
                        </div>

                        <WalletConnection
                            account={account}
                            network={network}
                            onConnect={connectWallet}
                            onDisconnect={disconnectWallet}
                            loading={loading}
                        />
                    </div>
                </div>
            </header>

            {/* Main Content */}
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                {account ? (
                    <>
                        {/* Protocol Stats */}
                        <ProtocolStats
                            balances={balances}
                            protocolData={protocolData}
                            onRefresh={() => {
                                loadUserData();
                                loadProtocolData();
                            }}
                        />

                        {/* Navigation Tabs */}
                        <div className="mt-8">
                            <div className="border-b border-gray-200">
                                <nav className="-mb-px flex space-x-8">
                                    {tabs.map((tab) => {
                                        const Icon = tab.icon;
                                        return (
                                            <button
                                                key={tab.id}
                                                onClick={() => setActiveTab(tab.id)}
                                                className={`${activeTab === tab.id
                                                        ? 'border-primary-500 text-primary-600'
                                                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                                                    } whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm flex items-center space-x-2`}
                                            >
                                                <Icon className="h-4 w-4" />
                                                <span>{tab.name}</span>
                                            </button>
                                        );
                                    })}
                                </nav>
                            </div>
                        </div>

                        {/* Tab Content */}
                        <div className="mt-8">
                            {activeTab === 'orderbook' && (
                                <OrderBook
                                    contracts={contracts}
                                    account={account}
                                    onOrderPlaced={() => {
                                        loadUserData();
                                        loadProtocolData();
                                    }}
                                />
                            )}

                            {activeTab === 'pools' && (
                                <LendingPools
                                    contracts={contracts}
                                    balances={balances}
                                    protocolData={protocolData}
                                    onTransaction={() => {
                                        loadUserData();
                                        loadProtocolData();
                                    }}
                                />
                            )}

                            {activeTab === 'risk' && (
                                <RiskDashboard
                                    contracts={contracts}
                                    protocolData={protocolData}
                                />
                            )}

                            {activeTab === 'governance' && (
                                <GovernancePanel
                                    contracts={contracts}
                                    account={account}
                                    balances={balances}
                                />
                            )}
                        </div>
                    </>
                ) : (
                    /* Welcome Screen */
                    <div className="text-center py-16">
                        <Zap className="mx-auto h-16 w-16 text-primary-600 mb-4" />
                        <h2 className="text-3xl font-bold text-gray-900 mb-4">
                            Welcome to Legos Finance
                        </h2>
                        <p className="text-lg text-gray-600 mb-8 max-w-2xl mx-auto">
                            A modular, capital-efficient lending protocol with transparent price discovery
                            through our Central Limit Order Book (CLOB) system.
                        </p>

                        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto mb-8">
                            <div className="card text-center">
                                <BarChart3 className="h-8 w-8 text-primary-600 mx-auto mb-2" />
                                <h3 className="font-semibold text-gray-900 mb-1">Order Book</h3>
                                <p className="text-sm text-gray-600">
                                    Place lending and borrowing orders with transparent price discovery
                                </p>
                            </div>

                            <div className="card text-center">
                                <TrendingUp className="h-8 w-8 text-secondary-600 mx-auto mb-2" />
                                <h3 className="font-semibold text-gray-900 mb-1">Lending Pools</h3>
                                <p className="text-sm text-gray-600">
                                    Passive liquidity provision with dynamic interest rates
                                </p>
                            </div>

                            <div className="card text-center">
                                <Shield className="h-8 w-8 text-yellow-600 mx-auto mb-2" />
                                <h3 className="font-semibold text-gray-900 mb-1">Risk Management</h3>
                                <p className="text-sm text-gray-600">
                                    Real-time monitoring and automated liquidation protection
                                </p>
                            </div>
                        </div>

                        <button
                            onClick={connectWallet}
                            disabled={loading}
                            className="btn-primary text-lg px-8 py-3"
                        >
                            {loading ? (
                                <span className="loading-dots">Connecting</span>
                            ) : (
                                <>
                                    <Wallet className="inline h-5 w-5 mr-2" />
                                    Connect Wallet to Start
                                </>
                            )}
                        </button>
                    </div>
                )}
            </main>
        </div>
    );
}

export default App; 