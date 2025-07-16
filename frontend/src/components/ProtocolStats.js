import React from 'react';
import { RefreshCw, DollarSign, TrendingUp, Users, Shield } from 'lucide-react';
import { formatCurrency, formatAPY, formatUnits } from '../config/contracts';

const ProtocolStats = ({ balances, protocolData, onRefresh }) => {
    const stats = [
        {
            title: 'USDC Balance',
            value: balances.usdc ? formatCurrency(balances.usdc, 6, 'USDC') : '0.00 USDC',
            icon: DollarSign,
            color: 'text-blue-600',
            bgColor: 'bg-blue-50'
        },
        {
            title: 'WETH Balance',
            value: balances.weth ? formatCurrency(balances.weth, 18, 'WETH') : '0.00 WETH',
            icon: DollarSign,
            color: 'text-purple-600',
            bgColor: 'bg-purple-50'
        },
        {
            title: 'LEGOS Balance',
            value: balances.legos ? formatCurrency(balances.legos, 18, 'LEGOS') : '0.00 LEGOS',
            icon: TrendingUp,
            color: 'text-green-600',
            bgColor: 'bg-green-50'
        },
        {
            title: 'Pool Shares',
            value: balances.usdcPool && balances.wethPool ?
                `${formatCurrency(balances.usdcPool, 18)} + ${formatCurrency(balances.wethPool, 18)}` :
                '0.00',
            icon: Users,
            color: 'text-indigo-600',
            bgColor: 'bg-indigo-50'
        }
    ];

    const protocolStats = [
        {
            title: 'USDC Supply APY',
            value: protocolData.usdcSupplyAPY ? `${formatAPY(protocolData.usdcSupplyAPY)}%` : '0.00%',
            subtitle: 'Annual Percentage Yield'
        },
        {
            title: 'WETH Supply APY',
            value: protocolData.wethSupplyAPY ? `${formatAPY(protocolData.wethSupplyAPY)}%` : '0.00%',
            subtitle: 'Annual Percentage Yield'
        },
        {
            title: 'Total Loans',
            value: protocolData.totalLoans ? protocolData.totalLoans.toString() : '0',
            subtitle: 'Active loan positions'
        },
        {
            title: 'Loans at Risk',
            value: protocolData.loansAtRisk ? protocolData.loansAtRisk.toString() : '0',
            subtitle: 'Health factor < 1.2'
        }
    ];

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex justify-between items-center">
                <h2 className="text-2xl font-bold text-gray-900">Protocol Overview</h2>
                <button
                    onClick={onRefresh}
                    className="btn-secondary flex items-center space-x-2"
                >
                    <RefreshCw className="h-4 w-4" />
                    <span>Refresh</span>
                </button>
            </div>

            {/* User Balances */}
            <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-4">Your Balances</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    {stats.map((stat, index) => {
                        const Icon = stat.icon;
                        return (
                            <div key={index} className="card">
                                <div className="flex items-center">
                                    <div className={`${stat.bgColor} ${stat.color} p-3 rounded-lg`}>
                                        <Icon className="h-6 w-6" />
                                    </div>
                                    <div className="ml-4 flex-1">
                                        <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                                        <p className="text-lg font-semibold text-gray-900">{stat.value}</p>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>

            {/* Protocol Metrics */}
            <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-4">Protocol Metrics</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    {protocolStats.map((stat, index) => (
                        <div key={index} className="stat-card">
                            <div className="text-center">
                                <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
                                <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                                <p className="text-xs text-gray-500 mt-1">{stat.subtitle}</p>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Liquidity Overview */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* USDC Pool */}
                <div className="card">
                    <h4 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                        <DollarSign className="h-5 w-5 text-blue-600 mr-2" />
                        USDC Pool
                    </h4>
                    <div className="space-y-3">
                        <div className="flex justify-between">
                            <span className="text-gray-600">Supply APY</span>
                            <span className="font-semibold text-green-600">
                                {protocolData.usdcSupplyAPY ? `${formatAPY(protocolData.usdcSupplyAPY)}%` : '0.00%'}
                            </span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-gray-600">Borrow APY</span>
                            <span className="font-semibold text-red-600">
                                {protocolData.usdcBorrowAPY ? `${formatAPY(protocolData.usdcBorrowAPY)}%` : '0.00%'}
                            </span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-gray-600">Available Liquidity</span>
                            <span className="font-semibold">
                                {protocolData.usdcLiquidity ? formatCurrency(protocolData.usdcLiquidity, 6, 'USDC') : '0.00 USDC'}
                            </span>
                        </div>
                        {balances.usdcPool && (
                            <div className="flex justify-between pt-2 border-t">
                                <span className="text-gray-600">Your Pool Shares</span>
                                <span className="font-semibold text-blue-600">
                                    {formatCurrency(balances.usdcPool, 18)}
                                </span>
                            </div>
                        )}
                    </div>
                </div>

                {/* WETH Pool */}
                <div className="card">
                    <h4 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                        <div className="w-5 h-5 bg-purple-600 rounded-full mr-2"></div>
                        WETH Pool
                    </h4>
                    <div className="space-y-3">
                        <div className="flex justify-between">
                            <span className="text-gray-600">Supply APY</span>
                            <span className="font-semibold text-green-600">
                                {protocolData.wethSupplyAPY ? `${formatAPY(protocolData.wethSupplyAPY)}%` : '0.00%'}
                            </span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-gray-600">Borrow APY</span>
                            <span className="font-semibold text-red-600">
                                {protocolData.wethBorrowAPY ? `${formatAPY(protocolData.wethBorrowAPY)}%` : '0.00%'}
                            </span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-gray-600">Available Liquidity</span>
                            <span className="font-semibold">
                                {protocolData.wethLiquidity ? formatCurrency(protocolData.wethLiquidity, 18, 'WETH') : '0.00 WETH'}
                            </span>
                        </div>
                        {balances.wethPool && (
                            <div className="flex justify-between pt-2 border-t">
                                <span className="text-gray-600">Your Pool Shares</span>
                                <span className="font-semibold text-purple-600">
                                    {formatCurrency(balances.wethPool, 18)}
                                </span>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Risk Overview */}
            {protocolData.totalLoans > 0 && (
                <div className="card">
                    <h4 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                        <Shield className="h-5 w-5 text-yellow-600 mr-2" />
                        Risk Overview
                    </h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="text-center">
                            <p className="text-2xl font-bold text-gray-900">{protocolData.totalLoans}</p>
                            <p className="text-sm text-gray-600">Total Active Loans</p>
                        </div>
                        <div className="text-center">
                            <p className="text-2xl font-bold text-yellow-600">{protocolData.loansAtRisk}</p>
                            <p className="text-sm text-gray-600">Loans at Risk</p>
                        </div>
                        <div className="text-center">
                            <p className="text-2xl font-bold text-green-600">
                                {protocolData.avgHealthFactor ? formatUnits(protocolData.avgHealthFactor, 18) : '0.00'}
                            </p>
                            <p className="text-sm text-gray-600">Avg Health Factor</p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default ProtocolStats; 