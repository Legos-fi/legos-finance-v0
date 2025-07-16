// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILegosCore
 * @dev Core interface defining data structures and enums for Legos Finance Protocol
 */
interface ILegosCore {
    /// @dev Order types for the CLOB
    enum OrderType {
        LEND,
        BORROW
    }
    
    /// @dev Order status
    enum OrderStatus {
        PENDING,
        PARTIALLY_FILLED,
        FILLED,
        CANCELLED,
        EXPIRED
    }
    
    /// @dev Loan status
    enum LoanStatus {
        ACTIVE,
        REPAID,
        LIQUIDATED,
        DEFAULTED
    }
    
    /// @dev Collateral status
    enum CollateralStatus {
        HEALTHY,
        WARNING,
        LIQUIDATION_ELIGIBLE,
        LIQUIDATED
    }
    
    /// @dev Order structure for the CLOB
    struct Order {
        uint256 orderId;
        address user;
        OrderType orderType;
        OrderStatus status;
        uint256 principalAmount;
        uint256 remainingAmount;
        uint256 interestRate; // in basis points (100 = 1%)
        uint256 duration; // in seconds
        uint256 maxLTV; // in basis points (7500 = 75%)
        address collateralToken;
        uint256 collateralAmount;
        uint256 timestamp;
        uint256 expiry;
    }
    
    /// @dev Loan structure
    struct Loan {
        uint256 loanId;
        address borrower;
        address lender;
        uint256 principalAmount;
        uint256 remainingPrincipal;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        uint256 lastUpdateTime;
        address collateralToken;
        uint256 collateralAmount;
        uint256 accruedInterest;
        LoanStatus status;
    }
    
    /// @dev Collateral position
    struct CollateralPosition {
        address owner;
        address token;
        uint256 amount;
        uint256 lockedAmount;
        uint256 availableAmount;
        CollateralStatus status;
        uint256 lastUpdateTime;
    }
    
    /// @dev Market data
    struct MarketData {
        address asset;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 utilizationRate;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 lastUpdateTime;
    }
    
    /// @dev Pool configuration
    struct PoolConfig {
        address asset;
        uint256 reserveFactor; // in basis points
        uint256 baseRate; // in basis points
        uint256 multiplier; // in basis points
        uint256 jumpMultiplier; // in basis points
        uint256 optimalUtilization; // in basis points
        uint256 liquidationThreshold; // in basis points
        uint256 liquidationPenalty; // in basis points
        bool isActive;
    }
    
    /// @dev Risk parameters
    struct RiskParameters {
        uint256 maxLTV; // in basis points
        uint256 liquidationThreshold; // in basis points
        uint256 liquidationPenalty; // in basis points
        uint256 minCollateralRatio; // in basis points
        bool isEnabled;
    }
    
    /// @dev Events
    event OrderPlaced(uint256 indexed orderId, address indexed user, OrderType orderType, uint256 amount);
    event OrderMatched(uint256 indexed lendOrderId, uint256 indexed borrowOrderId, uint256 amount);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event LiquidationExecuted(uint256 indexed loanId, address indexed liquidator, uint256 collateralSeized);
    event InterestAccrued(uint256 indexed loanId, uint256 interest);
} 