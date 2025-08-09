// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "./TestTokens.sol";

/**
 * @title TestTokenFactory
 * @notice Test token factory for creating various test tokens
 * @dev Supports creating standard ERC20 tokens, tokens with transfer fees, deflationary tokens etc.
 */
contract TestTokenFactory {
    event TokenCreated(
        address indexed token,
        string name, 
        string symbol,
        uint8 decimals,
        uint256 initialSupply,
        TokenType tokenType
    );

    enum TokenType {
        Standard,       // Standard ERC20 token
        FeeOnTransfer, // Transfer fee token  
        Deflationary,  // Deflationary token
        Rebasing,      // Rebasing token
        NonStandard    // Non-standard token (for edge case testing)
    }

    mapping(string => address) public tokens;
    mapping(address => TokenType) public tokenTypes;
    address[] public allTokens;

    /**
     * @notice Create standard ERC20 token
     * @param name Token name
     * @param symbol Token symbol  
     * @param decimals Decimal places
     * @param initialSupply Initial supply
     * @return token Token contract address
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) external returns (address token) {
        return createToken(name, symbol, decimals, initialSupply, TokenType.Standard);
    }

    /**
     * @notice Create test token of specified type
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Decimal places  
     * @param initialSupply Initial supply
     * @param tokenType Token type
     * @return token Token contract address
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply,
        TokenType tokenType
    ) public returns (address token) {
        require(tokens[symbol] == address(0), "Token already exists");

        if (tokenType == TokenType.Standard) {
            token = address(new StandardTestToken(name, symbol, decimals, initialSupply));
        } else if (tokenType == TokenType.FeeOnTransfer) {
            token = address(new FeeOnTransferToken(name, symbol, decimals, initialSupply));
        } else if (tokenType == TokenType.Deflationary) {
            token = address(new DeflationaryToken(name, symbol, decimals, initialSupply));
        } else if (tokenType == TokenType.Rebasing) {
            token = address(new RebasingToken(name, symbol, decimals, initialSupply));
        } else if (tokenType == TokenType.NonStandard) {
            token = address(new NonStandardToken(name, symbol, decimals, initialSupply));
        }

        tokens[symbol] = token;
        tokenTypes[token] = tokenType;
        allTokens.push(token);

        // Transfer tokens to caller
        IERC20(token).transfer(msg.sender, initialSupply);

        emit TokenCreated(token, name, symbol, decimals, initialSupply, tokenType);
        
        console.log("Created token:", name, "address:", token);
    }

    /**
     * @notice Batch create common test tokens
     * @dev Create common tokens like USDC, USDT, CAKE, BNB
     */
    function createCommonTokens() external {
        // USDC - 6 decimals
        createToken("USD Coin", "USDC", 6, 1000000 * 10**6, TokenType.Standard);
        
        // USDT - 6 decimals  
        createToken("Tether USD", "USDT", 6, 1000000 * 10**6, TokenType.Standard);
        
        // CAKE - 18 decimals
        createToken("PancakeSwap Token", "CAKE", 18, 1000000 * 10**18, TokenType.Standard);
        
        // BNB - 18 decimals
        createToken("BNB", "BNB", 18, 1000000 * 10**18, TokenType.Standard);
        
        // DAI - 18 decimals
        createToken("Dai Stablecoin", "DAI", 18, 1000000 * 10**18, TokenType.Standard);
        
        // BUSD - 18 decimals
        createToken("Binance USD", "BUSD", 18, 1000000 * 10**18, TokenType.Standard);
    }

    /**
     * @notice Create special test tokens (for edge case testing)
     */
    function createSpecialTokens() external {
        // Transfer fee token (1% fee)
        createToken("Fee Token", "FEE", 18, 1000000 * 10**18, TokenType.FeeOnTransfer);
        
        // Deflationary token (burns 0.1% on each transfer)
        createToken("Deflationary Token", "DEFLA", 18, 1000000 * 10**18, TokenType.Deflationary);
        
        // Rebasing token
        createToken("Rebasing Token", "REBASE", 18, 1000000 * 10**18, TokenType.Rebasing);
        
        // Non-standard token (transfer function doesn't return bool)
        createToken("Non Standard", "NONST", 18, 1000000 * 10**18, TokenType.NonStandard);
        
        // High precision token (27 decimals)
        createToken("High Precision", "HP27", 27, 1000000 * 10**27, TokenType.Standard);
        
        // Low precision token (2 decimals)  
        createToken("Low Precision", "LP2", 2, 1000000 * 10**2, TokenType.Standard);
    }

    /**
     * @notice Get token address by symbol
     */
    function getToken(string memory symbol) external view returns (address) {
        return tokens[symbol];
    }

    /**
     * @notice Get all created tokens
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Get token type
     */
    function getTokenType(address token) external view returns (TokenType) {
        return tokenTypes[token];
    }

    /**
     * @notice Mint tokens to specified address
     * @param tokenSymbol Token symbol
     * @param to Recipient address
     * @param amount Amount
     */
    function mintTo(string memory tokenSymbol, address to, uint256 amount) external {
        address token = tokens[tokenSymbol];
        require(token != address(0), "Token not found");
        
        // Call token contract's mint function (if supported)
        try IMintable(token).mint(to, amount) {
            // Minted tokens to recipient
        } catch {
            console.log("Token", tokenSymbol, "does not support minting function");
        }
    }

    /**
     * @notice Check token balance
     */
    function getBalance(string memory tokenSymbol, address account) external view returns (uint256) {
        address token = tokens[tokenSymbol];
        require(token != address(0), "Token not found");
        return IERC20(token).balanceOf(account);
    }
}

/**
 * @notice Mintable interface
 */
interface IMintable {
    function mint(address to, uint256 amount) external;
}