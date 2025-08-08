// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Core contract imports
import {Vault} from "@src/core/Vault.sol";
import {CLPoolManager} from "@src/core/pool-cl/CLPoolManager.sol";
import {BinPoolManager} from "@src/core/pool-bin/BinPoolManager.sol";
import {ProtocolFeeController} from "@src/core/ProtocolFeeController.sol";

// Periphery contract imports
import {CLPositionManager} from "@src/periphery/pool-cl/CLPositionManager.sol";
import {BinPositionManager} from "@src/periphery/pool-bin/BinPositionManager.sol";
import {CLQuoter} from "@src/periphery/pool-cl/lens/CLQuoter.sol";
import {BinQuoter} from "@src/periphery/pool-bin/lens/BinQuoter.sol";
import {InfinityRouter} from "@src/periphery/InfinityRouter.sol";

// Test tokens and tools
import "../test/tokens/TestTokenFactory.sol";
import "../test/tokens/TokenFaucet.sol";
import "../test/pools/PoolInitializer.sol";
import "../test/pools/LiquidityProvider.sol";

/**
 * @title LocalDevDeploy
 * @notice Complete DEX deployment script for local development environment
 * @dev Deploy the complete PancakeSwap Infinity protocol stack for local testing and project integration
 */
contract LocalDevDeploy is Script {
    // Deployment configuration
    struct DeployConfig {
        address deployer;
        address poolOwner;
        address protocolFeeControllerOwner;
        string salt;
        uint24 defaultProtocolFee;
        uint24 defaultLPFee;
    }

    // Deployed contract addresses
    struct DeployedContracts {
        // Core contracts
        Vault vault;
        CLPoolManager clPoolManager;
        BinPoolManager binPoolManager;
        ProtocolFeeController clProtocolFeeController;
        ProtocolFeeController binProtocolFeeController;
        // Periphery contracts
        CLPositionManager clPositionManager;
        BinPositionManager binPositionManager;
        CLQuoter clQuoter;
        BinQuoter binQuoter;
        InfinityRouter router;
        // Testing tools
        TestTokenFactory tokenFactory;
        TokenFaucet tokenFaucet;
        PoolInitializer poolInitializer;
        LiquidityProvider liquidityProvider;
    }

    DeployConfig public config;
    DeployedContracts public deployed;

    string configPath;

    function setUp() public {
        // Read configuration file
        string memory root = vm.projectRoot();
        configPath = string.concat(root, "/script/config/local-dev.json");
        console.log("[LocalDevDeploy] Reading config from:", configPath);

        // Parse configuration
        string memory json = vm.readFile(configPath);
        config.deployer = vm.parseJsonAddress(json, ".deployer");
        config.poolOwner = vm.parseJsonAddress(json, ".poolOwner");
        config.protocolFeeControllerOwner = vm.parseJsonAddress(json, ".protocolFeeControllerOwner");
        config.salt = vm.parseJsonString(json, ".salt");
        config.defaultProtocolFee = 2500; // 0.25%
        config.defaultLPFee = 3000; // 0.3%
    }

    function run() public {
        console.log("====================================");
        console.log("Deploy PancakeSwap Infinity Local DEX Environment");
        console.log("====================================");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Stage 1: Deploy core contracts
        deployCore();

        // Stage 2: Deploy periphery contracts
        deployPeriphery();

        // Stage 3: Deploy testing tools
        deployTestingTools();

        // Stage 4: Initialize system
        initializeSystem();

        // Stage 5: Create test tokens
        createTestTokens();

        // Stage 6: Create initial pools
        createInitialPools();

        vm.stopBroadcast();

        // Save deployment results
        saveDeploymentResults();

        console.log("====================================");
        console.log("Local DEX environment deployment completed!");
        console.log("====================================");
    }

    /**
     * @notice Deploy core contracts
     */
    function deployCore() internal {
        console.log("\n[Stage 1] Deploying core contracts...");

        // Deploy Vault
        deployed.vault = new Vault();
        console.log("Vault deployed to:", address(deployed.vault));

        // Deploy CL Pool Manager
        deployed.clPoolManager = new CLPoolManager(deployed.vault);
        console.log("CL Pool Manager deployed to:", address(deployed.clPoolManager));

        // Deploy Bin Pool Manager
        deployed.binPoolManager = new BinPoolManager(deployed.vault);
        console.log("Bin Pool Manager deployed to:", address(deployed.binPoolManager));

        // Deploy protocol fee controllers
        deployed.clProtocolFeeController = new ProtocolFeeController(address(deployed.clPoolManager));
        deployed.binProtocolFeeController = new ProtocolFeeController(address(deployed.binPoolManager));
        console.log("CL Protocol Fee Controller deployed to:", address(deployed.clProtocolFeeController));
        console.log("Bin Protocol Fee Controller deployed to:", address(deployed.binProtocolFeeController));
    }

    /**
     * @notice Deploy periphery contracts
     */
    function deployPeriphery() internal {
        console.log("\n[Stage 2] Deploying periphery contracts...");

        // TODO: Need to adjust based on actual periphery contract constructor parameters
        // Due to the complexity of periphery contract constructors, providing basic framework here

        console.log("Periphery contract deployment - implementation of specific constructor parameters pending");
        console.log("Required parameters: vault, poolManager, permit2, positionDescriptor, weth9, etc.");
    }

    /**
     * @notice Deploy testing tools
     */
    function deployTestingTools() internal {
        console.log("\n[Stage 3] Deploying testing tools...");

        // Deploy test token factory
        deployed.tokenFactory = new TestTokenFactory();
        console.log("Test Token Factory deployed to:", address(deployed.tokenFactory));

        // Deploy token faucet
        deployed.tokenFaucet = new TokenFaucet();
        console.log("Token Faucet deployed to:", address(deployed.tokenFaucet));

        // Deploy pool initializer
        deployed.poolInitializer =
            new PoolInitializer(address(deployed.clPoolManager), address(deployed.binPoolManager));
        console.log("Pool Initializer deployed to:", address(deployed.poolInitializer));

        // Deploy liquidity provider
        deployed.liquidityProvider = new LiquidityProvider(
            address(deployed.vault), address(deployed.clPoolManager), address(deployed.binPoolManager)
        );
        console.log("Liquidity Provider deployed to:", address(deployed.liquidityProvider));
    }

    /**
     * @notice Initialize system
     */
    function initializeSystem() internal {
        console.log("\n[Stage 4] Initializing system...");

        // Register Pool Managers to Vault
        deployed.vault.registerApp(address(deployed.clPoolManager));
        deployed.vault.registerApp(address(deployed.binPoolManager));
        console.log("Pool Managers registered to Vault");

        // Set protocol fee controllers
        deployed.clPoolManager.setProtocolFeeController(deployed.clProtocolFeeController);
        deployed.binPoolManager.setProtocolFeeController(deployed.binProtocolFeeController);
        console.log("Protocol fee controllers set");
    }

    /**
     * @notice Create test tokens
     */
    function createTestTokens() internal {
        console.log("\n[Stage 5] Creating test tokens...");

        string memory json = vm.readFile(configPath);

        // Create WETH
        address weth = deployed.tokenFactory.createToken("Wrapped Ether", "WETH", 18, 1000000 * 10 ** 18);
        console.log("WETH created:", weth);

        // Create USDC
        address usdc = deployed.tokenFactory.createToken("USD Coin", "USDC", 6, 1000000 * 10 ** 6);
        console.log("USDC created:", usdc);

        // Create USDT
        address usdt = deployed.tokenFactory.createToken("Tether USD", "USDT", 6, 1000000 * 10 ** 6);
        console.log("USDT created:", usdt);

        // Create CAKE
        address cake = deployed.tokenFactory.createToken("PancakeSwap Token", "CAKE", 18, 1000000 * 10 ** 18);
        console.log("CAKE created:", cake);

        // Add tokens to faucet
        deployed.tokenFaucet.addToken(weth, 100 * 10 ** 18, 3600); // 100 WETH per claim, 1 hour cooldown
        deployed.tokenFaucet.addToken(usdc, 10000 * 10 ** 6, 3600); // 10000 USDC per claim, 1 hour cooldown
        deployed.tokenFaucet.addToken(usdt, 10000 * 10 ** 6, 3600); // 10000 USDT per claim, 1 hour cooldown
        deployed.tokenFaucet.addToken(cake, 1000 * 10 ** 18, 3600); // 1000 CAKE per claim, 1 hour cooldown
        console.log("Tokens added to faucet");
    }

    /**
     * @notice Create initial pools
     */
    function createInitialPools() internal {
        console.log("\n[Stage 6] Creating initial pools...");

        // TODO: Implement initial pool creation
        // Need to create different types of pools based on initialPools configuration in config file
        console.log("Initial pool creation - implementation pending");
        console.log("Pools to create: WETH/USDC CL pool, USDC/USDT CL pool, WETH/CAKE Bin pool, etc.");
    }

    /**
     * @notice Save deployment results to configuration file
     */
    function saveDeploymentResults() internal {
        console.log("\nSaving deployment results...");

        // TODO: Implement logic to write contract addresses back to configuration file
        // Can use forge's file writing functionality or external script processing
        console.log("Deployment result saving - implementation pending");

        // Print all important contract addresses
        console.log("\n=== Deployed Contract Addresses ===");
        console.log("Vault:", address(deployed.vault));
        console.log("CL Pool Manager:", address(deployed.clPoolManager));
        console.log("Bin Pool Manager:", address(deployed.binPoolManager));
        console.log("Test Token Factory:", address(deployed.tokenFactory));
        console.log("Token Faucet:", address(deployed.tokenFaucet));
        console.log("Pool Initializer:", address(deployed.poolInitializer));
        console.log("Liquidity Provider:", address(deployed.liquidityProvider));
    }
}
