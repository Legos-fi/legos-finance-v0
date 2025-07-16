// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ILegosCore.sol";
import "../libraries/LegosMath.sol";
import "./LegosCLOB.sol";

/**
 * @title LegosLendingPool
 * @dev Passive liquidity provision pool that automatically manages orders on the CLOB
 * Users can deposit assets and earn yield without actively managing orders
 */
contract LegosLendingPool is ERC20, ILegosCore, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using LegosMath for uint256;
    
    /// @dev Pool configuration
    address public immutable underlyingAsset;
    LegosCLOB public immutable clob;
    PoolConfig public poolConfig;
    
    /// @dev Pool state
    uint256 public totalBorrows;
    uint256 public reserveBalance;
    uint256 public lastUpdateTime;
    uint256 public liquidityIndex = LegosMath.RAY;
    uint256 public borrowIndex = LegosMath.RAY;
    
    /// @dev Interest rate model parameters
    uint256 public constant OPTIMAL_UTILIZATION = 8000; // 80%
    uint256 public constant BASE_RATE = 200; // 2%
    uint256 public constant SLOPE1 = 400; // 4%
    uint256 public constant SLOPE2 = 10000; // 100%
    
    /// @dev Active pool orders on CLOB
    uint256[] public activeOrders;
    mapping(uint256 => bool) public isPoolOrder;
    
    /// @dev User data
    mapping(address => uint256) public userBorrows;
    mapping(address => uint256) public userBorrowIndex;
    
    /// @dev Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event InterestRateUpdated(uint256 newSupplyRate, uint256 newBorrowRate);
    event ReservesUpdated(uint256 newReserveBalance);
    event OrderPlacedByPool(uint256 indexed orderId, uint256 amount, uint256 rate);
    
    /// @dev Custom errors
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InvalidConfiguration();
    error BorrowCapExceeded();
    error RepaymentFailed();
    
    constructor(
        address _underlyingAsset,
        address _clob,
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC20(_name, _symbol) Ownable(_owner) {
        underlyingAsset = _underlyingAsset;
        clob = LegosCLOB(_clob);
        lastUpdateTime = block.timestamp;
        
        // Initialize pool configuration
        poolConfig = PoolConfig({
            asset: _underlyingAsset,
            reserveFactor: 1000, // 10%
            baseRate: BASE_RATE,
            multiplier: SLOPE1,
            jumpMultiplier: SLOPE2,
            optimalUtilization: OPTIMAL_UTILIZATION,
            liquidationThreshold: 8500, // 85%
            liquidationPenalty: 500, // 5%
            isActive: true
        });
    }
    
    /**
     * @dev Deposit assets into the pool and receive pool tokens
     * @param amount The amount to deposit
     * @return shares The amount of pool tokens minted
     */
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        _updateInterest();
        
        uint256 totalPoolAssets = _getTotalPoolAssets();
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalPoolAssets;
        }
        
        // Transfer underlying asset
        IERC20(underlyingAsset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Mint pool tokens
        _mint(msg.sender, shares);
        
        emit Deposit(msg.sender, amount, shares);
        
        // Update pool orders on CLOB
        _updatePoolOrders();
    }
    
    /**
     * @dev Withdraw assets from the pool by burning pool tokens
     * @param shares The amount of pool tokens to burn
     * @return amount The amount of underlying assets withdrawn
     */
    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        _updateInterest();
        
        uint256 totalPoolAssets = _getTotalPoolAssets();
        amount = (shares * totalPoolAssets) / totalSupply();
        
        if (amount > _getAvailableLiquidity()) {
            revert InsufficientLiquidity();
        }
        
        // Burn pool tokens
        _burn(msg.sender, shares);
        
        // Transfer underlying asset
        IERC20(underlyingAsset).safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, amount, shares);
        
        // Update pool orders on CLOB
        _updatePoolOrders();
    }
    
    /**
     * @dev Borrow from the pool with collateral
     * @param amount The amount to borrow
     * @param collateralToken The collateral token
     * @param collateralAmount The collateral amount
     * @param duration The loan duration
     */
    function borrow(
        uint256 amount,
        address collateralToken,
        uint256 collateralAmount,
        uint256 duration
    ) external nonReentrant {
        _updateInterest();
        _updateUserBorrow(msg.sender);
        
        if (amount > _getAvailableLiquidity()) {
            revert InsufficientLiquidity();
        }
        
        // Validate collateral (simplified - should use oracle in production)
        uint256 requiredCollateral = (amount * 15000) / LegosMath.BASIS_POINTS; // 150% collateralization
        if (collateralAmount < requiredCollateral) {
            revert InsufficientCollateral();
        }
        
        // Transfer collateral
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // Update borrow state
        userBorrows[msg.sender] += amount;
        userBorrowIndex[msg.sender] = borrowIndex;
        totalBorrows += amount;
        
        // Transfer borrowed asset
        IERC20(underlyingAsset).safeTransfer(msg.sender, amount);
        
        emit Borrow(msg.sender, amount);
        
        // Update interest rates and pool orders
        _updatePoolOrders();
    }
    
    /**
     * @dev Repay a loan to the pool
     * @param amount The amount to repay
     */
    function repay(uint256 amount) external nonReentrant {
        _updateInterest();
        _updateUserBorrow(msg.sender);
        
        uint256 userDebt = userBorrows[msg.sender];
        if (amount > userDebt) {
            amount = userDebt;
        }
        
        // Transfer repayment
        IERC20(underlyingAsset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update borrow state
        userBorrows[msg.sender] -= amount;
        totalBorrows -= amount;
        
        emit Repay(msg.sender, amount);
        
        // Update pool orders
        _updatePoolOrders();
    }
    
    /**
     * @dev Get current supply APY
     */
    function getSupplyAPY() external view returns (uint256) {
        uint256 utilizationRate = _getCurrentUtilizationRate();
        uint256 borrowRate = _calculateBorrowRate(utilizationRate);
        return (borrowRate * utilizationRate * (LegosMath.BASIS_POINTS - poolConfig.reserveFactor)) / 
               (LegosMath.BASIS_POINTS * LegosMath.BASIS_POINTS);
    }
    
    /**
     * @dev Get current borrow APY
     */
    function getBorrowAPY() external view returns (uint256) {
        uint256 utilizationRate = _getCurrentUtilizationRate();
        return _calculateBorrowRate(utilizationRate);
    }
    
    /**
     * @dev Get available liquidity
     */
    function getAvailableLiquidity() external view returns (uint256) {
        return _getAvailableLiquidity();
    }
    
    /**
     * @dev Get total pool assets (deposits + accrued interest)
     */
    function getTotalPoolAssets() external view returns (uint256) {
        return _getTotalPoolAssets();
    }
    
    /**
     * @dev Get user's borrow balance with accrued interest
     */
    function getUserBorrowBalance(address user) external view returns (uint256) {
        if (userBorrows[user] == 0) return 0;
        
        uint256 currentBorrowIndex = _calculateNewBorrowIndex();
        return (userBorrows[user] * currentBorrowIndex) / userBorrowIndex[user];
    }
    
    /**
     * @dev Update interest rates and indices
     */
    function _updateInterest() internal {
        uint256 currentTime = block.timestamp;
        uint256 timeDelta = currentTime - lastUpdateTime;
        
        if (timeDelta == 0) return;
        
        uint256 utilizationRate = _getCurrentUtilizationRate();
        uint256 borrowRate = _calculateBorrowRate(utilizationRate);
        uint256 supplyRate = (borrowRate * utilizationRate * (LegosMath.BASIS_POINTS - poolConfig.reserveFactor)) / 
                            (LegosMath.BASIS_POINTS * LegosMath.BASIS_POINTS);
        
        // Update indices
        liquidityIndex = _calculateNewLiquidityIndex(supplyRate, timeDelta);
        borrowIndex = _calculateNewBorrowIndex();
        
        // Update reserves
        uint256 interestAccrued = totalBorrows * borrowRate * timeDelta / (LegosMath.BASIS_POINTS * LegosMath.SECONDS_PER_YEAR);
        uint256 reserveIncrease = (interestAccrued * poolConfig.reserveFactor) / LegosMath.BASIS_POINTS;
        reserveBalance += reserveIncrease;
        
        lastUpdateTime = currentTime;
        
        emit InterestRateUpdated(supplyRate, borrowRate);
        emit ReservesUpdated(reserveBalance);
    }
    
    /**
     * @dev Update user's borrow balance with accrued interest
     */
    function _updateUserBorrow(address user) internal {
        if (userBorrows[user] == 0) return;
        
        uint256 newBalance = (userBorrows[user] * borrowIndex) / userBorrowIndex[user];
        userBorrows[user] = newBalance;
        userBorrowIndex[user] = borrowIndex;
    }
    
    /**
     * @dev Update pool orders on the CLOB based on current utilization
     */
    function _updatePoolOrders() internal {
        // Cancel existing orders
        _cancelPoolOrders();
        
        uint256 availableLiquidity = _getAvailableLiquidity();
        if (availableLiquidity < 1e18) return; // Minimum order size
        
        uint256 currentRate = _getCurrentSupplyRate();
        
        // Place new lending order with current rate
        try clob.placeLendOrder(
            underlyingAsset,
            availableLiquidity,
            currentRate,
            30 days, // Default duration
            7500, // 75% max LTV
            underlyingAsset, // Accept same asset as collateral for simplicity
            block.timestamp + 7 days // 7 days expiry
        ) returns (uint256 orderId) {
            activeOrders.push(orderId);
            isPoolOrder[orderId] = true;
            
            emit OrderPlacedByPool(orderId, availableLiquidity, currentRate);
        } catch {
            // Order placement failed, continue
        }
    }
    
    /**
     * @dev Cancel all active pool orders
     */
    function _cancelPoolOrders() internal {
        for (uint256 i = 0; i < activeOrders.length; i++) {
            try clob.cancelOrder(activeOrders[i]) {
                // Order cancelled successfully
            } catch {
                // Order cancellation failed, continue
            }
        }
        
        // Clear active orders array
        delete activeOrders;
    }
    
    /**
     * @dev Calculate current utilization rate
     */
    function _getCurrentUtilizationRate() internal view returns (uint256) {
        uint256 totalAssets = _getTotalPoolAssets();
        if (totalAssets == 0) return 0;
        return (totalBorrows * LegosMath.BASIS_POINTS) / totalAssets;
    }
    
    /**
     * @dev Calculate borrow rate based on utilization
     */
    function _calculateBorrowRate(uint256 utilizationRate) internal view returns (uint256) {
        return LegosMath.calculateInterestRate(
            utilizationRate,
            poolConfig.baseRate,
            poolConfig.multiplier,
            poolConfig.jumpMultiplier,
            poolConfig.optimalUtilization
        );
    }
    
    /**
     * @dev Get current supply rate
     */
    function _getCurrentSupplyRate() internal view returns (uint256) {
        uint256 utilizationRate = _getCurrentUtilizationRate();
        uint256 borrowRate = _calculateBorrowRate(utilizationRate);
        return (borrowRate * utilizationRate * (LegosMath.BASIS_POINTS - poolConfig.reserveFactor)) / 
               (LegosMath.BASIS_POINTS * LegosMath.BASIS_POINTS);
    }
    
    /**
     * @dev Calculate new liquidity index
     */
    function _calculateNewLiquidityIndex(uint256 supplyRate, uint256 timeDelta) internal view returns (uint256) {
        uint256 cumulatedInterest = LegosMath.calculateCompoundInterest(
            LegosMath.RAY,
            supplyRate,
            timeDelta
        );
        return LegosMath.rayMul(liquidityIndex, cumulatedInterest);
    }
    
    /**
     * @dev Calculate new borrow index
     */
    function _calculateNewBorrowIndex() internal view returns (uint256) {
        uint256 utilizationRate = _getCurrentUtilizationRate();
        uint256 borrowRate = _calculateBorrowRate(utilizationRate);
        uint256 timeDelta = block.timestamp - lastUpdateTime;
        
        uint256 cumulatedInterest = LegosMath.calculateCompoundInterest(
            LegosMath.RAY,
            borrowRate,
            timeDelta
        );
        return LegosMath.rayMul(borrowIndex, cumulatedInterest);
    }
    
    /**
     * @dev Get total pool assets
     */
    function _getTotalPoolAssets() internal view returns (uint256) {
        return IERC20(underlyingAsset).balanceOf(address(this)) + totalBorrows - reserveBalance;
    }
    
    /**
     * @dev Get available liquidity for lending
     */
    function _getAvailableLiquidity() internal view returns (uint256) {
        uint256 balance = IERC20(underlyingAsset).balanceOf(address(this));
        return balance > reserveBalance ? balance - reserveBalance : 0;
    }
} 