// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "forge-std/console.sol";

/**
 * @title TokenFaucet
 * @notice Token faucet providing free test tokens for test users
 * @dev Supports limiting claim frequency and amount per user
 */
contract TokenFaucet {
    struct TokenConfig {
        address token;           // Token address
        uint256 amountPerClaim;  // Amount per claim
        uint256 cooldownPeriod;  // Cooldown period (seconds)
        bool isActive;           // Whether active
        uint256 totalClaimed;    // Total claimed amount
        uint256 maxTotalClaim;   // Maximum total claim amount (0 means unlimited)
    }

    struct UserClaimInfo {
        uint256 lastClaimTime;   // Last claim time
        uint256 totalClaimed;    // Total claimed by user
        uint256 claimCount;      // Claim count
    }

    // Token configurations
    mapping(address => TokenConfig) public tokenConfigs;
    // User claim info: token => user => info
    mapping(address => mapping(address => UserClaimInfo)) public userClaimInfo;
    
    address[] public supportedTokens;
    address public owner;

    event TokenAdded(address indexed token, uint256 amountPerClaim, uint256 cooldownPeriod);
    event TokenClaimed(address indexed user, address indexed token, uint256 amount);
    event TokenConfigUpdated(address indexed token, uint256 amountPerClaim, uint256 cooldownPeriod);
    event FaucetDeposit(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Add supported token
     * @param token Token address
     * @param amountPerClaim Amount per claim
     * @param cooldownPeriod Cooldown period (seconds)
     */
    function addToken(address token, uint256 amountPerClaim, uint256 cooldownPeriod) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amountPerClaim > 0, "Amount must be positive");
        
        if (!tokenConfigs[token].isActive) {
            supportedTokens.push(token);
        }
        
        tokenConfigs[token] = TokenConfig({
            token: token,
            amountPerClaim: amountPerClaim,
            cooldownPeriod: cooldownPeriod,
            isActive: true,
            totalClaimed: 0,
            maxTotalClaim: 0 // Unlimited
        });

        emit TokenAdded(token, amountPerClaim, cooldownPeriod);
    }

    /**
     * @notice Add supported token (with total limit)
     */
    function addTokenWithLimit(
        address token, 
        uint256 amountPerClaim, 
        uint256 cooldownPeriod,
        uint256 maxTotalClaim
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amountPerClaim > 0, "Amount must be positive");
        require(maxTotalClaim > 0, "Max total must be positive");
        
        if (!tokenConfigs[token].isActive) {
            supportedTokens.push(token);
        }
        
        tokenConfigs[token] = TokenConfig({
            token: token,
            amountPerClaim: amountPerClaim,
            cooldownPeriod: cooldownPeriod,
            isActive: true,
            totalClaimed: 0,
            maxTotalClaim: maxTotalClaim
        });

        emit TokenAdded(token, amountPerClaim, cooldownPeriod);
    }

    /**
     * @notice Claim token
     * @param token Token address
     */
    function claimToken(address token) external {
        TokenConfig storage config = tokenConfigs[token];
        require(config.isActive, "Token not supported");
        
        UserClaimInfo storage userInfo = userClaimInfo[token][msg.sender];
        
        // Check cooldown period
        require(
            block.timestamp >= userInfo.lastClaimTime + config.cooldownPeriod,
            "Still in cooldown period"
        );
        
        // Check faucet balance
        uint256 faucetBalance = IERC20(token).balanceOf(address(this));
        require(faucetBalance >= config.amountPerClaim, "Faucet insufficient balance");
        
        // Check total claim limit
        if (config.maxTotalClaim > 0) {
            require(
                config.totalClaimed + config.amountPerClaim <= config.maxTotalClaim,
                "Total claim limit reached"
            );
        }

        // Update user info
        userInfo.lastClaimTime = block.timestamp;
        userInfo.totalClaimed += config.amountPerClaim;
        userInfo.claimCount += 1;
        
        // Update total claimed
        config.totalClaimed += config.amountPerClaim;

        // Transfer tokens
        require(IERC20(token).transfer(msg.sender, config.amountPerClaim), "Transfer failed");

        emit TokenClaimed(msg.sender, token, config.amountPerClaim);
        
        // User claimed tokens
    }

    /**
     * @notice Batch claim all supported tokens
     */
    function claimAllTokens() external {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            TokenConfig storage config = tokenConfigs[token];
            
            if (!config.isActive) continue;
            
            UserClaimInfo storage userInfo = userClaimInfo[token][msg.sender];
            
            // Skip tokens still in cooldown period
            if (block.timestamp < userInfo.lastClaimTime + config.cooldownPeriod) {
                continue;
            }
            
            // Skip tokens with insufficient faucet balance
            if (IERC20(token).balanceOf(address(this)) < config.amountPerClaim) {
                continue;
            }
            
            // Skip tokens that have reached total limit
            if (config.maxTotalClaim > 0 && 
                config.totalClaimed + config.amountPerClaim > config.maxTotalClaim) {
                continue;
            }

            // Execute claim
            userInfo.lastClaimTime = block.timestamp;
            userInfo.totalClaimed += config.amountPerClaim;
            userInfo.claimCount += 1;
            config.totalClaimed += config.amountPerClaim;

            require(IERC20(token).transfer(msg.sender, config.amountPerClaim), "Transfer failed");
            
            emit TokenClaimed(msg.sender, token, config.amountPerClaim);
        }
    }

    /**
     * @notice Check if user can claim specified token
     */
    function canClaim(address token, address user) external view returns (bool, string memory reason) {
        TokenConfig memory config = tokenConfigs[token];
        
        if (!config.isActive) {
            return (false, "Token not supported");
        }
        
        UserClaimInfo memory userInfo = userClaimInfo[token][user];
        
        if (block.timestamp < userInfo.lastClaimTime + config.cooldownPeriod) {
            return (false, "Still in cooldown period");
        }
        
        if (IERC20(token).balanceOf(address(this)) < config.amountPerClaim) {
            return (false, "Faucet insufficient balance");
        }
        
        if (config.maxTotalClaim > 0 && 
            config.totalClaimed + config.amountPerClaim > config.maxTotalClaim) {
            return (false, "Total claim limit reached");
        }
        
        return (true, "");
    }

    /**
     * @notice Get user's next claim time
     */
    function getNextClaimTime(address token, address user) external view returns (uint256) {
        TokenConfig memory config = tokenConfigs[token];
        UserClaimInfo memory userInfo = userClaimInfo[token][user];
        
        if (userInfo.lastClaimTime == 0) {
            return block.timestamp; // Never claimed before, can claim immediately
        }
        
        return userInfo.lastClaimTime + config.cooldownPeriod;
    }

    /**
     * @notice Get faucet token balance
     */
    function getFaucetBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Get all supported tokens
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @notice Update token configuration
     */
    function updateTokenConfig(
        address token, 
        uint256 amountPerClaim, 
        uint256 cooldownPeriod
    ) external onlyOwner {
        require(tokenConfigs[token].isActive, "Token not supported");
        
        tokenConfigs[token].amountPerClaim = amountPerClaim;
        tokenConfigs[token].cooldownPeriod = cooldownPeriod;
        
        emit TokenConfigUpdated(token, amountPerClaim, cooldownPeriod);
    }

    /**
     * @notice Disable token
     */
    function disableToken(address token) external onlyOwner {
        tokenConfigs[token].isActive = false;
    }

    /**
     * @notice Enable token
     */
    function enableToken(address token) external onlyOwner {
        require(tokenConfigs[token].token != address(0), "Token not configured");
        tokenConfigs[token].isActive = true;
    }

    /**
     * @notice Deposit tokens to faucet
     */
    function depositToken(address token, uint256 amount) external {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit FaucetDeposit(token, amount);
    }

    /**
     * @notice Emergency withdraw tokens (owner only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }

    /**
     * @notice Get user's claim statistics
     */
    function getUserStats(address token, address user) external view returns (
        uint256 lastClaimTime,
        uint256 totalClaimed,
        uint256 claimCount,
        uint256 nextClaimTime
    ) {
        UserClaimInfo memory userInfo = userClaimInfo[token][user];
        TokenConfig memory config = tokenConfigs[token];
        
        lastClaimTime = userInfo.lastClaimTime;
        totalClaimed = userInfo.totalClaimed;
        claimCount = userInfo.claimCount;
        
        if (userInfo.lastClaimTime == 0) {
            nextClaimTime = block.timestamp;
        } else {
            nextClaimTime = userInfo.lastClaimTime + config.cooldownPeriod;
        }
    }
}