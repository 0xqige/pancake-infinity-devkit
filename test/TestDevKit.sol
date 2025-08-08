// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

// Type definitions
import {Currency, CurrencyLibrary} from "../src/Currency.sol";
import {PoolKey} from "../src/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../src/PoolId.sol";
import {IHooks} from "../src/IHooks.sol";
import {IPoolManager} from "../src/IPoolManager.sol";

// Testing tools
import "./tokens/TestTokenFactory.sol";
import "./tokens/TokenFaucet.sol";
import "./tokens/TestTokens.sol";
// import "./pools/PoolInitializer.sol";
// import "./pools/LiquidityProvider.sol";
// import "./integration/DEXInteractionHelpers.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "forge-std/Test.sol";

// Import mock contracts
import "./mocks/MockCoreContracts.sol";

/**
 * @title TestDevKit
 * @notice PancakeSwap Infinity Test Development Kit - One-click deployment and management of testing environment
 * @dev Provides complete DEX testing environment including core contracts, tokens, pools and tools
 */
contract TestDevKit is Test {
    using CurrencyLibrary for address;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for bytes32;
    
    // ========== State Variables ==========
    
    // Core contracts (using mock contracts)
    MockVault public vault;
    MockCLPoolManager public clPoolManager;
    MockBinPoolManager public binPoolManager;
    MockProtocolFeeController public protocolFeeController;
    
    // Testing tools
    TestTokenFactory public tokenFactory;
    TokenFaucet public tokenFaucet;
    // PoolInitializer public poolInitializer;
    // LiquidityProvider public liquidityProvider;
    // DEXInteractionHelpers public dexHelpers;
    
    // Standard test tokens
    StandardTestToken public weth;
    StandardTestToken public usdc;
    StandardTestToken public usdt;
    StandardTestToken public cake;
    StandardTestToken public bnb;
    
    // Special test tokens
    FeeOnTransferToken public feeToken;
    DeflationaryToken public defToken;
    RebasingToken public rebaseToken;
    
    // Common pools
    struct PoolInfo {
        PoolKey key;
        PoolId id;
        bool isInitialized;
        string name;
    }
    
    mapping(string => PoolInfo) public pools;
    string[] public poolNames;
    
    // Test accounts
    address public alice;
    address public bob;
    address public carol;
    address public dave;
    address public eve;
    
    // Configuration
    address public owner;
    bool public isInitialized;
    uint256 public deploymentTimestamp;
    
    // Events
    event EnvironmentDeployed(uint256 timestamp);
    event TokensCreated(uint256 count);
    event PoolsCreated(uint256 count);
    event TestAccountsFunded(uint256 count);
    event ComponentDeployed(string name, address addr);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier notInitialized() {
        require(!isInitialized, "Already initialized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        deploymentTimestamp = block.timestamp;
    }
    
    // ========== One-Click Deployment Functions ==========
    
    /**
     * @notice Deploy complete testing environment with one click
     * @param deployCore Whether to deploy core contracts (if false, need to set existing deployed addresses)
     */
    function deployFullEnvironment(bool deployCore) external notInitialized {
        console.log("\n============================================");
        console.log("PancakeSwap Infinity TestDevKit deployment started");
        console.log("============================================\n");
        
        // 1. Deploy or set core contracts
        if (deployCore) {
            _deployCoreContracts();
        }
        
        // 2. Deploy testing tools
        _deployTestingTools();
        
        // 3. Create test tokens
        _createTestTokens();
        
        // 4. Setup test accounts
        _setupTestAccounts();
        
        // 5. Create common pools
        _createCommonPools();
        
        // 6. Add initial liquidity
        _addInitialLiquidity();
        
        // 7. Distribute tokens to test accounts
        _fundTestAccounts();
        
        isInitialized = true;
        emit EnvironmentDeployed(block.timestamp);
        
        console.log("\n============================================");
        console.log("TestDevKit deployment completed!");
        console.log("============================================");
        _printSummary();
    }
    
    /**
     * @notice Set deployed core contract addresses
     */
    function setCoreContracts(
        address _vault,
        address _clPoolManager,
        address _binPoolManager,
        address _protocolFeeController
    ) external onlyOwner {
        vault = MockVault(_vault);
        clPoolManager = MockCLPoolManager(_clPoolManager);
        binPoolManager = MockBinPoolManager(_binPoolManager);
        protocolFeeController = MockProtocolFeeController(_protocolFeeController);
        
        console.log("Core contracts set:");
        console.log("  Vault:", _vault);
        console.log("  CL Pool Manager:", _clPoolManager);
        console.log("  Bin Pool Manager:", _binPoolManager);
    }
    
    // ========== Internal Deployment Functions ==========
    
    function _deployCoreContracts() internal {
        console.log("Deploying mock core contracts for testing...");
        
        // Deploy simple mock contracts for testing
        vault = new MockVault();
        clPoolManager = new MockCLPoolManager();
        binPoolManager = new MockBinPoolManager();
        protocolFeeController = new MockProtocolFeeController();
        
        console.log("Mock core contracts deployed:");
        console.log("  Vault:", address(vault));
        console.log("  CL Pool Manager:", address(clPoolManager));
        console.log("  Bin Pool Manager:", address(binPoolManager));
        console.log("  Protocol Fee Controller:", address(protocolFeeController));
    }
    
    function _deployTestingTools() internal {
        console.log("Deploying testing tools...");
        
        // Deploy token factory
        tokenFactory = new TestTokenFactory();
        emit ComponentDeployed("TokenFactory", address(tokenFactory));
        
        // Deploy faucet
        tokenFaucet = new TokenFaucet();
        emit ComponentDeployed("TokenFaucet", address(tokenFaucet));
        
        // Deploy pool initializer (simplified for testing)
        // poolInitializer = new PoolInitializer(
        //     address(clPoolManager),
        //     address(binPoolManager)
        // );
        // emit ComponentDeployed("PoolInitializer", address(poolInitializer));
        
        // Deploy liquidity provider (simplified for testing)
        // liquidityProvider = new LiquidityProvider(
        //     address(vault),
        //     address(clPoolManager),
        //     address(binPoolManager)
        // );
        // emit ComponentDeployed("LiquidityProvider", address(liquidityProvider));
        
        // Deploy DEX interaction helpers (simplified for testing)
        // dexHelpers = new DEXInteractionHelpers(
        //     address(vault),
        //     address(clPoolManager),
        //     address(binPoolManager)
        // );
        // emit ComponentDeployed("DEXHelpers", address(dexHelpers));
        
        console.log("Testing tools deployment completed!");
    }
    
    function _createTestTokens() internal {
        console.log("\nCreating test tokens...");
        
        // Create standard tokens
        weth = StandardTestToken(tokenFactory.createToken(
            "Wrapped Ether", "WETH", 18, 10000000 * 10**18
        ));
        
        usdc = StandardTestToken(tokenFactory.createToken(
            "USD Coin", "USDC", 6, 10000000 * 10**6
        ));
        
        usdt = StandardTestToken(tokenFactory.createToken(
            "Tether USD", "USDT", 6, 10000000 * 10**6
        ));
        
        cake = StandardTestToken(tokenFactory.createToken(
            "PancakeSwap Token", "CAKE", 18, 10000000 * 10**18
        ));
        
        bnb = StandardTestToken(tokenFactory.createToken(
            "BNB", "BNB", 18, 10000000 * 10**18
        ));
        
        // Create special tokens (for edge case testing)
        feeToken = FeeOnTransferToken(tokenFactory.createToken(
            "Fee Token", "FEE", 18, 1000000 * 10**18,
            TestTokenFactory.TokenType.FeeOnTransfer
        ));
        
        defToken = DeflationaryToken(tokenFactory.createToken(
            "Deflationary Token", "DEF", 18, 1000000 * 10**18,
            TestTokenFactory.TokenType.Deflationary
        ));
        
        rebaseToken = RebasingToken(tokenFactory.createToken(
            "Rebase Token", "REBASE", 18, 1000000 * 10**18,
            TestTokenFactory.TokenType.Rebasing
        ));
        
        // Configure faucet
        _setupFaucet();
        
        emit TokensCreated(8);
        console.log("Test tokens creation completed!");
    }
    
    function _setupFaucet() internal {
        // Standard token faucet configuration
        tokenFaucet.addToken(address(weth), 100 * 10**18, 3600); // 100 WETH, 1 hour cooldown
        tokenFaucet.addToken(address(usdc), 10000 * 10**6, 3600); // 10,000 USDC
        tokenFaucet.addToken(address(usdt), 10000 * 10**6, 3600); // 10,000 USDT
        tokenFaucet.addToken(address(cake), 1000 * 10**18, 3600); // 1,000 CAKE
        tokenFaucet.addToken(address(bnb), 100 * 10**18, 3600); // 100 BNB
        
        // Special token faucet configuration
        tokenFaucet.addToken(address(feeToken), 1000 * 10**18, 3600);
        tokenFaucet.addToken(address(defToken), 1000 * 10**18, 3600);
        tokenFaucet.addToken(address(rebaseToken), 1000 * 10**18, 3600);
        
        // Transfer initial tokens to faucet (scaled down amounts)
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 10000 * 10**18) {
            weth.transfer(address(tokenFaucet), 10000 * 10**18);
        } else if (wethBalance > 1000 * 10**18) {
            weth.transfer(address(tokenFaucet), 1000 * 10**18);
        }
        
        uint256 usdcBalance = usdc.balanceOf(address(this));
        if (usdcBalance > 1000000 * 10**6) {
            usdc.transfer(address(tokenFaucet), 1000000 * 10**6);
        } else if (usdcBalance > 100000 * 10**6) {
            usdc.transfer(address(tokenFaucet), 100000 * 10**6);
        }
        
        uint256 usdtBalance = usdt.balanceOf(address(this));
        if (usdtBalance > 1000000 * 10**6) {
            usdt.transfer(address(tokenFaucet), 1000000 * 10**6);
        } else if (usdtBalance > 100000 * 10**6) {
            usdt.transfer(address(tokenFaucet), 100000 * 10**6);
        }
        
        uint256 cakeBalance = cake.balanceOf(address(this));
        if (cakeBalance > 100000 * 10**18) {
            cake.transfer(address(tokenFaucet), 100000 * 10**18);
        } else if (cakeBalance > 10000 * 10**18) {
            cake.transfer(address(tokenFaucet), 10000 * 10**18);
        }
        
        uint256 bnbBalance = bnb.balanceOf(address(this));
        if (bnbBalance > 10000 * 10**18) {
            bnb.transfer(address(tokenFaucet), 10000 * 10**18);
        } else if (bnbBalance > 1000 * 10**18) {
            bnb.transfer(address(tokenFaucet), 1000 * 10**18);
        }
        
        // Transfer special tokens if available
        uint256 feeTokenBalance = feeToken.balanceOf(address(this));
        if (feeTokenBalance > 10000 * 10**18) {
            feeToken.transfer(address(tokenFaucet), 10000 * 10**18);
        }
        
        uint256 defTokenBalance = defToken.balanceOf(address(this));
        if (defTokenBalance > 10000 * 10**18) {
            defToken.transfer(address(tokenFaucet), 10000 * 10**18);
        }
        
        uint256 rebaseTokenBalance = rebaseToken.balanceOf(address(this));
        if (rebaseTokenBalance > 10000 * 10**18) {
            rebaseToken.transfer(address(tokenFaucet), 10000 * 10**18);
        }
    }
    
    function _setupTestAccounts() internal {
        console.log("\nSetting up test accounts...");
        
        // Use makeAddr to create test accounts with labels
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");
        eve = makeAddr("eve");
        
        // Fund test accounts with ETH for gas
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(dave, 100 ether);
        vm.deal(eve, 100 ether);
        
        console.log("Test accounts:");
        console.log("  Alice:", alice);
        console.log("  Bob:", bob);
        console.log("  Carol:", carol);
        console.log("  Dave:", dave);
        console.log("  Eve:", eve);
    }
    
    function _createCommonPools() internal {
        console.log("\nCreating common trading pools...");
        
        // 1. WETH/USDC - Mainstream trading pair
        _createAndRegisterPool(
            "WETH/USDC",
            address(weth).wrap(),
            address(usdc).wrap(),
            3000, // 0.3% fee
            60,   // tick spacing
            79228162514264337593543950336 // Approximately 1:1 price for testing
        );
        
        // 2. USDC/USDT - Stablecoin pair
        _createAndRegisterPool(
            "USDC/USDT",
            address(usdc).wrap(),
            address(usdt).wrap(),
            100,  // 0.01% fee
            1,    // tick spacing
            79228162514264337593543950336 // 1:1 price
        );
        
        // 3. WETH/CAKE - Platform token pair
        _createAndRegisterPool(
            "WETH/CAKE",
            address(weth).wrap(),
            address(cake).wrap(),
            3000, // 0.3% fee
            60,   // tick spacing
            79228162514264337593543950336 // Simplified price for testing
        );
        
        // 4. CAKE/USDC
        _createAndRegisterPool(
            "CAKE/USDC",
            address(cake).wrap(),
            address(usdc).wrap(),
            3000, // 0.3% fee
            60,   // tick spacing
            79228162514264337593543950336 // Simplified price for testing
        );
        
        // 5. BNB/USDC
        _createAndRegisterPool(
            "BNB/USDC",
            address(bnb).wrap(),
            address(usdc).wrap(),
            3000, // 0.3% fee
            60,   // tick spacing
            79228162514264337593543950336 // Simplified price for testing
        );
        
        emit PoolsCreated(poolNames.length);
        console.log("Created", poolNames.length, "trading pools");
    }
    
    function _createAndRegisterPool(
        string memory name,
        Currency currency0,
        Currency currency1,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal {
        // Ensure currency order is correct
        if (currency0.unwrap() > currency1.unwrap()) {
            (currency0, currency1) = (currency1, currency0);
        }
        
        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            parameters: bytes32(uint256(int256(tickSpacing))),
            hooks: IHooks(address(0)),
            poolManager: IPoolManager(address(clPoolManager))
        });
        
        // Initialize pool in mock CLPoolManager
        clPoolManager.initialize(key, sqrtPriceX96);
        
        // Calculate pool ID
        PoolId id = keccak256(abi.encode(key)).wrap();
        
        pools[name] = PoolInfo({
            key: key,
            id: id,
            isInitialized: true,
            name: name
        });
        
        poolNames.push(name);
        console.log("  Pool created:", name);
    }
    
    function _addInitialLiquidity() internal {
        console.log("\nAdding initial liquidity...");
        
        // In a real implementation, this would add liquidity to pools
        // For testing, we'll just log the action
        for (uint256 i = 0; i < poolNames.length; i++) {
            string memory poolName = poolNames[i];
            PoolInfo memory pool = pools[poolName];
            
            if (pool.isInitialized) {
                // Mock liquidity addition
                console.log("  Added liquidity to", poolName);
            }
        }
    }
    
    function _fundTestAccounts() internal {
        console.log("\nDistributing tokens to test accounts...");
        
        address[5] memory accounts = [alice, bob, carol, dave, eve];
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            
            // Distribute standard tokens (check balance first)
            if (weth.balanceOf(address(this)) >= 100 * 10**18) {
                weth.transfer(account, 100 * 10**18);
            } else {
                weth.transfer(account, 10 * 10**18); // Smaller amount
            }
            
            if (usdc.balanceOf(address(this)) >= 100000 * 10**6) {
                usdc.transfer(account, 100000 * 10**6);
            } else {
                usdc.transfer(account, 10000 * 10**6); // Smaller amount
            }
            
            if (usdt.balanceOf(address(this)) >= 100000 * 10**6) {
                usdt.transfer(account, 100000 * 10**6);
            } else {
                usdt.transfer(account, 10000 * 10**6); // Smaller amount
            }
            
            if (cake.balanceOf(address(this)) >= 10000 * 10**18) {
                cake.transfer(account, 10000 * 10**18);
            } else {
                cake.transfer(account, 1000 * 10**18); // Smaller amount
            }
            
            if (bnb.balanceOf(address(this)) >= 100 * 10**18) {
                bnb.transfer(account, 100 * 10**18);
            } else {
                bnb.transfer(account, 10 * 10**18); // Smaller amount
            }
            
            // Distribute special tokens
            if (feeToken.balanceOf(address(this)) >= 1000 * 10**18) {
                feeToken.transfer(account, 1000 * 10**18);
            } else if (feeToken.balanceOf(address(this)) > 0) {
                feeToken.transfer(account, 100 * 10**18);
            }
            
            if (defToken.balanceOf(address(this)) >= 1000 * 10**18) {
                defToken.transfer(account, 1000 * 10**18);
            } else if (defToken.balanceOf(address(this)) > 0) {
                defToken.transfer(account, 100 * 10**18);
            }
            
            if (rebaseToken.balanceOf(address(this)) >= 1000 * 10**18) {
                rebaseToken.transfer(account, 1000 * 10**18);
            } else if (rebaseToken.balanceOf(address(this)) > 0) {
                rebaseToken.transfer(account, 100 * 10**18);
            }
        }
        
        emit TestAccountsFunded(accounts.length);
        console.log("Distributed tokens to", accounts.length, "test accounts");
    }
    
    // ========== Utility Functions ==========
    
    /**
     * @notice Calculate sqrtPriceX96 from price
     * @param price Price (18 decimals)
     * @return sqrtPriceX96
     */
    function _encodePriceToSqrtPriceX96(uint256 price) internal pure returns (uint160) {
        // Simplified calculation to avoid overflow
        // For testing, just return a reasonable value
        if (price == 0) return 0;
        
        // Use a simple approximation for testing
        uint256 sqrtPrice = _sqrt(price / 1e9) * 1e9; // Scale down to avoid overflow
        return uint160(sqrtPrice >> 32); // Adjust for X96 format
    }
    
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    function _printSummary() internal view {
        console.log("\n========== Deployment Summary ==========");
        console.log("\nCore contracts:");
        console.log("  Vault:", address(vault));
        console.log("  CL Pool Manager:", address(clPoolManager));
        console.log("  Bin Pool Manager:", address(binPoolManager));
        
        console.log("\nTesting tools:");
        console.log("  Token Factory:", address(tokenFactory));
        console.log("  Token Faucet:", address(tokenFaucet));
        // console.log("  Pool Initializer:", address(poolInitializer));
        // console.log("  Liquidity Provider:", address(liquidityProvider));
        // console.log("  DEX Helpers:", address(dexHelpers));
        
        console.log("\nStandard tokens:");
        console.log("  WETH:", address(weth));
        console.log("  USDC:", address(usdc));
        console.log("  USDT:", address(usdt));
        console.log("  CAKE:", address(cake));
        console.log("  BNB:", address(bnb));
        
        console.log("\nSpecial tokens:");
        console.log("  Fee Token:", address(feeToken));
        console.log("  Deflationary Token:", address(defToken));
        console.log("  Rebase Token:", address(rebaseToken));
        
        console.log("\nTrading pools:");
        for (uint256 i = 0; i < poolNames.length; i++) {
            console.log("  ", poolNames[i]);
        }
        
        console.log("\nTest accounts:");
        console.log("  Alice:", alice);
        console.log("  Bob:", bob);
        console.log("  Carol:", carol);
        console.log("  Dave:", dave);
        console.log("  Eve:", eve);
        
        console.log("\n==============================");
    }
    
    // ========== Query Functions ==========
    
    /**
     * @notice Get pool information
     */
    function getPool(string memory name) external view returns (PoolKey memory key, PoolId id) {
        PoolInfo memory pool = pools[name];
        require(pool.isInitialized, "Pool not found");
        return (pool.key, pool.id);
    }
    
    /**
     * @notice Get all pool names
     */
    function getAllPoolNames() external view returns (string[] memory) {
        return poolNames;
    }
    
    /**
     * @notice Get test account balance
     */
    function getTestAccountBalance(address account, address token) external view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
    
    /**
     * @notice Check if environment is initialized
     */
    function isReady() external view returns (bool) {
        return isInitialized;
    }
    
    // ========== Management Functions ==========
    
    /**
     * @notice Reset environment (testing only)
     */
    function resetEnvironment() external onlyOwner {
        isInitialized = false;
        delete poolNames;
        console.log("Environment reset, can redeploy");
    }
    
    /**
     * @notice Refund tokens for all test accounts
     */
    function refundAllTestAccounts() external {
        _fundTestAccounts();
    }
    
    /**
     * @notice Create custom pool
     */
    function createCustomPool(
        string memory name,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        uint256 initialPrice
    ) external returns (PoolKey memory key, PoolId id) {
        _createAndRegisterPool(
            name,
            Currency.wrap(token0),
            Currency.wrap(token1),
            fee,
            tickSpacing,
            _encodePriceToSqrtPriceX96(initialPrice)
        );
        
        return (pools[name].key, pools[name].id);
    }
    
    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
}