// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ILegosCore.sol";
import "../libraries/LegosMath.sol";

/**
 * @title LegosCLOB
 * @dev Central Limit Order Book for Legos Finance Protocol
 * Handles order placement, matching, and management for lending and borrowing
 */
contract LegosCLOB is ILegosCore, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using LegosMath for uint256;
    
    /// @dev State variables
    uint256 private _nextOrderId = 1;
    uint256 private _nextLoanId = 1;
    
    /// @dev Mappings
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userOrders;
    mapping(address => uint256[]) public userLoans;
    mapping(address => mapping(address => uint256)) public userCollateral;
    mapping(address => RiskParameters) public assetRiskParams;
    
    /// @dev Order book data structures
    mapping(address => mapping(uint256 => uint256[])) public lendOrdersByRate; // asset => rate => orderIds
    mapping(address => mapping(uint256 => uint256[])) public borrowOrdersByRate; // asset => rate => orderIds
    mapping(address => uint256[]) public activeLendRates; // asset => rates
    mapping(address => uint256[]) public activeBorrowRates; // asset => rates
    
    /// @dev Protocol parameters
    uint256 public constant MIN_ORDER_AMOUNT = 1e18; // 1 token minimum
    uint256 public constant MAX_INTEREST_RATE = 10000; // 100% max interest rate
    uint256 public constant DEFAULT_LTV = 7500; // 75% default max LTV
    uint256 public protocolFee = 100; // 1% protocol fee in basis points
    
    /// @dev Custom errors
    error InvalidAmount();
    error InvalidInterestRate();
    error InvalidLTV();
    error OrderNotFound();
    error OrderNotActive();
    error InsufficientCollateral();
    error UnauthorizedAccess();
    error InvalidAsset();
    error OrderExpired();
    
    /// @dev Events specific to CLOB
    event OrderBookUpdated(address indexed asset, uint256 indexed rate, bool isLend);
    event OrderPartiallyFilled(uint256 indexed orderId, uint256 amountFilled, uint256 remaining);
    event LendingRateUpdated(address indexed asset, uint256 newRate);
    event BorrowingRateUpdated(address indexed asset, uint256 newRate);
    event InstantExecution(uint256 indexed orderId, uint256 amount, uint256 rate);
    event OrderBookDepthUpdated(address indexed asset, uint256 totalLendVolume, uint256 totalBorrowVolume);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @dev Place a lending order in the order book
     * @param asset The asset to lend
     * @param amount The amount to lend
     * @param interestRate The interest rate in basis points
     * @param duration The loan duration in seconds
     * @param maxLTV Maximum loan-to-value ratio accepted
     * @param collateralToken Accepted collateral token
     * @param expiry Order expiry timestamp
     */
    function placeLendOrder(
        address asset,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 maxLTV,
        address collateralToken,
        uint256 expiry
    ) external nonReentrant returns (uint256 orderId) {
        _validateOrderParams(amount, interestRate, maxLTV, expiry);
        
        // Transfer assets to contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        orderId = _nextOrderId++;
        
        orders[orderId] = Order({
            orderId: orderId,
            user: msg.sender,
            orderType: OrderType.LEND,
            status: OrderStatus.PENDING,
            principalAmount: amount,
            remainingAmount: amount,
            interestRate: interestRate,
            duration: duration,
            maxLTV: maxLTV,
            collateralToken: collateralToken,
            collateralAmount: 0, // Not applicable for lend orders
            timestamp: block.timestamp,
            expiry: expiry
        });
        
        userOrders[msg.sender].push(orderId);
        _addToOrderBook(asset, orderId, interestRate, true);
        
        emit OrderPlaced(orderId, msg.sender, OrderType.LEND, amount);
        
        // Try to match immediately for instant execution
        uint256 matchedAmount = _tryMatchOrderInstant(orderId, asset);
        
        if (matchedAmount > 0) {
            emit InstantExecution(orderId, matchedAmount, interestRate);
        }
    }
    
    /**
     * @dev Place a borrowing order in the order book
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @param interestRate The maximum interest rate willing to pay
     * @param duration The loan duration in seconds
     * @param collateralToken The collateral token to deposit
     * @param collateralAmount The collateral amount to deposit
     * @param expiry Order expiry timestamp
     */
    function placeBorrowOrder(
        address asset,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount,
        uint256 expiry
    ) external nonReentrant returns (uint256 orderId) {
        _validateOrderParams(amount, interestRate, DEFAULT_LTV, expiry);
        _validateCollateral(asset, amount, collateralToken, collateralAmount);
        
        // Transfer collateral to contract
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        userCollateral[msg.sender][collateralToken] += collateralAmount;
        
        orderId = _nextOrderId++;
        
        orders[orderId] = Order({
            orderId: orderId,
            user: msg.sender,
            orderType: OrderType.BORROW,
            status: OrderStatus.PENDING,
            principalAmount: amount,
            remainingAmount: amount,
            interestRate: interestRate,
            duration: duration,
            maxLTV: DEFAULT_LTV,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            timestamp: block.timestamp,
            expiry: expiry
        });
        
        userOrders[msg.sender].push(orderId);
        _addToOrderBook(asset, orderId, interestRate, false);
        
        emit OrderPlaced(orderId, msg.sender, OrderType.BORROW, amount);
        
        // Try to match immediately for instant execution
        uint256 matchedAmount = _tryMatchOrderInstant(orderId, asset);
        
        if (matchedAmount > 0) {
            emit InstantExecution(orderId, matchedAmount, interestRate);
        }
    }
    
    /**
     * @dev Cancel an active order
     * @param orderId The order ID to cancel
     */
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        
        if (order.user != msg.sender) {
            revert UnauthorizedAccess();
        }
        
        if (order.status != OrderStatus.PENDING && order.status != OrderStatus.PARTIALLY_FILLED) {
            revert OrderNotActive();
        }
        
        order.status = OrderStatus.CANCELLED;
        
        // Refund remaining assets
        if (order.orderType == OrderType.LEND) {
            if (order.remainingAmount > 0) {
                IERC20(order.collateralToken).safeTransfer(order.user, order.remainingAmount);
            }
        } else {
            // Return collateral for borrow orders
            if (order.collateralAmount > 0) {
                userCollateral[order.user][order.collateralToken] -= order.collateralAmount;
                IERC20(order.collateralToken).safeTransfer(order.user, order.collateralAmount);
            }
        }
        
        _removeFromOrderBook(orderId);
    }
    
    /**
     * @dev Get the best lending rate for an asset
     * @param asset The asset to check
     * @return The best lending rate in basis points
     */
    function getBestLendingRate(address asset) external view returns (uint256) {
        uint256[] memory rates = activeLendRates[asset];
        if (rates.length == 0) return 0;
        
        uint256 bestRate = type(uint256).max;
        for (uint256 i = 0; i < rates.length; i++) {
            if (lendOrdersByRate[asset][rates[i]].length > 0 && rates[i] < bestRate) {
                bestRate = rates[i];
            }
        }
        
        return bestRate == type(uint256).max ? 0 : bestRate;
    }
    
    /**
     * @dev Get the best borrowing rate for an asset
     * @param asset The asset to check
     * @return The best borrowing rate in basis points
     */
    function getBestBorrowingRate(address asset) external view returns (uint256) {
        uint256[] memory rates = activeBorrowRates[asset];
        if (rates.length == 0) return 0;
        
        uint256 bestRate = 0;
        for (uint256 i = 0; i < rates.length; i++) {
            if (borrowOrdersByRate[asset][rates[i]].length > 0 && rates[i] > bestRate) {
                bestRate = rates[i];
            }
        }
        
        return bestRate;
    }
    
    /**
     * @dev Get order book depth for an asset
     * @param asset The asset to check
     * @param isLend Whether to get lending or borrowing depth
     * @return rates Array of interest rates
     * @return amounts Array of amounts at each rate
     */
    function getOrderBookDepth(address asset, bool isLend) 
        external 
        view 
        returns (uint256[] memory rates, uint256[] memory amounts) 
    {
        uint256[] memory activeRates = isLend ? activeLendRates[asset] : activeBorrowRates[asset];
        rates = new uint256[](activeRates.length);
        amounts = new uint256[](activeRates.length);
        
        for (uint256 i = 0; i < activeRates.length; i++) {
            rates[i] = activeRates[i];
            
            uint256[] memory orderIds = isLend 
                ? lendOrdersByRate[asset][activeRates[i]]
                : borrowOrdersByRate[asset][activeRates[i]];
            
            uint256 totalAmount = 0;
            for (uint256 j = 0; j < orderIds.length; j++) {
                if (orders[orderIds[j]].status == OrderStatus.PENDING || 
                    orders[orderIds[j]].status == OrderStatus.PARTIALLY_FILLED) {
                    totalAmount += orders[orderIds[j]].remainingAmount;
                }
            }
            amounts[i] = totalAmount;
        }
    }
    
    /**
     * @dev Get user's active orders
     * @param user The user address
     * @return orderIds Array of order IDs
     */
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }
    
    /**
     * @dev Get user's active loans
     * @param user The user address
     * @return loanIds Array of loan IDs
     */
    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }
    
    /**
     * @dev Execute market order - instant execution at best available rate
     * @param asset The asset to trade
     * @param amount The amount to trade
     * @param isLend Whether this is a lending (true) or borrowing (false) order
     * @param maxSlippage Maximum slippage tolerance in basis points
     * @param collateralToken Collateral token for borrow orders
     * @param collateralAmount Collateral amount for borrow orders
     * @return executedAmount Amount that was executed
     * @return avgRate Average execution rate
     */
    function executeMarketOrder(
        address asset,
        uint256 amount,
        bool isLend,
        uint256 maxSlippage,
        address collateralToken,
        uint256 collateralAmount
    ) external nonReentrant returns (uint256 executedAmount, uint256 avgRate) {
        if (amount < MIN_ORDER_AMOUNT) revert InvalidAmount();
        
        if (isLend) {
            // Transfer assets for lending
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            (executedAmount, avgRate) = _executeMarketLendOrder(asset, amount, maxSlippage);
        } else {
            // Validate and transfer collateral for borrowing
            _validateCollateral(asset, amount, collateralToken, collateralAmount);
            IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
            userCollateral[msg.sender][collateralToken] += collateralAmount;
            (executedAmount, avgRate) = _executeMarketBorrowOrder(asset, amount, maxSlippage, collateralToken, collateralAmount);
        }
        
        emit InstantExecution(0, executedAmount, avgRate); // orderId = 0 for market orders
    }
    
    /**
     * @dev Execute market lending order
     */
    function _executeMarketLendOrder(
        address asset, 
        uint256 amount, 
        uint256 maxSlippage
    ) internal returns (uint256 executedAmount, uint256 avgRate) {
        uint256[] memory borrowRates = activeBorrowRates[asset];
        _sortRatesDescending(borrowRates);
        
        uint256 remainingAmount = amount;
        uint256 totalRate = 0;
        uint256 totalExecuted = 0;
        
        for (uint256 i = 0; i < borrowRates.length && remainingAmount > 0; i++) {
            uint256[] memory borrowOrderIds = borrowOrdersByRate[asset][borrowRates[i]];
            
            for (uint256 j = 0; j < borrowOrderIds.length && remainingAmount > 0; j++) {
                Order storage borrowOrder = orders[borrowOrderIds[j]];
                
                if (borrowOrder.status == OrderStatus.PENDING || 
                    borrowOrder.status == OrderStatus.PARTIALLY_FILLED) {
                    
                    uint256 matchAmount = remainingAmount < borrowOrder.remainingAmount 
                        ? remainingAmount 
                        : borrowOrder.remainingAmount;
                    
                    // Create temporary lend order for execution
                    uint256 tempLendOrderId = _createTempLendOrder(msg.sender, asset, matchAmount, borrowRates[i]);
                    _executeMatch(tempLendOrderId, borrowOrderIds[j], asset);
                    
                    totalRate += borrowRates[i] * matchAmount;
                    totalExecuted += matchAmount;
                    remainingAmount -= matchAmount;
                }
            }
        }
        
        executedAmount = totalExecuted;
        avgRate = totalExecuted > 0 ? totalRate / totalExecuted : 0;
        
        // Refund unexecuted amount
        if (remainingAmount > 0) {
            IERC20(asset).safeTransfer(msg.sender, remainingAmount);
        }
    }
    
    /**
     * @dev Execute market borrowing order
     */
    function _executeMarketBorrowOrder(
        address asset,
        uint256 amount,
        uint256 maxSlippage,
        address collateralToken,
        uint256 collateralAmount
    ) internal returns (uint256 executedAmount, uint256 avgRate) {
        uint256[] memory lendRates = activeLendRates[asset];
        _sortRatesAscending(lendRates);
        
        uint256 remainingAmount = amount;
        uint256 totalRate = 0;
        uint256 totalExecuted = 0;
        
        for (uint256 i = 0; i < lendRates.length && remainingAmount > 0; i++) {
            uint256[] memory lendOrderIds = lendOrdersByRate[asset][lendRates[i]];
            
            for (uint256 j = 0; j < lendOrderIds.length && remainingAmount > 0; j++) {
                Order storage lendOrder = orders[lendOrderIds[j]];
                
                if (lendOrder.status == OrderStatus.PENDING || 
                    lendOrder.status == OrderStatus.PARTIALLY_FILLED) {
                    
                    uint256 matchAmount = remainingAmount < lendOrder.remainingAmount 
                        ? remainingAmount 
                        : lendOrder.remainingAmount;
                    
                    // Calculate proportional collateral
                    uint256 proportionalCollateral = (collateralAmount * matchAmount) / amount;
                    
                    // Create temporary borrow order for execution
                    uint256 tempBorrowOrderId = _createTempBorrowOrder(
                        msg.sender, asset, matchAmount, lendRates[i], 
                        collateralToken, proportionalCollateral
                    );
                    _executeMatch(lendOrderIds[j], tempBorrowOrderId, asset);
                    
                    totalRate += lendRates[i] * matchAmount;
                    totalExecuted += matchAmount;
                    remainingAmount -= matchAmount;
                }
            }
        }
        
        executedAmount = totalExecuted;
        avgRate = totalExecuted > 0 ? totalRate / totalExecuted : 0;
        
        // Refund unused collateral
        if (remainingAmount > 0) {
            uint256 unusedCollateral = (collateralAmount * remainingAmount) / amount;
            userCollateral[msg.sender][collateralToken] -= unusedCollateral;
            IERC20(collateralToken).safeTransfer(msg.sender, unusedCollateral);
        }
    }
    
    /**
     * @dev Create temporary lend order for market execution
     */
    function _createTempLendOrder(
        address user,
        address asset,
        uint256 amount,
        uint256 rate
    ) internal returns (uint256 orderId) {
        orderId = _nextOrderId++;
        
        orders[orderId] = Order({
            orderId: orderId,
            user: user,
            orderType: OrderType.LEND,
            status: OrderStatus.PENDING,
            principalAmount: amount,
            remainingAmount: amount,
            interestRate: rate,
            duration: 30 days, // Default duration for market orders
            maxLTV: DEFAULT_LTV,
            collateralToken: asset, // Use asset as collateral token reference
            collateralAmount: 0,
            timestamp: block.timestamp,
            expiry: block.timestamp + 1 hours // Short expiry for temp orders
        });
    }
    
    /**
     * @dev Create temporary borrow order for market execution
     */
    function _createTempBorrowOrder(
        address user,
        address asset,
        uint256 amount,
        uint256 rate,
        address collateralToken,
        uint256 collateralAmount
    ) internal returns (uint256 orderId) {
        orderId = _nextOrderId++;
        
        orders[orderId] = Order({
            orderId: orderId,
            user: user,
            orderType: OrderType.BORROW,
            status: OrderStatus.PENDING,
            principalAmount: amount,
            remainingAmount: amount,
            interestRate: rate,
            duration: 30 days, // Default duration for market orders
            maxLTV: DEFAULT_LTV,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            timestamp: block.timestamp,
            expiry: block.timestamp + 1 hours // Short expiry for temp orders
        });
    }
    
    /**
     * @dev Internal function to try matching an order instantly
     * @return matchedAmount Total amount that was matched
     */
    function _tryMatchOrderInstant(uint256 orderId, address asset) internal returns (uint256 matchedAmount) {
        Order storage order = orders[orderId];
        uint256 initialAmount = order.remainingAmount;
        
        if (order.orderType == OrderType.LEND) {
            _matchLendOrderInstant(orderId, asset);
        } else {
            _matchBorrowOrderInstant(orderId, asset);
        }
        
        matchedAmount = initialAmount - order.remainingAmount;
        _updateOrderBookDepth(asset);
    }
    
    /**
     * @dev Update order book depth events
     */
    function _updateOrderBookDepth(address asset) internal {
        (uint256 totalLendVolume, uint256 totalBorrowVolume) = _calculateOrderBookVolume(asset);
        emit OrderBookDepthUpdated(asset, totalLendVolume, totalBorrowVolume);
    }
    
    /**
     * @dev Calculate total volume in order book
     */
    function _calculateOrderBookVolume(address asset) internal view returns (uint256 lendVolume, uint256 borrowVolume) {
        // Calculate total lending volume
        uint256[] memory lendRates = activeLendRates[asset];
        for (uint256 i = 0; i < lendRates.length; i++) {
            uint256[] memory orderIds = lendOrdersByRate[asset][lendRates[i]];
            for (uint256 j = 0; j < orderIds.length; j++) {
                Order storage order = orders[orderIds[j]];
                if (order.status == OrderStatus.PENDING || order.status == OrderStatus.PARTIALLY_FILLED) {
                    lendVolume += order.remainingAmount;
                }
            }
        }
        
        // Calculate total borrowing volume
        uint256[] memory borrowRates = activeBorrowRates[asset];
        for (uint256 i = 0; i < borrowRates.length; i++) {
            uint256[] memory orderIds = borrowOrdersByRate[asset][borrowRates[i]];
            for (uint256 j = 0; j < orderIds.length; j++) {
                Order storage order = orders[orderIds[j]];
                if (order.status == OrderStatus.PENDING || order.status == OrderStatus.PARTIALLY_FILLED) {
                    borrowVolume += order.remainingAmount;
                }
            }
        }
    }
    
    /**
     * @dev Match a lending order with borrowing orders (instant execution)
     */
    function _matchLendOrderInstant(uint256 lendOrderId, address asset) internal {
        _matchLendOrder(lendOrderId, asset);
    }
    
    /**
     * @dev Match a borrowing order with lending orders (instant execution)
     */
    function _matchBorrowOrderInstant(uint256 borrowOrderId, address asset) internal {
        _matchBorrowOrder(borrowOrderId, asset);
    }
    
    /**
     * @dev Match a lending order with borrowing orders
     */
    function _matchLendOrder(uint256 lendOrderId, address asset) internal {
        Order storage lendOrder = orders[lendOrderId];
        uint256[] memory borrowRates = activeBorrowRates[asset];
        
        // Sort borrow rates in descending order to match highest rates first
        _sortRatesDescending(borrowRates);
        
        for (uint256 i = 0; i < borrowRates.length && lendOrder.remainingAmount > 0; i++) {
            if (borrowRates[i] >= lendOrder.interestRate) {
                uint256[] memory borrowOrderIds = borrowOrdersByRate[asset][borrowRates[i]];
                
                for (uint256 j = 0; j < borrowOrderIds.length && lendOrder.remainingAmount > 0; j++) {
                    uint256 borrowOrderId = borrowOrderIds[j];
                    Order storage borrowOrder = orders[borrowOrderId];
                    
                    if (borrowOrder.status == OrderStatus.PENDING || 
                        borrowOrder.status == OrderStatus.PARTIALLY_FILLED) {
                        _executeMatch(lendOrderId, borrowOrderId, asset);
                    }
                }
            }
        }
    }
    
    /**
     * @dev Match a borrowing order with lending orders
     */
    function _matchBorrowOrder(uint256 borrowOrderId, address asset) internal {
        Order storage borrowOrder = orders[borrowOrderId];
        uint256[] memory lendRates = activeLendRates[asset];
        
        // Sort lend rates in ascending order to match lowest rates first
        _sortRatesAscending(lendRates);
        
        for (uint256 i = 0; i < lendRates.length && borrowOrder.remainingAmount > 0; i++) {
            if (lendRates[i] <= borrowOrder.interestRate) {
                uint256[] memory lendOrderIds = lendOrdersByRate[asset][lendRates[i]];
                
                for (uint256 j = 0; j < lendOrderIds.length && borrowOrder.remainingAmount > 0; j++) {
                    uint256 lendOrderId = lendOrderIds[j];
                    Order storage lendOrder = orders[lendOrderId];
                    
                    if (lendOrder.status == OrderStatus.PENDING || 
                        lendOrder.status == OrderStatus.PARTIALLY_FILLED) {
                        _executeMatch(lendOrderId, borrowOrderId, asset);
                    }
                }
            }
        }
    }
    
    /**
     * @dev Execute a match between a lend and borrow order
     */
    function _executeMatch(uint256 lendOrderId, uint256 borrowOrderId, address asset) internal {
        Order storage lendOrder = orders[lendOrderId];
        Order storage borrowOrder = orders[borrowOrderId];
        
        uint256 matchAmount = lendOrder.remainingAmount < borrowOrder.remainingAmount 
            ? lendOrder.remainingAmount 
            : borrowOrder.remainingAmount;
        
        // Create loan
        uint256 loanId = _createLoan(lendOrder, borrowOrder, matchAmount, asset);
        
        // Update order amounts
        lendOrder.remainingAmount -= matchAmount;
        borrowOrder.remainingAmount -= matchAmount;
        
        // Update order statuses
        if (lendOrder.remainingAmount == 0) {
            lendOrder.status = OrderStatus.FILLED;
        } else {
            lendOrder.status = OrderStatus.PARTIALLY_FILLED;
            emit OrderPartiallyFilled(lendOrderId, matchAmount, lendOrder.remainingAmount);
        }
        
        if (borrowOrder.remainingAmount == 0) {
            borrowOrder.status = OrderStatus.FILLED;
        } else {
            borrowOrder.status = OrderStatus.PARTIALLY_FILLED;
            emit OrderPartiallyFilled(borrowOrderId, matchAmount, borrowOrder.remainingAmount);
        }
        
        emit OrderMatched(lendOrderId, borrowOrderId, matchAmount);
    }
    
    /**
     * @dev Create a new loan from matched orders
     */
    function _createLoan(
        Order storage lendOrder,
        Order storage borrowOrder,
        uint256 amount,
        address asset
    ) internal returns (uint256 loanId) {
        loanId = _nextLoanId++;
        
        // Calculate proportional collateral for this loan portion
        uint256 proportionalCollateral = (borrowOrder.collateralAmount * amount) / borrowOrder.principalAmount;
        
        loans[loanId] = Loan({
            loanId: loanId,
            borrower: borrowOrder.user,
            lender: lendOrder.user,
            principalAmount: amount,
            remainingPrincipal: amount,
            interestRate: lendOrder.interestRate, // Use lender's rate
            startTime: block.timestamp,
            duration: borrowOrder.duration < lendOrder.duration ? borrowOrder.duration : lendOrder.duration,
            lastUpdateTime: block.timestamp,
            collateralToken: borrowOrder.collateralToken,
            collateralAmount: proportionalCollateral,
            accruedInterest: 0,
            status: LoanStatus.ACTIVE
        });
        
        userLoans[borrowOrder.user].push(loanId);
        userLoans[lendOrder.user].push(loanId);
        
        // Transfer borrowed asset to borrower
        IERC20(asset).safeTransfer(borrowOrder.user, amount);
        
        // Update collateral allocation
        userCollateral[borrowOrder.user][borrowOrder.collateralToken] -= proportionalCollateral;
        
        emit LoanCreated(loanId, borrowOrder.user, lendOrder.user, amount);
    }
    
    /**
     * @dev Add order to order book data structures
     */
    function _addToOrderBook(address asset, uint256 orderId, uint256 rate, bool isLend) internal {
        if (isLend) {
            lendOrdersByRate[asset][rate].push(orderId);
            if (!_rateExists(activeLendRates[asset], rate)) {
                activeLendRates[asset].push(rate);
            }
        } else {
            borrowOrdersByRate[asset][rate].push(orderId);
            if (!_rateExists(activeBorrowRates[asset], rate)) {
                activeBorrowRates[asset].push(rate);
            }
        }
        
        emit OrderBookUpdated(asset, rate, isLend);
    }
    
    /**
     * @dev Remove order from order book data structures
     */
    function _removeFromOrderBook(uint256 orderId) internal {
        // This is a simplified implementation
        // In production, you'd want to properly remove from the order book arrays
        // and clean up empty rate levels
        // TODO: Implement proper order removal from rate arrays
    }
    
    
    /**
     * @dev Validation functions
     */
    function _validateOrderParams(uint256 amount, uint256 interestRate, uint256 maxLTV, uint256 expiry) internal view {
        if (amount < MIN_ORDER_AMOUNT) revert InvalidAmount();
        if (interestRate > MAX_INTEREST_RATE) revert InvalidInterestRate();
        if (maxLTV > LegosMath.BASIS_POINTS) revert InvalidLTV();
        if (expiry <= block.timestamp) revert OrderExpired();
    }
    
    function _validateCollateral(
        address asset,
        uint256 borrowAmount,
        address collateralToken,
        uint256 collateralAmount
    ) internal view {
        // Simplified validation - in production you'd use a price oracle
        // For now, assume 1:1 ratio and require 150% collateralization
        if (collateralAmount < (borrowAmount * 15000) / LegosMath.BASIS_POINTS) {
            revert InsufficientCollateral();
        }
    }
    
    /**
     * @dev Utility functions
     */
    function _rateExists(uint256[] memory rates, uint256 rate) internal pure returns (bool) {
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] == rate) return true;
        }
        return false;
    }
    
    function _sortRatesAscending(uint256[] memory rates) internal pure {
        // Simple bubble sort - in production use a more efficient algorithm
        for (uint256 i = 0; i < rates.length; i++) {
            for (uint256 j = i + 1; j < rates.length; j++) {
                if (rates[i] > rates[j]) {
                    (rates[i], rates[j]) = (rates[j], rates[i]);
                }
            }
        }
    }
    
    function _sortRatesDescending(uint256[] memory rates) internal pure {
        // Simple bubble sort - in production use a more efficient algorithm
        for (uint256 i = 0; i < rates.length; i++) {
            for (uint256 j = i + 1; j < rates.length; j++) {
                if (rates[i] < rates[j]) {
                    (rates[i], rates[j]) = (rates[j], rates[i]);
                }
            }
        }
    }
} 