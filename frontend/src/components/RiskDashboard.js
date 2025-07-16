import React from 'react';
import { Shield, AlertTriangle, TrendingDown } from 'lucide-react';
import { formatUnits } from '../config/contracts';

const RiskDashboard = ({ contracts, protocolData }) => {
    return (
        <div className="space-y-6">
            <h2 className="text-2xl font-bold text-gray-900">Risk Dashboard</h2>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="card">
                    <div className="flex items-center mb-4">
                        <Shield className="h-6 w-6 text-green-600 mr-2" />
                        <h3 className="text-lg font-semibold">Total Loans</h3>
                    </div>
                    <div className="text-3xl font-bold text-gray-900">
                        {protocolData.totalLoans || 0}
                    </div>
                    <p className="text-sm text-gray-600 mt-2">Active loan positions</p>
                </div>

                <div className="card">
                    <div className="flex items-center mb-4">
                        <AlertTriangle className="h-6 w-6 text-yellow-600 mr-2" />
                        <h3 className="text-lg font-semibold">At Risk Loans</h3>
                    </div>
                    <div className="text-3xl font-bold text-yellow-600">
                        {protocolData.loansAtRisk || 0}
                    </div>
                    <p className="text-sm text-gray-600 mt-2">Health factor &lt; 1.2</p>
                </div>

                <div className="card">
                    <div className="flex items-center mb-4">
                        <TrendingDown className="h-6 w-6 text-blue-600 mr-2" />
                        <h3 className="text-lg font-semibold">Avg Health Factor</h3>
                    </div>
                    <div className="text-3xl font-bold text-blue-600">
                        {protocolData.avgHealthFactor ?
                            parseFloat(formatUnits(protocolData.avgHealthFactor, 18)).toFixed(2) :
                            '0.00'
                        }
                    </div>
                    <p className="text-sm text-gray-600 mt-2">Protocol average</p>
                </div>
            </div>

            <div className="card">
                <h3 className="text-lg font-semibold mb-4">Risk Metrics Overview</h3>
                <div className="space-y-4">
                    <div className="flex justify-between items-center">
                        <span className="text-gray-600">Protocol Health Status</span>
                        <span className={`px-3 py-1 rounded-full text-sm font-semibold ${(protocolData.loansAtRisk || 0) === 0
                                ? 'bg-green-100 text-green-800'
                                : (protocolData.loansAtRisk || 0) < 5
                                    ? 'bg-yellow-100 text-yellow-800'
                                    : 'bg-red-100 text-red-800'
                            }`}>
                            {(protocolData.loansAtRisk || 0) === 0 ? 'Healthy' :
                                (protocolData.loansAtRisk || 0) < 5 ? 'Monitor' : 'At Risk'}
                        </span>
                    </div>

                    <div className="flex justify-between items-center">
                        <span className="text-gray-600">Risk Coverage Ratio</span>
                        <span className="font-semibold">
                            {protocolData.totalLoans ?
                                `${((1 - (protocolData.loansAtRisk || 0) / protocolData.totalLoans) * 100).toFixed(1)}%` :
                                '100%'
                            }
                        </span>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default RiskDashboard; 