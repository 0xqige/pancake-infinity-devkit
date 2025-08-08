// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Core contracts and types
import {Currency} from "@src/core/types/Currency.sol";
import {PoolKey} from "@src/core/types/PoolKey.sol";
import {PoolId} from "@src/core/types/PoolId.sol";
import {IVault} from "@src/core/interfaces/IVault.sol";
import {ICLPoolManager} from "@src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "@src/core/pool-bin/interfaces/IBinPoolManager.sol";

// Testing tools
import "../tokens/TestTokenFactory.sol";
import "../tokens/TokenFaucet.sol";
import "../pools/PoolInitializer.sol";
import "../pools/LiquidityProvider.sol";
import "./DEXInteractionHelpers.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title ProjectIntegrationTest
 * @notice Project integration test base class, provides complete DEX testing environment for third-party projects
 * @dev Inheriting this contract provides complete PancakeSwap Infinity testing environment
 */
abstract contract ProjectIntegrationTest is Test {
    // Core contract instances
    IVault public vault;
    ICLPoolManager public clPoolManager;
    IBinPoolManager public binPoolManager;

    // Testing tool instances
    TestTokenFactory public tokenFactory;
    TokenFaucet public tokenFaucet;
    PoolInitializer public poolInitializer;
    LiquidityProvider public liquidityProvider;
    DEXInteractionHelpers public dexHelpers;

    // Common test tokens
    IERC20 public weth;
    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public cake;
    IERC20 public bnb;

    // Common pools
    PoolKey public wethUsdcPool;
    PoolKey public usdcUsdtPool;
    PoolKey public wethCakePool;
    PoolKey public cakeUsdcPool;

    // Test users
    address public alice;
    address public bob;
    address public carol;
    address public liquidityProvider_user;

    // Event definitions
    event TestStarted(string testName);
    event TestCompleted(string testName, bool success);
    event DEXStateSnapshot(string label, uint256 timestamp);

    /**
     * @notice Setup testing environment
     * @dev Subclasses must call this function in setUp
     */
    function setupDEXEnvironment() internal {
        console.log("====================================");
        console.log("Setting up PancakeSwap Infinity testing environment");
        console.log("====================================");

        // Setup test users
        setupTestUsers();

        // Deploy core contracts (in actual testing, these should be pre-deployed)
        deployCoreContracts();

        // Deploy testing tools
        deployTestingTools();

        // Create test tokens
        createTestTokens();

        // Create test pools
        createTestPools();

        // Add initial liquidity to pools
        addInitialLiquidity();

        // Distribute tokens to test users
        distributeTokensToUsers();

        console.log("====================================");
        console.log("DEX test environment setup completed");
        console.log("====================================");
    }

    /**
     * @notice Setup test users
     */
    function setupTestUsers() internal {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        liquidityProvider_user = makeAddr("liquidityProvider");

        // Give test users some ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(liquidityProvider_user, 100 ether);

        console.log("Test users setup completed:");
        console.log("  Alice:", alice);
        console.log("  Bob:", bob);
        console.log("  Carol:", carol);
        console.log("  LP User:", liquidityProvider_user);
    }

    /**
     * @notice Deploy core contracts
     * @dev In actual usage, these contracts should already be deployed
     */
    function deployCoreContracts() internal virtual {
        // TODO: Deploy or connect to existing core contracts
        // This should be modified according to actual situation
        console.log("Core contract deployment - to be implemented");
        console.log("In actual testing, should connect to pre-deployed contracts");
    }

    /**
     * @notice Deploy testing tools
     */
    function deployTestingTools() internal {
        tokenFactory = new TestTokenFactory();
        tokenFaucet = new TokenFaucet();
        poolInitializer = new PoolInitializer(address(clPoolManager), address(binPoolManager));
        liquidityProvider = new LiquidityProvider(address(vault), address(clPoolManager), address(binPoolManager));
        dexHelpers = new DEXInteractionHelpers(address(vault), address(clPoolManager), address(binPoolManager));

        console.log("Testing tools deployed:");
        console.log("  Token Factory:", address(tokenFactory));
        console.log("  Token Faucet:", address(tokenFaucet));
        console.log("  Pool Initializer:", address(poolInitializer));
        console.log("  Liquidity Provider:", address(liquidityProvider));
        console.log("  DEX Helpers:", address(dexHelpers));
    }

    /**
     * @notice Create test tokens
     */
    function createTestTokens() internal {
        weth = IERC20(tokenFactory.createToken("Wrapped Ether", "WETH", 18, 1000000 * 10 ** 18));
        usdc = IERC20(tokenFactory.createToken("USD Coin", "USDC", 6, 1000000 * 10 ** 6));
        usdt = IERC20(tokenFactory.createToken("Tether USD", "USDT", 6, 1000000 * 10 ** 6));
        cake = IERC20(tokenFactory.createToken("PancakeSwap Token", "CAKE", 18, 1000000 * 10 ** 18));
        bnb = IERC20(tokenFactory.createToken("BNB", "BNB", 18, 1000000 * 10 ** 18));

        // Configure faucet
        tokenFaucet.addToken(address(weth), 100 * 10 ** 18, 3600); // 100 WETH per claim, 1 hour cooldown
        tokenFaucet.addToken(address(usdc), 10000 * 10 ** 6, 3600); // 10,000 USDC per claim, 1 hour cooldown
        tokenFaucet.addToken(address(usdt), 10000 * 10 ** 6, 3600); // 10,000 USDT per claim, 1 hour cooldown
        tokenFaucet.addToken(address(cake), 1000 * 10 ** 18, 3600); // 1,000 CAKE per claim, 1 hour cooldown
        tokenFaucet.addToken(address(bnb), 100 * 10 ** 18, 3600); // 100 BNB per claim, 1 hour cooldown

        console.log("Test tokens created:");
        console.log("  WETH:", address(weth));
        console.log("  USDC:", address(usdc));
        console.log("  USDT:", address(usdt));
        console.log("  CAKE:", address(cake));
        console.log("  BNB:", address(bnb));
    }

    /**
     * @notice Create test pools
     */
    function createTestPools() internal virtual {
        // TODO: Use poolInitializer to create various test pools
        console.log("Test pool creation - to be implemented");
        console.log("Need to create WETH/USDC, USDC/USDT, WETH/CAKE, CAKE/USDC and other pools");
    }

    /**
     * @notice Add initial liquidity
     */
    function addInitialLiquidity() internal virtual {
        // TODO: Use liquidityProvider to add initial liquidity to pools
        console.log("Initial liquidity addition - to be implemented");
    }

    /**
     * @notice Distribute tokens to test users
     */
    function distributeTokensToUsers() internal {
        address[] memory users = new address[](4);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
        users[3] = liquidityProvider_user;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            // Transfer test tokens to user
            weth.transfer(user, 10 * 10 ** 18); // 10 WETH
            usdc.transfer(user, 20000 * 10 ** 6); // 20,000 USDC
            usdt.transfer(user, 20000 * 10 ** 6); // 20,000 USDT
            cake.transfer(user, 5000 * 10 ** 18); // 5,000 CAKE
            bnb.transfer(user, 50 * 10 ** 18); // 50 BNB

            console.log("Tokens distributed to user:", user);
        }
    }

    // ========== Test Helper Functions ==========

    /**
     * @notice Start test
     */
    function startTest(string memory testName) internal {
        emit TestStarted(testName);
        console.log("\n[TEST START]", testName);
    }

    /**
     * @notice End test
     */
    function endTest(string memory testName, bool success) internal {
        emit TestCompleted(testName, success);
        console.log("[TEST END]", testName, success ? "PASSED" : "FAILED");
    }

    /**
     * @notice Take DEX state snapshot
     */
    function snapshotDEXState(string memory label) internal {
        emit DEXStateSnapshot(label, block.timestamp);
        console.log("\n[SNAPSHOT]", label);

        // Record important state information
        console.log("Block timestamp:", block.timestamp);
        console.log("Block number:", block.number);

        // TODO: Record pool state, prices, liquidity and other information
    }

    /**
     * @notice Check token balance
     */
    function checkBalance(address user, IERC20 token, string memory tokenName) internal view returns (uint256) {
        uint256 balance = token.balanceOf(user);
        console.log("%s balance of %s: %s", tokenName, user, balance);
        return balance;
    }

    /**
     * @notice Check all users' token balances
     */
    function checkAllBalances() internal view {
        address[] memory users = new address[](4);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
        users[3] = liquidityProvider_user;

        string[] memory userNames = new string[](4);
        userNames[0] = "Alice";
        userNames[1] = "Bob";
        userNames[2] = "Carol";
        userNames[3] = "LP User";

        for (uint256 i = 0; i < users.length; i++) {
            console.log("\n%s balances:", userNames[i]);
            checkBalance(users[i], weth, "WETH");
            checkBalance(users[i], usdc, "USDC");
            checkBalance(users[i], usdt, "USDT");
            checkBalance(users[i], cake, "CAKE");
            checkBalance(users[i], bnb, "BNB");
        }
    }

    // ========== Common Interaction Functions ==========

    /**
     * @notice User claims tokens from faucet
     */
    function claimFromFaucet(address user, IERC20 token) internal {
        vm.startPrank(user);
        tokenFaucet.claimToken(address(token));
        vm.stopPrank();
    }

    /**
     * @notice User batch claims all tokens
     */
    function claimAllFromFaucet(address user) internal {
        vm.startPrank(user);
        tokenFaucet.claimAllTokens();
        vm.stopPrank();
    }

    /**
     * @notice Simulate time passage (to bypass cooldown period)
     */
    function skipTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
        console.log("Time advanced by", seconds_, "seconds");
    }

    /**
     * @notice Assert token balance
     */
    function assertBalance(address user, IERC20 token, uint256 expectedBalance, string memory message) internal {
        uint256 actualBalance = token.balanceOf(user);
        assertEq(actualBalance, expectedBalance, message);
    }

    /**
     * @notice Assert token balance is greater than a value
     */
    function assertBalanceGreaterThan(address user, IERC20 token, uint256 minBalance, string memory message) internal {
        uint256 actualBalance = token.balanceOf(user);
        assertGt(actualBalance, minBalance, message);
    }

    // ========== Custom Assertion Functions ==========

    /**
     * @notice Assert swap successful
     */
    function assertSwapSuccessful(
        address user,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 expectedMinAmountOut
    ) internal {
        uint256 balanceInBefore = tokenIn.balanceOf(user);
        uint256 balanceOutBefore = tokenOut.balanceOf(user);

        // Execute swap (actual swap logic needed here)
        // TODO: Implement actual swap call

        uint256 balanceInAfter = tokenIn.balanceOf(user);
        uint256 balanceOutAfter = tokenOut.balanceOf(user);

        assertEq(balanceInBefore - balanceInAfter, amountIn, "Input amount mismatch");
        assertGe(balanceOutAfter - balanceOutBefore, expectedMinAmountOut, "Insufficient output amount");
    }

    // ========== Virtual Functions - To be implemented by subclasses ==========

    /**
     * @notice Custom test logic - to be implemented by subclasses
     */
    function runCustomTests() internal virtual {
        // Subclasses should override this function to implement custom tests
    }

    /**
     * @notice Main test function
     * @dev Subclasses can override this function or directly implement functions starting with test
     */
    function testIntegration() public virtual {
        startTest("Integration Test");

        // Check initial state
        snapshotDEXState("Initial State");
        checkAllBalances();

        // Run custom tests
        runCustomTests();

        // Check final state
        snapshotDEXState("Final State");
        checkAllBalances();

        endTest("Integration Test", true);
    }
}
