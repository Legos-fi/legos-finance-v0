import React, { useState, useEffect } from 'react';
import { PlusCircle, MinusCircle, BarChart3, Clock, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { parseUnits, formatUnits, formatCurrency, formatAPY } from '../config/contracts';

const OrderBook = ({ contracts, account, onOrderPlaced }) => {
    const [activeOrderType, setActiveOrderType] = useState('lend');
    const [orderForm, setOrderForm] = useState({
        asset: 'usdc',
        amount: '',
        interestRate: '',
        duration: '30',
        collateralAsset: 'weth',
        collateralAmount: '',
        maxLTV: '75'
    });

    const [orders, setOrders] = useState([]);
    const [orderBookData, setOrderBookData] = useState({ usdc: null, weth: null });
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (contracts.clob && account) {
            loadUserOrders();
            loadOrderBookData();
        }
    }, [contracts, account]);

    const loadUserOrders = async () => {
        try {
            const orderIds = await contracts.clob.getUserOrders(account);
            const orderPromises = orderIds.map(id => contracts.clob.orders(id));
            const orderData = await Promise.all(orderPromises);

            const formattedOrders = orderData.map((order, index) => ({
                id: orderIds[index],
                orderType: order[2] === 0 ? 'LEND' : 'BORROW',
                status: ['PENDING', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'EXPIRED'][order[3]],
                principalAmount: order[4],
                remainingAmount: order[5],
                interestRate: order[6],
                duration: order[7],
                timestamp: order[11]
            }));

            setOrders(formattedOrders);
        } catch (error) {
            console.error('Error loading user orders:', error);
        }
    };

    const loadOrderBookData = async () => {
        try {
            const usdcLendData = await contracts.clob.getOrderBookDepth(
                await contracts.usdc.getAddress(),
                true
            );
            const usdcBorrowData = await contracts.clob.getOrderBookDepth(
                await contracts.usdc.getAddress(),
                false
            );

            const wethLendData = await contracts.clob.getOrderBookDepth(
                await contracts.weth.getAddress(),
                true
            );
            const wethBorrowData = await contracts.clob.getOrderBookDepth(
                await contracts.weth.getAddress(),
                false
            );

            setOrderBookData({
                usdc: {
                    lend: { rates: usdcLendData[0], amounts: usdcLendData[1] },
                    borrow: { rates: usdcBorrowData[0], amounts: usdcBorrowData[1] }
                },
                weth: {
                    lend: { rates: wethLendData[0], amounts: wethLendData[1] },
                    borrow: { rates: wethBorrowData[0], amounts: wethBorrowData[1] }
                }
            });
        } catch (error) {
            console.error('Error loading order book data:', error);
        }
    };

    const handlePlaceOrder = async () => {
        if (!orderForm.amount || !orderForm.interestRate) {
            toast.error('Please fill in all required fields');
            return;
        }

        setLoading(true);

        try {
            const asset = orderForm.asset === 'usdc' ? contracts.usdc : contracts.weth;
            const assetAddress = await asset.getAddress();
            const decimals = orderForm.asset === 'usdc' ? 6 : 18;
            const amount = parseUnits(orderForm.amount, decimals);
            const interestRate = parseInt(orderForm.interestRate * 100); // Convert to basis points
            const duration = parseInt(orderForm.duration) * 24 * 60 * 60; // Convert days to seconds
            const expiry = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60); // 7 days from now

            if (activeOrderType === 'lend') {
                // Approve tokens for lending
                await asset.approve(await contracts.clob.getAddress(), amount);

                const collateralAsset = orderForm.collateralAsset === 'usdc' ? contracts.usdc : contracts.weth;
                const collateralAddress = await collateralAsset.getAddress();
                const maxLTV = parseInt(orderForm.maxLTV) * 100; // Convert to basis points

                const tx = await contracts.clob.placeLendOrder(
                    assetAddress,
                    amount,
                    interestRate,
                    duration,
                    maxLTV,
                    collateralAddress,
                    expiry
                );

                await tx.wait();
                toast.success('Lending order placed successfully!');
            } else {
                // For borrowing orders, need collateral
                const collateralAsset = orderForm.collateralAsset === 'usdc' ? contracts.usdc : contracts.weth;
                const collateralDecimals = orderForm.collateralAsset === 'usdc' ? 6 : 18;
                const collateralAmount = parseUnits(orderForm.collateralAmount, collateralDecimals);

                // Approve collateral
                await collateralAsset.approve(await contracts.clob.getAddress(), collateralAmount);

                const tx = await contracts.clob.placeBorrowOrder(
                    assetAddress,
                    amount,
                    interestRate,
                    duration,
                    await collateralAsset.getAddress(),
                    collateralAmount,
                    expiry
                );

                await tx.wait();
                toast.success('Borrowing order placed successfully!');
            }

            // Reset form and reload data
            setOrderForm({
                asset: 'usdc',
                amount: '',
                interestRate: '',
                duration: '30',
                collateralAsset: 'weth',
                collateralAmount: '',
                maxLTV: '75'
            });

            loadUserOrders();
            loadOrderBookData();
            onOrderPlaced();

        } catch (error) {
            console.error('Error placing order:', error);
            toast.error(error.message || 'Failed to place order');
        } finally {
            setLoading(false);
        }
    };

    const handleCancelOrder = async (orderId) => {
        try {
            const tx = await contracts.clob.cancelOrder(orderId);
            await tx.wait();
            toast.success('Order cancelled successfully!');

            loadUserOrders();
            loadOrderBookData();
            onOrderPlaced();
        } catch (error) {
            console.error('Error cancelling order:', error);
            toast.error('Failed to cancel order');
        }
    };

    const renderOrderBookTable = (asset, type) => {
        const data = orderBookData[asset]?.[type];
        if (!data || data.rates.length === 0) {
            return (
                <div className="text-center py-4 text-gray-500">
                    No {type} orders
                </div>
            );
        }

        const decimals = asset === 'usdc' ? 6 : 18;
        const symbol = asset.toUpperCase();

        return (
            <div className="space-y-2">
                {data.rates.map((rate, index) => (
                    <div key={index} className="flex justify-between items-center py-2 px-3 bg-gray-50 rounded">
                        <span className="text-sm text-gray-600">
                            {formatAPY(rate)}%
                        </span>
                        <span className="text-sm font-mono">
                            {formatCurrency(data.amounts[index], decimals, symbol)}
                        </span>
                    </div>
                ))}
            </div>
        );
    };

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <h2 className="text-2xl font-bold text-gray-900">Order Book</h2>
                <div className="flex space-x-2">
                    <button
                        onClick={() => setActiveOrderType('lend')}
                        className={`px-4 py-2 rounded-lg ${activeOrderType === 'lend'
                                ? 'bg-green-600 text-white'
                                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                            }`}
                    >
                        Lend
                    </button>
                    <button
                        onClick={() => setActiveOrderType('borrow')}
                        className={`px-4 py-2 rounded-lg ${activeOrderType === 'borrow'
                                ? 'bg-blue-600 text-white'
                                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                            }`}
                    >
                        Borrow
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Order Form */}
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4">
                        Place {activeOrderType === 'lend' ? 'Lending' : 'Borrowing'} Order
                    </h3>

                    <div className="space-y-4">
                        {/* Asset Selection */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Asset
                            </label>
                            <select
                                value={orderForm.asset}
                                onChange={(e) => setOrderForm({ ...orderForm, asset: e.target.value })}
                                className="input-field w-full"
                            >
                                <option value="usdc">USDC</option>
                                <option value="weth">WETH</option>
                            </select>
                        </div>

                        {/* Amount */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Amount
                            </label>
                            <input
                                type="number"
                                value={orderForm.amount}
                                onChange={(e) => setOrderForm({ ...orderForm, amount: e.target.value })}
                                className="input-field w-full"
                                placeholder="0.0"
                                step="0.01"
                            />
                        </div>

                        {/* Interest Rate */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Interest Rate (APY %)
                            </label>
                            <input
                                type="number"
                                value={orderForm.interestRate}
                                onChange={(e) => setOrderForm({ ...orderForm, interestRate: e.target.value })}
                                className="input-field w-full"
                                placeholder="5.00"
                                step="0.01"
                            />
                        </div>

                        {/* Duration */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Duration (Days)
                            </label>
                            <select
                                value={orderForm.duration}
                                onChange={(e) => setOrderForm({ ...orderForm, duration: e.target.value })}
                                className="input-field w-full"
                            >
                                <option value="7">7 Days</option>
                                <option value="14">14 Days</option>
                                <option value="30">30 Days</option>
                                <option value="90">90 Days</option>
                                <option value="180">180 Days</option>
                            </select>
                        </div>

                        {/* Collateral Settings */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Collateral Asset
                            </label>
                            <select
                                value={orderForm.collateralAsset}
                                onChange={(e) => setOrderForm({ ...orderForm, collateralAsset: e.target.value })}
                                className="input-field w-full"
                            >
                                <option value="usdc">USDC</option>
                                <option value="weth">WETH</option>
                            </select>
                        </div>

                        {activeOrderType === 'borrow' && (
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-2">
                                    Collateral Amount
                                </label>
                                <input
                                    type="number"
                                    value={orderForm.collateralAmount}
                                    onChange={(e) => setOrderForm({ ...orderForm, collateralAmount: e.target.value })}
                                    className="input-field w-full"
                                    placeholder="0.0"
                                    step="0.01"
                                />
                            </div>
                        )}

                        {activeOrderType === 'lend' && (
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-2">
                                    Max LTV (%)
                                </label>
                                <select
                                    value={orderForm.maxLTV}
                                    onChange={(e) => setOrderForm({ ...orderForm, maxLTV: e.target.value })}
                                    className="input-field w-full"
                                >
                                    <option value="50">50%</option>
                                    <option value="60">60%</option>
                                    <option value="70">70%</option>
                                    <option value="75">75%</option>
                                    <option value="80">80%</option>
                                </select>
                            </div>
                        )}

                        <button
                            onClick={handlePlaceOrder}
                            disabled={loading}
                            className="btn-primary w-full"
                        >
                            {loading ? (
                                <span className="loading-dots">Placing Order</span>
                            ) : (
                                <>
                                    <PlusCircle className="inline h-4 w-4 mr-2" />
                                    Place {activeOrderType === 'lend' ? 'Lending' : 'Borrowing'} Order
                                </>
                            )}
                        </button>
                    </div>
                </div>

                {/* Order Book Depth */}
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4 flex items-center">
                        <BarChart3 className="h-5 w-5 mr-2" />
                        Order Book Depth
                    </h3>

                    <div className="space-y-4">
                        {/* Asset Tabs */}
                        <div className="flex space-x-2">
                            <button
                                onClick={() => setOrderForm({ ...orderForm, asset: 'usdc' })}
                                className={`px-3 py-1 rounded text-sm ${orderForm.asset === 'usdc'
                                        ? 'bg-blue-100 text-blue-800'
                                        : 'text-gray-600 hover:bg-gray-100'
                                    }`}
                            >
                                USDC
                            </button>
                            <button
                                onClick={() => setOrderForm({ ...orderForm, asset: 'weth' })}
                                className={`px-3 py-1 rounded text-sm ${orderForm.asset === 'weth'
                                        ? 'bg-purple-100 text-purple-800'
                                        : 'text-gray-600 hover:bg-gray-100'
                                    }`}
                            >
                                WETH
                            </button>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            {/* Lending Orders */}
                            <div>
                                <h4 className="text-sm font-medium text-green-700 mb-2">
                                    Lending Orders
                                </h4>
                                {renderOrderBookTable(orderForm.asset, 'lend')}
                            </div>

                            {/* Borrowing Orders */}
                            <div>
                                <h4 className="text-sm font-medium text-blue-700 mb-2">
                                    Borrowing Orders
                                </h4>
                                {renderOrderBookTable(orderForm.asset, 'borrow')}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* User Orders */}
            {orders.length > 0 && (
                <div className="card">
                    <h3 className="text-lg font-semibold mb-4 flex items-center">
                        <Clock className="h-5 w-5 mr-2" />
                        Your Orders
                    </h3>

                    <div className="overflow-x-auto">
                        <table className="min-w-full divide-y divide-gray-200">
                            <thead className="bg-gray-50">
                                <tr>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Type
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Amount
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Rate
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Status
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                        Actions
                                    </th>
                                </tr>
                            </thead>
                            <tbody className="bg-white divide-y divide-gray-200">
                                {orders.map((order) => (
                                    <tr key={order.id}>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${order.orderType === 'LEND'
                                                    ? 'bg-green-100 text-green-800'
                                                    : 'bg-blue-100 text-blue-800'
                                                }`}>
                                                {order.orderType}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-mono">
                                            {formatUnits(order.remainingAmount, 18)}
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                            {formatAPY(order.interestRate)}%
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${order.status === 'PENDING' ? 'bg-yellow-100 text-yellow-800' :
                                                    order.status === 'FILLED' ? 'bg-green-100 text-green-800' :
                                                        order.status === 'CANCELLED' ? 'bg-red-100 text-red-800' :
                                                            'bg-gray-100 text-gray-800'
                                                }`}>
                                                {order.status}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                            {(order.status === 'PENDING' || order.status === 'PARTIALLY_FILLED') && (
                                                <button
                                                    onClick={() => handleCancelOrder(order.id)}
                                                    className="text-red-600 hover:text-red-900"
                                                >
                                                    <X className="h-4 w-4" />
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}
        </div>
    );
};

export default OrderBook; 