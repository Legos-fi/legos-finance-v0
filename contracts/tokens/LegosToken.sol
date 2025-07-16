// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LegosToken
 * @dev Governance token for Legos Finance Protocol
 * Features voting capabilities, burning, and staking rewards
 */
contract LegosToken is ERC20, ERC20Burnable, ERC20Votes, ERC20Permit, Ownable, ReentrancyGuard {
    /// @dev Tokenomics parameters
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 100 million tokens (10%)
    
    /// @dev Distribution allocations
    uint256 public constant TEAM_ALLOCATION = 200_000_000 * 10**18; // 20%
    uint256 public constant TREASURY_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant LIQUIDITY_MINING_ALLOCATION = 300_000_000 * 10**18; // 30%
    uint256 public constant COMMUNITY_ALLOCATION = 250_000_000 * 10**18; // 25%
    
    /// @dev Vesting parameters
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revoked;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public isVestingBeneficiary;
    address[] public vestingBeneficiaries;
    
    /// @dev Staking for governance
    struct StakingInfo {
        uint256 stakedAmount;
        uint256 stakingStartTime;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }
    
    mapping(address => StakingInfo) public stakingInfo;
    uint256 public totalStaked;
    uint256 public stakingRewardRate = 100; // 1% per year in basis points
    uint256 public constant STAKING_REWARD_PRECISION = 10000;
    
    /// @dev Treasury and distribution addresses
    address public treasury;
    address public liquidityMining;
    address public communityRewards;
    
    /// @dev Minting controls
    bool public mintingFinished = false;
    uint256 public totalMinted;
    
    /// @dev Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount, uint256 startTime, uint256 duration);
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event StakingRewardsClaimed(address indexed user, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    event MintingFinished();
    
    /// @dev Custom errors
    error MaxSupplyExceeded();
    error MintingAlreadyFinished();
    error VestingNotStarted();
    error NoTokensToVest();
    error VestingAlreadyRevoked();
    error InsufficientStakedAmount();
    error NoStakingRewards();
    error InvalidAddress();
    
    constructor(
        address _treasury,
        address _liquidityMining,
        address _communityRewards,
        address _owner
    ) 
        ERC20("Legos Finance Token", "LEGOS")
        ERC20Permit("Legos Finance Token")
        Ownable(_owner)
    {
        if (_treasury == address(0) || _liquidityMining == address(0) || 
            _communityRewards == address(0) || _owner == address(0)) {
            revert InvalidAddress();
        }
        
        treasury = _treasury;
        liquidityMining = _liquidityMining;
        communityRewards = _communityRewards;
        
        // Mint initial supply to deployer for distribution
        _mint(_owner, INITIAL_SUPPLY);
        totalMinted = INITIAL_SUPPLY;
    }
    
    /**
     * @dev Create vesting schedule for team/advisors
     * @param beneficiary The beneficiary address
     * @param amount Total amount to vest
     * @param startTime Vesting start time
     * @param cliffDuration Cliff period in seconds
     * @param vestingDuration Total vesting duration in seconds
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        if (beneficiary == address(0)) revert InvalidAddress();
        if (totalMinted + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        if (vestingSchedules[beneficiary].totalAmount > 0) {
            revert("Vesting schedule already exists");
        }
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revoked: false
        });
        
        if (!isVestingBeneficiary[beneficiary]) {
            isVestingBeneficiary[beneficiary] = true;
            vestingBeneficiaries.push(beneficiary);
        }
        
        // Mint tokens to contract for vesting
        _mint(address(this), amount);
        totalMinted += amount;
        
        emit VestingScheduleCreated(beneficiary, amount, startTime, vestingDuration);
    }
    
    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external nonReentrant {
        uint256 vestedAmount = getVestedAmount(msg.sender);
        if (vestedAmount == 0) revert NoTokensToVest();
        
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        schedule.releasedAmount += vestedAmount;
        
        _transfer(address(this), msg.sender, vestedAmount);
        
        emit TokensVested(msg.sender, vestedAmount);
    }
    
    /**
     * @dev Get vested amount for a beneficiary
     * @param beneficiary The beneficiary address
     * @return vestedAmount The amount available to claim
     */
    function getVestedAmount(address beneficiary) public view returns (uint256 vestedAmount) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        
        if (schedule.revoked || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        uint256 elapsedTime = block.timestamp - schedule.startTime;
        
        if (elapsedTime >= schedule.vestingDuration) {
            vestedAmount = schedule.totalAmount - schedule.releasedAmount;
        } else {
            uint256 totalVested = (schedule.totalAmount * elapsedTime) / schedule.vestingDuration;
            vestedAmount = totalVested - schedule.releasedAmount;
        }
    }
    
    /**
     * @dev Revoke vesting schedule (only owner)
     * @param beneficiary The beneficiary address
     */
    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.revoked) revert VestingAlreadyRevoked();
        
        // Transfer unvested tokens back to treasury
        uint256 vestedAmount = getVestedAmount(beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount - vestedAmount;
        
        if (unvestedAmount > 0) {
            _transfer(address(this), treasury, unvestedAmount);
        }
        
        schedule.revoked = true;
        
        emit VestingRevoked(beneficiary);
    }
    
    /**
     * @dev Stake tokens for governance voting power
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert("Cannot stake zero tokens");
        
        _updateStakingRewards(msg.sender);
        
        stakingInfo[msg.sender].stakedAmount += amount;
        stakingInfo[msg.sender].stakingStartTime = block.timestamp;
        totalStaked += amount;
        
        _transfer(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev Unstake tokens
     * @param amount Amount to unstake
     */
    function unstake(uint256 amount) external nonReentrant {
        if (stakingInfo[msg.sender].stakedAmount < amount) {
            revert InsufficientStakedAmount();
        }
        
        _updateStakingRewards(msg.sender);
        
        stakingInfo[msg.sender].stakedAmount -= amount;
        totalStaked -= amount;
        
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev Claim staking rewards
     */
    function claimStakingRewards() external nonReentrant {
        _updateStakingRewards(msg.sender);
        
        uint256 rewards = stakingInfo[msg.sender].pendingRewards;
        if (rewards == 0) revert NoStakingRewards();
        
        stakingInfo[msg.sender].pendingRewards = 0;
        
        // Mint rewards (up to max supply)
        if (totalMinted + rewards <= MAX_SUPPLY) {
            _mint(msg.sender, rewards);
            totalMinted += rewards;
        }
        
        emit StakingRewardsClaimed(msg.sender, rewards);
    }
    
    /**
     * @dev Update staking rewards for a user
     */
    function _updateStakingRewards(address user) internal {
        StakingInfo storage info = stakingInfo[user];
        
        if (info.stakedAmount > 0) {
            uint256 timeStaked = block.timestamp - info.stakingStartTime;
            uint256 rewards = (info.stakedAmount * stakingRewardRate * timeStaked) / 
                             (365 days * STAKING_REWARD_PRECISION);
            
            info.pendingRewards += rewards;
            info.rewardDebt = rewards;
            info.stakingStartTime = block.timestamp;
        }
    }
    
    /**
     * @dev Get pending staking rewards
     * @param user The user address
     * @return rewards Pending staking rewards
     */
    function getPendingStakingRewards(address user) external view returns (uint256 rewards) {
        StakingInfo memory info = stakingInfo[user];
        
        if (info.stakedAmount > 0) {
            uint256 timeStaked = block.timestamp - info.stakingStartTime;
            rewards = info.pendingRewards + 
                     ((info.stakedAmount * stakingRewardRate * timeStaked) / 
                      (365 days * STAKING_REWARD_PRECISION));
        }
    }
    
    /**
     * @dev Distribute allocated tokens to respective contracts
     */
    function distributeAllocations() external onlyOwner {
        if (mintingFinished) revert MintingAlreadyFinished();
        
        // Mint to treasury
        _mint(treasury, TREASURY_ALLOCATION);
        
        // Mint to liquidity mining contract
        _mint(liquidityMining, LIQUIDITY_MINING_ALLOCATION);
        
        // Mint to community rewards
        _mint(communityRewards, COMMUNITY_ALLOCATION);
        
        totalMinted += TREASURY_ALLOCATION + LIQUIDITY_MINING_ALLOCATION + COMMUNITY_ALLOCATION;
        
        // Note: Team allocation will be handled through vesting schedules
    }
    
    /**
     * @dev Finish minting (permanent action)
     */
    function finishMinting() external onlyOwner {
        mintingFinished = true;
        emit MintingFinished();
    }
    
    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
    
    /**
     * @dev Update staking reward rate
     * @param newRate New reward rate in basis points
     */
    function updateStakingRewardRate(uint256 newRate) external onlyOwner {
        stakingRewardRate = newRate;
    }
    
    /**
     * @dev Get voting power (includes both balance and staked amount)
     * @param account The account address
     * @return votingPower Total voting power
     */
    function getVotingPower(address account) external view returns (uint256 votingPower) {
        return balanceOf(account) + stakingInfo[account].stakedAmount;
    }
    
    /**
     * @dev Get all vesting beneficiaries
     * @return beneficiaries Array of beneficiary addresses
     */
    function getVestingBeneficiaries() external view returns (address[] memory) {
        return vestingBeneficiaries;
    }
    
    /**
     * @dev Override functions for ERC20Votes compatibility
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
    
    /**
     * @dev Override nonces for permit functionality
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
} 