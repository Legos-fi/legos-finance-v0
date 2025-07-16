import React, { useState } from 'react';
import { Vote, Users, Coins, Lock } from 'lucide-react';
import toast from 'react-hot-toast';
import { parseUnits, formatCurrency } from '../config/contracts';

const GovernancePanel = ({ contracts, account, balances }) => {
    const [stakeAmount, setStakeAmount] = useState('');
    const [loading, setLoading] = useState(false);

    const handleStake = async () => {
        if (!stakeAmount || !contracts.legosToken) {
            toast.error('Please enter a stake amount');
            return;
        }

        setLoading(true);

        try {
            const amount = parseUnits(stakeAmount, 18);
            const tx = await contracts.legosToken.stake(amount);
            await tx.wait();

            toast.success('Tokens staked successfully!');
            setStakeAmount('');
        } catch (error) {
            console.error('Staking error:', error);
            toast.error(error.message || 'Staking failed');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="space-y-6">
            <h2 className="text-2xl font-bold text-gray-900">Governance</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Token Staking */}
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4 flex items-center">
                        <Lock className="h-5 w-5 text-blue-600 mr-2" />
                        Stake LEGOS Tokens
                    </h3>

                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Amount to Stake
                            </label>
                            <input
                                type="number"
                                value={stakeAmount}
                                onChange={(e) => setStakeAmount(e.target.value)}
                                className="input-field w-full"
                                placeholder="0.0"
                                step="0.01"
                            />
                            <p className="text-sm text-gray-500 mt-1">
                                Available: {balances.legos ? formatCurrency(balances.legos, 18, 'LEGOS') : '0.00 LEGOS'}
                            </p>
                        </div>

                        <button
                            onClick={handleStake}
                            disabled={loading || !stakeAmount}
                            className="btn-primary w-full"
                        >
                            {loading ? (
                                <span className="loading-dots">Staking</span>
                            ) : (
                                <>
                                    <Coins className="inline h-4 w-4 mr-2" />
                                    Stake Tokens
                                </>
                            )}
                        </button>
                    </div>

                    <div className="mt-6 p-4 bg-blue-50 rounded-lg">
                        <h4 className="text-sm font-medium text-blue-800 mb-2">Staking Benefits</h4>
                        <ul className="text-sm text-blue-700 space-y-1">
                            <li>• Increased voting power</li>
                            <li>• Earn staking rewards</li>
                            <li>• Participate in governance</li>
                            <li>• Protocol fee sharing</li>
                        </ul>
                    </div>
                </div>

                {/* Governance Stats */}
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4 flex items-center">
                        <Vote className="h-5 w-5 text-green-600 mr-2" />
                        Your Governance Power
                    </h3>

                    <div className="space-y-4">
                        <div className="flex justify-between">
                            <span className="text-gray-600">LEGOS Balance</span>
                            <span className="font-semibold">
                                {balances.legos ? formatCurrency(balances.legos, 18, 'LEGOS') : '0.00 LEGOS'}
                            </span>
                        </div>

                        <div className="flex justify-between">
                            <span className="text-gray-600">Staked Amount</span>
                            <span className="font-semibold text-blue-600">
                                0.00 LEGOS
                            </span>
                        </div>

                        <div className="flex justify-between">
                            <span className="text-gray-600">Voting Power</span>
                            <span className="font-semibold text-green-600">
                                {balances.legos ? formatCurrency(balances.legos, 18) : '0.00'}
                            </span>
                        </div>

                        <div className="flex justify-between pt-2 border-t">
                            <span className="text-gray-600">Proposal Threshold</span>
                            <span className="text-sm text-gray-500">100 LEGOS</span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Governance Information */}
            <div className="card">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                    <Users className="h-5 w-5 text-purple-600 mr-2" />
                    Governance Overview
                </h3>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="text-center">
                        <div className="text-2xl font-bold text-gray-900">7 days</div>
                        <div className="text-sm text-gray-600">Voting Period</div>
                    </div>

                    <div className="text-center">
                        <div className="text-2xl font-bold text-gray-900">4%</div>
                        <div className="text-sm text-gray-600">Quorum Required</div>
                    </div>

                    <div className="text-center">
                        <div className="text-2xl font-bold text-gray-900">2 days</div>
                        <div className="text-sm text-gray-600">Timelock Delay</div>
                    </div>
                </div>

                <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-800 mb-2">Governance Process</h4>
                    <ol className="text-sm text-gray-700 space-y-1 list-decimal list-inside">
                        <li>Stake LEGOS tokens to gain voting power</li>
                        <li>Create proposals (requires 100 LEGOS threshold)</li>
                        <li>Community votes for 7 days</li>
                        <li>Successful proposals execute after 2-day timelock</li>
                    </ol>
                </div>
            </div>
        </div>
    );
};

export default GovernancePanel; 