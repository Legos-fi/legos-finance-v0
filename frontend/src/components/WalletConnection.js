import React from 'react';
import { Wallet, Power, ChevronDown } from 'lucide-react';
import { formatAddress } from '../config/contracts';

const WalletConnection = ({ account, network, onConnect, onDisconnect, loading }) => {
    if (!account) {
        return (
            <button
                onClick={onConnect}
                disabled={loading}
                className="btn-primary flex items-center space-x-2"
            >
                <Wallet className="h-4 w-4" />
                <span>{loading ? 'Connecting...' : 'Connect Wallet'}</span>
            </button>
        );
    }

    return (
        <div className="flex items-center space-x-3">
            {/* Network Indicator */}
            {network && (
                <div className="flex items-center space-x-2 bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm">
                    <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                    <span>{network.name}</span>
                </div>
            )}

            {/* Account Info */}
            <div className="flex items-center space-x-2 bg-gray-100 rounded-lg px-3 py-2">
                <Wallet className="h-4 w-4 text-gray-600" />
                <span className="text-sm font-mono">{formatAddress(account)}</span>

                {/* Disconnect Button */}
                <button
                    onClick={onDisconnect}
                    className="ml-2 p-1 text-gray-400 hover:text-red-600 transition-colors"
                    title="Disconnect Wallet"
                >
                    <Power className="h-4 w-4" />
                </button>
            </div>
        </div>
    );
};

export default WalletConnection; 