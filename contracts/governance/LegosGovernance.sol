// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ILegosCore.sol";

/**
 * @title LegosGovernance
 * @dev Governance contract for Legos Finance Protocol
 * Allows token holders to vote on protocol parameters, asset listings, and other critical decisions
 */
contract LegosGovernance is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    ILegosCore
{
    /// @dev Governance parameters
    uint48 public constant VOTING_DELAY = 1 days; // 1 day
    uint32 public constant VOTING_PERIOD = 7 days; // 1 week
    uint256 public constant PROPOSAL_THRESHOLD = 1e20; // 100 tokens with 18 decimals
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%
    uint256 public constant TIMELOCK_DELAY = 2 days; // 2 days
    
    /// @dev Protocol contracts
    mapping(address => bool) public authorizedContracts;
    
    /// @dev Proposal types
    enum ProposalType {
        PARAMETER_UPDATE,
        ASSET_LISTING,
        RISK_PARAMETER_UPDATE,
        PROTOCOL_UPGRADE,
        TREASURY_MANAGEMENT,
        EMERGENCY_ACTION
    }
    
    /// @dev Proposal metadata
    struct ProposalMetadata {
        ProposalType proposalType;
        string title;
        string description;
        address target;
        uint256 value;
        bytes data;
        uint256 executionTime;
        bool executed;
    }
    
    mapping(uint256 => ProposalMetadata) public proposalMetadata;
    
    /// @dev Events
    event ProposalCreatedWithMetadata(
        uint256 indexed proposalId,
        ProposalType proposalType,
        string title,
        string description
    );
    event ParameterUpdated(string parameter, uint256 oldValue, uint256 newValue);
    event AssetListed(address indexed asset, string symbol);
    event RiskParametersUpdated(address indexed asset, RiskParameters params);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event EmergencyActionExecuted(address indexed target, bytes data);
    
    /// @dev Custom errors
    error UnauthorizedContract();
    error InvalidProposalType();
    error ProposalAlreadyExecuted();
    error InvalidParameter();
    
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("LegosGovernance")
        GovernorSettings(
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(QUORUM_PERCENTAGE)
        GovernorTimelockControl(_timelock)
    {}
    
    /**
     * @dev Create a proposal to update protocol parameters
     * @param target The target contract address
     * @param data The encoded function call
     * @param title The proposal title
     * @param description The proposal description
     */
    function proposeParameterUpdate(
        address target,
        bytes memory data,
        string memory title,
        string memory description
    ) external returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = target;
        values[0] = 0;
        calldatas[0] = data;
        
        proposalId = propose(targets, values, calldatas, description);
        
        proposalMetadata[proposalId] = ProposalMetadata({
            proposalType: ProposalType.PARAMETER_UPDATE,
            title: title,
            description: description,
            target: target,
            value: 0,
            data: data,
            executionTime: 0,
            executed: false
        });
        
        emit ProposalCreatedWithMetadata(proposalId, ProposalType.PARAMETER_UPDATE, title, description);
    }
    
    /**
     * @dev Create a proposal to list a new asset
     * @param asset The asset address to list
     * @param riskParams Risk parameters for the asset
     * @param title The proposal title
     * @param description The proposal description
     */
    function proposeAssetListing(
        address asset,
        RiskParameters memory riskParams,
        string memory title,
        string memory description
    ) external returns (uint256 proposalId) {
        bytes memory data = abi.encodeWithSignature(
            "listAsset(address,(uint256,uint256,uint256,uint256,bool))",
            asset,
            riskParams
        );
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(this); // Self-call for asset listing
        values[0] = 0;
        calldatas[0] = data;
        
        proposalId = propose(targets, values, calldatas, description);
        
        proposalMetadata[proposalId] = ProposalMetadata({
            proposalType: ProposalType.ASSET_LISTING,
            title: title,
            description: description,
            target: asset,
            value: 0,
            data: data,
            executionTime: 0,
            executed: false
        });
        
        emit ProposalCreatedWithMetadata(proposalId, ProposalType.ASSET_LISTING, title, description);
    }
    
    /**
     * @dev Create a proposal for emergency action
     * @param target The target contract
     * @param data The emergency action data
     * @param title The proposal title
     * @param description The proposal description
     */
    function proposeEmergencyAction(
        address target,
        bytes memory data,
        string memory title,
        string memory description
    ) external returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = target;
        values[0] = 0;
        calldatas[0] = data;
        
        proposalId = propose(targets, values, calldatas, description);
        
        proposalMetadata[proposalId] = ProposalMetadata({
            proposalType: ProposalType.EMERGENCY_ACTION,
            title: title,
            description: description,
            target: target,
            value: 0,
            data: data,
            executionTime: 0,
            executed: false
        });
        
        emit ProposalCreatedWithMetadata(proposalId, ProposalType.EMERGENCY_ACTION, title, description);
    }
    
    /**
     * @dev Create a proposal for treasury management
     * @param target The target address (treasury or recipient)
     * @param value The ETH value to transfer
     * @param data The encoded function call
     * @param title The proposal title
     * @param description The proposal description
     */
    function proposeTreasuryAction(
        address target,
        uint256 value,
        bytes memory data,
        string memory title,
        string memory description
    ) external returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = target;
        values[0] = value;
        calldatas[0] = data;
        
        proposalId = propose(targets, values, calldatas, description);
        
        proposalMetadata[proposalId] = ProposalMetadata({
            proposalType: ProposalType.TREASURY_MANAGEMENT,
            title: title,
            description: description,
            target: target,
            value: value,
            data: data,
            executionTime: 0,
            executed: false
        });
        
        emit ProposalCreatedWithMetadata(proposalId, ProposalType.TREASURY_MANAGEMENT, title, description);
    }
    
    /**
     * @dev Authorize or deauthorize a contract for governance actions
     * @param contractAddr The contract address
     * @param authorized Whether to authorize or deauthorize
     */
    function setContractAuthorization(address contractAddr, bool authorized) external onlyGovernance {
        authorizedContracts[contractAddr] = authorized;
        emit ContractAuthorized(contractAddr, authorized);
    }
    
    /**
     * @dev List a new asset (called by governance)
     * @param asset The asset address
     * @param riskParams Risk parameters for the asset
     */
    function listAsset(address asset, RiskParameters memory riskParams) external onlyGovernance {
        // This would integrate with the risk manager to set asset parameters
        emit AssetListed(asset, "NEW");
        emit RiskParametersUpdated(asset, riskParams);
    }
    
    /**
     * @dev Update interest rate model parameters
     * @param poolAddress The lending pool address
     * @param baseRate New base rate
     * @param multiplier New multiplier
     * @param jumpMultiplier New jump multiplier
     */
    function updateInterestRateModel(
        address poolAddress,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier
    ) external onlyGovernance {
        if (!authorizedContracts[poolAddress]) {
            revert UnauthorizedContract();
        }
        
        // This would call the pool's update function
        bytes memory data = abi.encodeWithSignature(
            "updateInterestRateModel(uint256,uint256,uint256)",
            baseRate,
            multiplier,
            jumpMultiplier
        );
        
        (bool success,) = poolAddress.call(data);
        require(success, "Parameter update failed");
        
        emit ParameterUpdated("interestRateModel", 0, baseRate);
    }
    
    /**
     * @dev Update protocol fee
     * @param clobAddress The CLOB contract address
     * @param newFee New protocol fee in basis points
     */
    function updateProtocolFee(address clobAddress, uint256 newFee) external onlyGovernance {
        if (!authorizedContracts[clobAddress]) {
            revert UnauthorizedContract();
        }
        
        bytes memory data = abi.encodeWithSignature("updateProtocolFee(uint256)", newFee);
        (bool success,) = clobAddress.call(data);
        require(success, "Fee update failed");
        
        emit ParameterUpdated("protocolFee", 0, newFee);
    }
    
    /**
     * @dev Update liquidation parameters
     * @param riskManagerAddress The risk manager contract address
     * @param asset The asset address
     * @param liquidationThreshold New liquidation threshold
     * @param liquidationPenalty New liquidation penalty
     */
    function updateLiquidationParameters(
        address riskManagerAddress,
        address asset,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty
    ) external onlyGovernance {
        if (!authorizedContracts[riskManagerAddress]) {
            revert UnauthorizedContract();
        }
        
        RiskParameters memory newParams = RiskParameters({
            maxLTV: 7500, // Keep existing or get from contract
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            minCollateralRatio: liquidationThreshold + 500, // 5% buffer
            isEnabled: true
        });
        
        bytes memory data = abi.encodeWithSignature(
            "setAssetRiskParameters(address,(uint256,uint256,uint256,uint256,bool))",
            asset,
            newParams
        );
        
        (bool success,) = riskManagerAddress.call(data);
        require(success, "Risk parameter update failed");
        
        emit RiskParametersUpdated(asset, newParams);
    }
    
    /**
     * @dev Get proposal metadata
     * @param proposalId The proposal ID
     * @return metadata The proposal metadata
     */
    function getProposalMetadata(uint256 proposalId) external view returns (ProposalMetadata memory) {
        return proposalMetadata[proposalId];
    }
    
    /**
     * @dev Get voting power of an account
     * @param account The account address
     * @return votingPower The voting power
     */
    function getVotingPower(address account) external view returns (uint256) {
        return getVotes(account, block.number - 1);
    }
    
    /**
     * @dev Check if an account can create proposals
     * @param account The account address
     * @return canPropose Whether the account can create proposals
     */
    function canCreateProposal(address account) external view returns (bool) {
        return getVotes(account, block.number - 1) >= proposalThreshold();
    }
    
    /**
     * @dev Emergency execute function (only for critical situations)
     * @param target The target contract
     * @param data The function call data
     */
    function emergencyExecute(address target, bytes memory data) external onlyGovernance {
        (bool success,) = target.call(data);
        require(success, "Emergency execution failed");
        
        emit EmergencyActionExecuted(target, data);
    }
    
    /**
     * @dev Override functions required by Solidity
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }
    
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }
    
    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
    
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
    
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }
    
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }
    
    // Remove the _execute override as it's handled by _executeOperations
    function _afterExecute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal {
        // Mark proposal as executed
        proposalMetadata[proposalId].executed = true;
        proposalMetadata[proposalId].executionTime = block.timestamp;
    }
    
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }
    
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
        _afterExecute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function proposalNeedsQueuing(uint256 proposalId) 
        public 
        view 
        override(Governor, GovernorTimelockControl) 
        returns (bool) 
    {
        return super.proposalNeedsQueuing(proposalId);
    }
} 