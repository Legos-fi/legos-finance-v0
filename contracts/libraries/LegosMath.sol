// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LegosMath
 * @dev Mathematical library for Legos Finance Protocol calculations
 * Includes interest rate calculations, LTV ratios, liquidation logic, and utilization rates
 */
library LegosMath {
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RAY = 1e27;
    uint256 public constant HALF_RAY = RAY / 2;
    
    /// @dev Custom errors
    error DivisionByZero();
    error Overflow();
    error InvalidBasisPoints();
    
    /**
     * @dev Calculates compound interest using the formula: A = P(1 + r/n)^(nt)
     * @param principal The principal amount
     * @param rate The annual interest rate in basis points
     * @param timeElapsed Time elapsed in seconds
     * @return The total amount including interest
     */
    function calculateCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || rate == 0 || timeElapsed == 0) {
            return principal;
        }
        
        // Convert rate from basis points to ray precision
        uint256 ratePerSecond = (rate * RAY) / (BASIS_POINTS * SECONDS_PER_YEAR);
        
        // Calculate compound interest using ray math for precision
        uint256 compoundFactor = rayPow(RAY + ratePerSecond, timeElapsed);
        
        return (principal * compoundFactor) / RAY;
    }
    
    /**
     * @dev Calculates simple interest: Interest = P * r * t
     * @param principal The principal amount
     * @param rate The annual interest rate in basis points
     * @param timeElapsed Time elapsed in seconds
     * @return The interest amount
     */
    function calculateSimpleInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || rate == 0 || timeElapsed == 0) {
            return 0;
        }
        
        return (principal * rate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
    }
    
    /**
     * @dev Calculates the current LTV ratio
     * @param loanAmount The current loan amount
     * @param collateralValue The current collateral value
     * @return The LTV ratio in basis points
     */
    function calculateLTV(
        uint256 loanAmount,
        uint256 collateralValue
    ) internal pure returns (uint256) {
        if (collateralValue == 0) {
            revert DivisionByZero();
        }
        
        return (loanAmount * BASIS_POINTS) / collateralValue;
    }
    
    /**
     * @dev Calculates the health factor of a position
     * @param collateralValue The collateral value in USD
     * @param borrowedAmount The borrowed amount in USD
     * @param liquidationThreshold The liquidation threshold in basis points
     * @return The health factor (1e18 = 100%)
     */
    function calculateHealthFactor(
        uint256 collateralValue,
        uint256 borrowedAmount,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {
        if (borrowedAmount == 0) {
            return type(uint256).max; // Infinite health factor
        }
        
        uint256 adjustedCollateral = (collateralValue * liquidationThreshold) / BASIS_POINTS;
        return (adjustedCollateral * 1e18) / borrowedAmount;
    }
    
    /**
     * @dev Calculates utilization rate for a lending pool
     * @param totalBorrows Total borrowed amount
     * @param totalSupply Total supplied amount
     * @return The utilization rate in basis points
     */
    function calculateUtilizationRate(
        uint256 totalBorrows,
        uint256 totalSupply
    ) internal pure returns (uint256) {
        if (totalSupply == 0) {
            return 0;
        }
        
        return (totalBorrows * BASIS_POINTS) / totalSupply;
    }
    
    /**
     * @dev Calculates the interest rate based on utilization using a kinked rate model
     * @param utilizationRate The current utilization rate in basis points
     * @param baseRate Base interest rate in basis points
     * @param multiplier Rate multiplier in basis points
     * @param jumpMultiplier Jump multiplier for high utilization in basis points
     * @param optimalUtilization Optimal utilization threshold in basis points
     * @return The interest rate in basis points
     */
    function calculateInterestRate(
        uint256 utilizationRate,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 optimalUtilization
    ) internal pure returns (uint256) {
        if (utilizationRate <= optimalUtilization) {
            // Below optimal utilization: rate = base + (utilization * multiplier / optimal)
            return baseRate + (utilizationRate * multiplier) / optimalUtilization;
        } else {
            // Above optimal utilization: rate = base + multiplier + excess * jumpMultiplier
            uint256 normalRate = baseRate + multiplier;
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 maxExcess = BASIS_POINTS - optimalUtilization;
            
            return normalRate + (excessUtilization * jumpMultiplier) / maxExcess;
        }
    }
    
    /**
     * @dev Calculates the maximum borrowable amount given collateral
     * @param collateralValue The collateral value
     * @param maxLTV The maximum loan-to-value ratio in basis points
     * @return The maximum borrowable amount
     */
    function calculateMaxBorrow(
        uint256 collateralValue,
        uint256 maxLTV
    ) internal pure returns (uint256) {
        return (collateralValue * maxLTV) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculates liquidation amounts
     * @param debtAmount The total debt amount
     * @param collateralAmount The collateral amount
     * @param liquidationPenalty The liquidation penalty in basis points
     * @return debtToCover The amount of debt to cover
     * @return collateralToSeize The amount of collateral to seize
     */
    function calculateLiquidation(
        uint256 debtAmount,
        uint256 collateralAmount,
        uint256 liquidationPenalty
    ) internal pure returns (uint256 debtToCover, uint256 collateralToSeize) {
        // In a partial liquidation, we typically liquidate up to 50% of the debt
        debtToCover = debtAmount / 2;
        
        // Calculate collateral to seize with penalty
        collateralToSeize = (debtToCover * (BASIS_POINTS + liquidationPenalty)) / BASIS_POINTS;
        
        // Ensure we don't seize more collateral than available
        if (collateralToSeize > collateralAmount) {
            collateralToSeize = collateralAmount;
            // Adjust debt to cover based on available collateral
            debtToCover = (collateralAmount * BASIS_POINTS) / (BASIS_POINTS + liquidationPenalty);
        }
    }
    
    /**
     * @dev Ray math operations for high precision calculations
     */
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }
        
        return (a * b + HALF_RAY) / RAY;
    }
    
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            revert DivisionByZero();
        }
        
        return (a * RAY + b / 2) / b;
    }
    
    /**
     * @dev Calculates a^n using binary exponentiation for ray precision
     */
    function rayPow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        if (exponent == 0) {
            return RAY;
        }
        
        uint256 result = RAY;
        uint256 currentBase = base;
        
        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = rayMul(result, currentBase);
            }
            currentBase = rayMul(currentBase, currentBase);
            exponent >>= 1;
        }
        
        return result;
    }
    
    /**
     * @dev Validates that a value is within basis points range
     */
    function validateBasisPoints(uint256 value) internal pure {
        if (value > BASIS_POINTS) {
            revert InvalidBasisPoints();
        }
    }
    
    /**
     * @dev Safe percentage calculation
     */
    function percentageOf(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        validateBasisPoints(percentage);
        return (amount * percentage) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculates the weighted average of two values
     */
    function weightedAverage(
        uint256 value1,
        uint256 weight1,
        uint256 value2,
        uint256 weight2
    ) internal pure returns (uint256) {
        uint256 totalWeight = weight1 + weight2;
        if (totalWeight == 0) {
            return 0;
        }
        
        return (value1 * weight1 + value2 * weight2) / totalWeight;
    }
} 