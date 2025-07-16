// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ILegosCore.sol";
import "../libraries/LegosMath.sol";
import "./LegosCLOB.sol";

/**
 * @title LegosRiskManager
 * @dev Risk management and liquidation contract for Legos Finance Protocol
 * Monitors loan health, calculates risk metrics, and executes liquidations
 */
contract LegosRiskManager is ILegosCore, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using LegosMath for uint256;
    
    /// @dev Protocol contracts
    LegosCLOB public immutable clob;
    
    /// @dev Risk parameters
    mapping(address => RiskParameters) public assetRiskParams;
    mapping(address => uint256) public assetPrices; // Simplified price feed
    mapping(uint256 => uint256) public loanHealthFactors;
    
    /// @dev Liquidation parameters
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18; // 100%
    uint256 public constant MAX_LIQUIDATION_CLOSE_FACTOR = 5000; // 50%
    uint256 public constant LIQUIDATION_INCENTIVE = 500; // 5%
    uint256 public constant PRICE_DEVIATION_THRESHOLD = 500; // 5%
    
    /// @dev Liquidator incentives
    mapping(address => uint256) public liquidatorRewards;
    uint256 public totalLiquidatorRewards;
    
    /// @dev Risk monitoring state
    mapping(uint256 => uint256) public lastHealthCheckTime;
    uint256 public healthCheckInterval = 1 hours;
    uint256[] public riskLoans; // Loans that need monitoring
    
    /// @dev Events
    event RiskParametersUpdated(address indexed asset, RiskParameters params);
    event PriceUpdated(address indexed asset, uint256 newPrice);
    event HealthFactorUpdated(uint256 indexed loanId, uint256 healthFactor);
    event LiquidationTriggered(uint256 indexed loanId, address indexed liquidator, uint256 debtCovered, uint256 collateralSeized);
    event LiquidatorRewardClaimed(address indexed liquidator, uint256 amount);
    event RiskLoanAdded(uint256 indexed loanId);
    event RiskLoanRemoved(uint256 indexed loanId);
    
    /// @dev Custom errors
    error InvalidRiskParameters();
    error HealthyPosition();
    error InsufficientCollateral();
    error InvalidLiquidationAmount();
    error UnauthorizedLiquidator();
    error PriceStale();
    error InvalidPrice();
    
    constructor(address _clob, address _owner) Ownable(_owner) {
        clob = LegosCLOB(_clob);
    }
    
    /**
     * @dev Set risk parameters for an asset
     * @param asset The asset address
     * @param params Risk parameters
     */
    function setAssetRiskParameters(address asset, RiskParameters memory params) external onlyOwner {
        if (params.maxLTV > params.liquidationThreshold || 
            params.liquidationThreshold > LegosMath.BASIS_POINTS ||
            params.liquidationPenalty > LegosMath.BASIS_POINTS) {
            revert InvalidRiskParameters();
        }
        
        assetRiskParams[asset] = params;
        emit RiskParametersUpdated(asset, params);
    }
    
    /**
     * @dev Update asset price (simplified price oracle)
     * @param asset The asset address
     * @param price The new price in USD (scaled by 1e18)
     */
    function updateAssetPrice(address asset, uint256 price) external onlyOwner {
        if (price == 0) revert InvalidPrice();
        
        uint256 oldPrice = assetPrices[asset];
        assetPrices[asset] = price;
        
        // Check for significant price deviation
        if (oldPrice > 0) {
            uint256 deviation = oldPrice > price 
                ? ((oldPrice - price) * LegosMath.BASIS_POINTS) / oldPrice
                : ((price - oldPrice) * LegosMath.BASIS_POINTS) / oldPrice;
                
            if (deviation > PRICE_DEVIATION_THRESHOLD) {
                // Trigger risk assessment for all loans
                _triggerRiskAssessment();
            }
        }
        
        emit PriceUpdated(asset, price);
    }
    
    /**
     * @dev Calculate health factor for a loan
     * @param loanId The loan ID
     * @return healthFactor The health factor (1e18 = 100%)
     */
    function calculateHealthFactor(uint256 loanId) public view returns (uint256 healthFactor) {
        (, , , , uint256 remainingPrincipal, , , , , address collateralToken, uint256 collateralAmount, uint256 accruedInterest, ) = clob.loans(loanId);
        
        uint256 totalDebt = remainingPrincipal + accruedInterest;
        uint256 collateralValue = _getAssetValue(collateralToken, collateralAmount);
        
        RiskParameters memory riskParams = assetRiskParams[collateralToken];
        
        healthFactor = LegosMath.calculateHealthFactor(
            collateralValue,
            totalDebt,
            riskParams.liquidationThreshold
        );
    }
    
    /**
     * @dev Check if a loan is eligible for liquidation
     * @param loanId The loan ID
     * @return isEligible Whether the loan can be liquidated
     */
    function isLiquidationEligible(uint256 loanId) public view returns (bool isEligible) {
        uint256 healthFactor = calculateHealthFactor(loanId);
        return healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }
    
    /**
     * @dev Liquidate an undercollateralized loan
     * @param loanId The loan ID to liquidate
     * @param debtToCover The amount of debt to cover
     */
    function liquidateLoan(uint256 loanId, uint256 debtToCover) external nonReentrant {
        if (!isLiquidationEligible(loanId)) {
            revert HealthyPosition();
        }
        
        (, , address borrower, , uint256 remainingPrincipal, , , , , address collateralToken, uint256 collateralAmount, uint256 accruedInterest, LoanStatus status) = clob.loans(loanId);
        
        if (status != LoanStatus.ACTIVE) {
            revert InvalidLiquidationAmount();
        }
        
        uint256 totalDebt = remainingPrincipal + accruedInterest;
        
        // Limit liquidation to maximum close factor
        uint256 maxDebtToCover = (totalDebt * MAX_LIQUIDATION_CLOSE_FACTOR) / LegosMath.BASIS_POINTS;
        if (debtToCover > maxDebtToCover) {
            debtToCover = maxDebtToCover;
        }
        
        // Calculate collateral to seize
        RiskParameters memory riskParams = assetRiskParams[collateralToken];
        (uint256 actualDebtToCover, uint256 collateralToSeize) = LegosMath.calculateLiquidation(
            debtToCover,
            collateralAmount,
            riskParams.liquidationPenalty
        );
        
        // Transfer debt payment from liquidator
        IERC20 debtAsset = IERC20(_getLoanAsset(loanId));
        debtAsset.safeTransferFrom(msg.sender, address(this), actualDebtToCover);
        
        // Transfer collateral to liquidator
        IERC20(collateralToken).safeTransfer(msg.sender, collateralToSeize);
        
        // Calculate liquidator reward
        uint256 liquidatorReward = (collateralToSeize * LIQUIDATION_INCENTIVE) / LegosMath.BASIS_POINTS;
        liquidatorRewards[msg.sender] += liquidatorReward;
        totalLiquidatorRewards += liquidatorReward;
        
        // Update loan state
        _updateLoanAfterLiquidation(loanId, actualDebtToCover, collateralToSeize);
        
        // Remove from risk monitoring if fully liquidated
        if (remainingPrincipal <= actualDebtToCover) {
            _removeFromRiskMonitoring(loanId);
        }
        
        emit LiquidationTriggered(loanId, msg.sender, actualDebtToCover, collateralToSeize);
    }
    
    /**
     * @dev Claim liquidator rewards
     */
    function claimLiquidatorRewards() external nonReentrant {
        uint256 reward = liquidatorRewards[msg.sender];
        if (reward == 0) return;
        
        liquidatorRewards[msg.sender] = 0;
        totalLiquidatorRewards -= reward;
        
        // Transfer reward (this would need to be funded by protocol fees)
        payable(msg.sender).transfer(reward);
        
        emit LiquidatorRewardClaimed(msg.sender, reward);
    }
    
    /**
     * @dev Perform health check on all risk loans
     */
    function performHealthCheck() external {
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 loanId = riskLoans[i];
            
            if (currentTime - lastHealthCheckTime[loanId] >= healthCheckInterval) {
                uint256 healthFactor = calculateHealthFactor(loanId);
                loanHealthFactors[loanId] = healthFactor;
                lastHealthCheckTime[loanId] = currentTime;
                
                emit HealthFactorUpdated(loanId, healthFactor);
                
                // Auto-liquidate if severely undercollateralized
                if (healthFactor < (HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 80) / 100) { // 80% of threshold
                    _autoLiquidate(loanId);
                }
            }
        }
    }
    
    /**
     * @dev Add a loan to risk monitoring
     * @param loanId The loan ID to monitor
     */
    function addToRiskMonitoring(uint256 loanId) external {
        // In production, this should be called by the CLOB contract
        riskLoans.push(loanId);
        lastHealthCheckTime[loanId] = block.timestamp;
        
        emit RiskLoanAdded(loanId);
    }
    
    /**
     * @dev Get loans at risk of liquidation
     * @return atRiskLoans Array of loan IDs with health factor < 1.2
     */
    function getLoansAtRisk() external view returns (uint256[] memory atRiskLoans) {
        uint256 count = 0;
        
        // First pass: count at-risk loans
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 healthFactor = calculateHealthFactor(riskLoans[i]);
            if (healthFactor < 1.2e18) { // 120% threshold
                count++;
            }
        }
        
        // Second pass: populate array
        atRiskLoans = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 healthFactor = calculateHealthFactor(riskLoans[i]);
            if (healthFactor < 1.2e18) {
                atRiskLoans[index] = riskLoans[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Get total value at risk across all loans
     * @return totalVaR Total value at risk in USD
     */
    function getTotalValueAtRisk() external view returns (uint256 totalVaR) {
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 loanId = riskLoans[i];
            (, , , , uint256 remainingPrincipal, , , , , address collateralToken, uint256 collateralAmount, uint256 accruedInterest, ) = clob.loans(loanId);
            
            uint256 totalDebt = remainingPrincipal + accruedInterest;
            uint256 collateralValue = _getAssetValue(collateralToken, collateralAmount);
            
            if (collateralValue < totalDebt) {
                totalVaR += (totalDebt - collateralValue);
            }
        }
    }
    
    /**
     * @dev Get risk metrics for the protocol
     * @return totalLoans Total number of loans being monitored
     * @return loansAtRisk Number of loans with health factor < 1.2
     * @return avgHealthFactor Average health factor across all loans
     */
    function getRiskMetrics() external view returns (
        uint256 totalLoans,
        uint256 loansAtRisk,
        uint256 avgHealthFactor
    ) {
        totalLoans = riskLoans.length;
        uint256 totalHealthFactor = 0;
        
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 healthFactor = calculateHealthFactor(riskLoans[i]);
            totalHealthFactor += healthFactor;
            
            if (healthFactor < 1.2e18) {
                loansAtRisk++;
            }
        }
        
        avgHealthFactor = totalLoans > 0 ? totalHealthFactor / totalLoans : 0;
    }
    
    /**
     * @dev Update health check interval
     * @param newInterval New interval in seconds
     */
    function updateHealthCheckInterval(uint256 newInterval) external onlyOwner {
        healthCheckInterval = newInterval;
    }
    
    /**
     * @dev Internal function to auto-liquidate severely undercollateralized loans
     */
    function _autoLiquidate(uint256 loanId) internal {
        (, , , , uint256 remainingPrincipal, , , , , , , uint256 accruedInterest, ) = clob.loans(loanId);
        uint256 totalDebt = remainingPrincipal + accruedInterest;
        
        // Calculate maximum liquidation amount
        uint256 debtToCover = (totalDebt * MAX_LIQUIDATION_CLOSE_FACTOR) / LegosMath.BASIS_POINTS;
        
        // This would need to be implemented with a liquidation bot or keeper network
        // For now, just emit an event for external liquidators
        emit LiquidationTriggered(loanId, address(0), debtToCover, 0);
    }
    
    /**
     * @dev Remove loan from risk monitoring
     */
    function _removeFromRiskMonitoring(uint256 loanId) internal {
        for (uint256 i = 0; i < riskLoans.length; i++) {
            if (riskLoans[i] == loanId) {
                riskLoans[i] = riskLoans[riskLoans.length - 1];
                riskLoans.pop();
                delete lastHealthCheckTime[loanId];
                delete loanHealthFactors[loanId];
                
                emit RiskLoanRemoved(loanId);
                break;
            }
        }
    }
    
    /**
     * @dev Trigger risk assessment for all loans
     */
    function _triggerRiskAssessment() internal {
        for (uint256 i = 0; i < riskLoans.length; i++) {
            uint256 loanId = riskLoans[i];
            uint256 healthFactor = calculateHealthFactor(loanId);
            loanHealthFactors[loanId] = healthFactor;
            
            emit HealthFactorUpdated(loanId, healthFactor);
        }
    }
    
    /**
     * @dev Update loan state after liquidation
     */
    function _updateLoanAfterLiquidation(
        uint256 loanId,
        uint256 debtCovered,
        uint256 collateralSeized
    ) internal {
        // This would need to interact with the CLOB contract to update loan state
        // For now, just update our internal tracking
        uint256 healthFactor = calculateHealthFactor(loanId);
        loanHealthFactors[loanId] = healthFactor;
    }
    
    /**
     * @dev Get asset value in USD
     */
    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = assetPrices[asset];
        if (price == 0) return 0;
        
        return (amount * price) / 1e18;
    }
    
    /**
     * @dev Get the asset address for a loan (simplified)
     */
    function _getLoanAsset(uint256 loanId) internal pure returns (address) {
        // This would need to be implemented based on the CLOB contract structure
        // For now, return a placeholder
        return address(0);
    }
    
    /**
     * @dev Emergency pause function
     */
    function pause() external onlyOwner {
        // Implementation for emergency pause
    }
    
    /**
     * @dev Unpause function
     */
    function unpause() external onlyOwner {
        // Implementation for unpause
    }
} 