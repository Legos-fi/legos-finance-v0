import React, { useState } from 'react';
import { PlusCircle, MinusCircle, TrendingUp } from 'lucide-react';
import toast from 'react-hot-toast';
import { parseUnits, formatCurrency, formatAPY } from '../config/contracts';

const LendingPools = ({ contracts, balances, protocolData, onTransaction }) => {
    const [activePool, setActivePool] = useState('usdc');
    const [action, setAction] = useState('deposit');
    const [amount, setAmount] = useState('');
    const [loading, setLoading] = useState(false);

    const pools = [
        {
            id: 'usdc',
            name: 'USDC Pool',
            asset: 'USDC',
            decimals: 6,
            contract: contracts.usdcPool,
            token: contracts.usdc,
            balance: balances.usdc,
            poolShares: balances.usdcPool,
            supplyAPY: protocolData.usdcSupplyAPY,
            liquidity: protocolData.usdcLiquidity,
            color: 'blue'
        },
        {
            id: 'weth',
            name: 'WETH Pool',
            asset: 'WETH',
            decimals: 18,
            contract: contracts.wethPool,
            token: contracts.weth,
            balance: balances.weth,
            poolShares: balances.wethPool,
            supplyAPY: protocolData.wethSupplyAPY,
            liquidity: protocolData.wethLiquidity,
            color: 'purple'
        }
    ];

    const currentPool = pools.find(p => p.id === activePool);

    const handleTransaction = async () => {
        if (!amount || !currentPool) {
            toast.error('Please enter an amount');
            return;
        }

        setLoading(true);

        try {
            if (action === 'deposit') {
                const depositAmount = parseUnits(amount, currentPool.decimals);

                // Approve tokens
                await currentPool.token.approve(
                    await currentPool.contract.getAddress(),
                    depositAmount
                );

                // Deposit
                const tx = await currentPool.contract.deposit(depositAmount);
                await tx.wait();

                toast.success('Deposit successful!');
            } else {
                // Withdraw - amount is in pool shares
                const withdrawShares = parseUnits(amount, 18); // Pool shares are always 18 decimals

                const tx = await currentPool.contract.withdraw(withdrawShares);
                await tx.wait();

                toast.success('Withdrawal successful!');
            }

            setAmount('');
            onTransaction();
        } catch (error) {
            console.error('Transaction error:', error);
            toast.error(error.message || 'Transaction failed');
        } finally {
            setLoading(false);
        }
    };

    const getMaxAmount = () => {
        if (action === 'deposit') {
            return currentPool?.balance ? formatCurrency(currentPool.balance, currentPool.decimals, '') : '0';
        } else {
            return currentPool?.poolShares ? formatCurrency(currentPool.poolShares, 18, '') : '0';
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <h2 className="text-2xl font-bold text-gray-900">Lending Pools</h2>
                <div className="flex space-x-2">
                    <button
                        onClick={() => setAction('deposit')}
                        className={`px-4 py-2 rounded-lg ${action === 'deposit'
                                ? 'bg-green-600 text-white'
                                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                            }`}
                    >
                        Deposit
                    </button>
                    <button
                        onClick={() => setAction('withdraw')}
                        className={`px-4 py-2 rounded-lg ${action === 'withdraw'
                                ? 'bg-red-600 text-white'
                                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                            }`}
                    >
                        Withdraw
                    </button>
                </div>
            </div>

            {/* Pool Selection */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {pools.map((pool) => (
                    <div
                        key={pool.id}
                        onClick={() => setActivePool(pool.id)}
                        className={`card cursor-pointer transition-all ${activePool === pool.id
                                ? `ring-2 ring-${pool.color}-500 bg-${pool.color}-50`
                                : 'hover:shadow-lg'
                            }`}
                    >
                        <div className="flex justify-between items-start mb-4">
                            <h3 className="text-lg font-semibold">{pool.name}</h3>
                            <span className={`px-2 py-1 text-xs font-semibold rounded-full bg-${pool.color}-100 text-${pool.color}-800`}>
                                {pool.asset}
                            </span>
                        </div>

                        <div className="space-y-3">
                            <div className="flex justify-between">
                                <span className="text-gray-600">Supply APY</span>
                                <span className="font-semibold text-green-600">
                                    {pool.supplyAPY ? formatAPY(pool.supplyAPY) : '0.00'}%
                                </span>
                            </div>

                            <div className="flex justify-between">
                                <span className="text-gray-600">Available Liquidity</span>
                                <span className="font-semibold">
                                    {pool.liquidity ? formatCurrency(pool.liquidity, pool.decimals, pool.asset) : `0.00 ${pool.asset}`}
                                </span>
                            </div>

                            <div className="flex justify-between">
                                <span className="text-gray-600">Your Balance</span>
                                <span className="font-semibold">
                                    {pool.balance ? formatCurrency(pool.balance, pool.decimals, pool.asset) : `0.00 ${pool.asset}`}
                                </span>
                            </div>

                            {pool.poolShares && parseFloat(formatCurrency(pool.poolShares, 18, '')) > 0 && (
                                <div className="flex justify-between pt-2 border-t">
                                    <span className="text-gray-600">Your Pool Shares</span>
                                    <span className={`font-semibold text-${pool.color}-600`}>
                                        {formatCurrency(pool.poolShares, 18)}
                                    </span>
                                </div>
                            )}
                        </div>
                    </div>
                ))}
            </div>

            {/* Transaction Form */}
            {currentPool && (
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4">
                        {action === 'deposit' ? 'Deposit to' : 'Withdraw from'} {currentPool.name}
                    </h3>

                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Amount {action === 'withdraw' ? '(Pool Shares)' : `(${currentPool.asset})`}
                            </label>

                            <div className="relative">
                                <input
                                    type="number"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="input-field w-full pr-20"
                                    placeholder="0.0"
                                    step="0.01"
                                />

                                <button
                                    onClick={() => setAmount(getMaxAmount())}
                                    className="absolute right-2 top-1/2 transform -translate-y-1/2 text-sm text-blue-600 hover:text-blue-800"
                                >
                                    MAX
                                </button>
                            </div>

                            <p className="text-sm text-gray-500 mt-1">
                                Available: {getMaxAmount()} {action === 'withdraw' ? 'shares' : currentPool.asset}
                            </p>
                        </div>

                        {action === 'deposit' && (
                            <div className="bg-green-50 p-4 rounded-lg">
                                <h4 className="text-sm font-medium text-green-800 mb-2">Deposit Benefits</h4>
                                <ul className="text-sm text-green-700 space-y-1">
                                    <li>• Earn {currentPool.supplyAPY ? formatAPY(currentPool.supplyAPY) : '0.00'}% APY</li>
                                    <li>• Automatic compounding</li>
                                    <li>• Withdraw anytime</li>
                                    <li>• Pool tokens are transferable</li>
                                </ul>
                            </div>
                        )}

                        <button
                            onClick={handleTransaction}
                            disabled={loading || !amount}
                            className={`w-full ${action === 'deposit' ? 'btn-primary' : 'bg-red-600 hover:bg-red-700 text-white'
                                } font-semibold py-2 px-4 rounded-lg transition-colors duration-200 disabled:opacity-50`}
                        >
                            {loading ? (
                                <span className="loading-dots">
                                    {action === 'deposit' ? 'Depositing' : 'Withdrawing'}
                                </span>
                            ) : (
                                <>
                                    {action === 'deposit' ? (
                                        <PlusCircle className="inline h-4 w-4 mr-2" />
                                    ) : (
                                        <MinusCircle className="inline h-4 w-4 mr-2" />
                                    )}
                                    {action === 'deposit' ? 'Deposit' : 'Withdraw'}
                                </>
                            )}
                        </button>
                    </div>
                </div>
            )}

            {/* Pool Statistics */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {pools.map((pool) => (
                    <div key={pool.id} className="card">
                        <h4 className="text-lg font-semibold mb-4 flex items-center">
                            <TrendingUp className={`h-5 w-5 text-${pool.color}-600 mr-2`} />
                            {pool.name} Analytics
                        </h4>

                        <div className="space-y-3">
                            <div className="flex justify-between">
                                <span className="text-gray-600">Current APY</span>
                                <span className="font-semibold text-green-600">
                                    {pool.supplyAPY ? formatAPY(pool.supplyAPY) : '0.00'}%
                                </span>
                            </div>

                            <div className="flex justify-between">
                                <span className="text-gray-600">Total Liquidity</span>
                                <span className="font-semibold">
                                    {pool.liquidity ? formatCurrency(pool.liquidity, pool.decimals, pool.asset) : `0.00 ${pool.asset}`}
                                </span>
                            </div>

                            {pool.poolShares && parseFloat(formatCurrency(pool.poolShares, 18, '')) > 0 && (
                                <>
                                    <div className="flex justify-between">
                                        <span className="text-gray-600">Your Contribution</span>
                                        <span className={`font-semibold text-${pool.color}-600`}>
                                            {formatCurrency(pool.poolShares, 18)} shares
                                        </span>
                                    </div>

                                    <div className="flex justify-between pt-2 border-t">
                                        <span className="text-gray-600">Estimated Earnings</span>
                                        <span className="font-semibold text-green-600">
                                            {pool.supplyAPY ?
                                                `~${(parseFloat(formatCurrency(pool.poolShares, 18, '')) * parseFloat(formatAPY(pool.supplyAPY)) / 100).toFixed(4)} ${pool.asset}/year` :
                                                '0.00'
                                            }
                                        </span>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default LendingPools; 