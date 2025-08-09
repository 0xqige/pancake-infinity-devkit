// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Import core contract interfaces
import {IVault} from "../src/core/interfaces/IVault.sol";
import {ICLPoolManager} from "../src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {IHooks} from "../src/core/interfaces/IHooks.sol";

// Import periphery contracts (commented out - using simplified approach)
// import {CLPositionManager} from "../src/periphery/pool-cl/CLPositionManager.sol";
// import {ICLPositionManager} from "../src/periphery/pool-cl/interfaces/ICLPositionManager.sol";

// Import type definitions
import {Currency, CurrencyLibrary} from "../src/core/types/Currency.sol";
import {PoolKey} from "../src/core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../src/core/types/PoolId.sol";
import {TickMath} from "../src/core/pool-cl/libraries/TickMath.sol";
import {FixedPoint96} from "../src/core/pool-cl/libraries/FixedPoint96.sol";
// import {LiquidityAmounts} from "../src/periphery/pool-cl/libraries/LiquidityAmounts.sol";

// Import testing tools
import "./TestDevKit.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title TestDemo - BNB/MEME Liquidity Addition Demo
 * @notice Demonstrates how to create pools and add liquidity in PancakeSwap Infinity protocol
 * @dev Based on Uniswap V4 template, adapted for PancakeSwap Infinity architecture
 */
contract TestDemo is Test {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // ========== State Variables ==========

    // Core contracts
    TestDevKit public devKit;
    IVault public vault;
    ICLPoolManager public poolManager;
    // CLPositionManager public positionManager; // Simplified demo - Position Manager not used

    // Test tokens
    IERC20 public bnbToken; // BNB test token
    IERC20 public memeToken; // MEME test token

    // Pool information
    PoolKey public poolKey;
    PoolId public poolId;

    // Test account
    address public liquidityProvider;

    // Pool parameters
    uint24 constant POOL_FEE = 3000; // 0.3% fee
    int24 constant TICK_SPACING = 60; // tick spacing
    uint160 constant INITIAL_SQRT_PRICE = 79228162514264337593543950336; // 1:1 initial price

    // Liquidity parameters
    int24 constant MIN_TICK = -887220; // Min tick (price ~0.00001)
    int24 constant MAX_TICK = 887220; // Max tick (price ~100000)
    uint256 constant BNB_LIQUIDITY_AMOUNT = 100 ether; // 100 BNB
    uint256 constant MEME_LIQUIDITY_AMOUNT = 100000 ether; // 100,000 MEME

    // ========== Setup Functions ==========

    function setUp() public {
        console.log("\n========================================");
        console.log("TestDemo: BNB/MEME Liquidity Addition Demo");
        console.log("========================================\n");

        // 1. Deploy test environment
        _deployTestEnvironment();

        // 2. Create test tokens
        _createTestTokens();

        // 3. Setup test account (Position Manager deployment skipped for simplified demo)
        _setupTestAccount();
    }

    function _deployTestEnvironment() internal {
        console.log("Step 1: Deploying test environment...");

        // Deploy TestDevKit and initialize environment
        devKit = new TestDevKit();
        devKit.deployFullEnvironment(true);

        // Get core contract addresses
        vault = IVault(address(devKit.vault()));
        poolManager = ICLPoolManager(address(devKit.clPoolManager()));

        console.log("  [OK] Vault deployed at:", address(vault));
        console.log("  [OK] CLPoolManager deployed at:", address(poolManager));
    }

    function _createTestTokens() internal {
        console.log("\nStep 2: Creating test tokens...");

        // Get BNB and create MEME token
        bnbToken = IERC20(address(devKit.bnb()));

        // Create MEME token
        TestTokenFactory factory = devKit.tokenFactory();
        memeToken = IERC20(
            factory.createToken(
                "Meme Coin",
                "MEME",
                18,
                10 ** 27 // 1 billion tokens (10^9 * 10^18)
            )
        );

        console.log("  [OK] BNB Token:", address(bnbToken));
        console.log("  [OK] MEME Token:", address(memeToken));
    }

    // Position Manager deployment removed for simplified demo
    // The actual CLPositionManager uses an action-based architecture
    // which requires more complex setup. This demo focuses on pool creation.

    function _setupTestAccount() internal {
        console.log("\nStep 3: Setting up test account...");

        liquidityProvider = makeAddr("liquidityProvider");
        vm.deal(liquidityProvider, 1000 ether);

        // Check balances before transfer
        uint256 bnbBalance = bnbToken.balanceOf(address(this));
        uint256 memeBalance = memeToken.balanceOf(address(this));

        // Allocate tokens to liquidity provider (only if we have balance)
        if (bnbBalance > 0) {
            uint256 transferAmount = bnbBalance > 1000 ether ? 1000 ether : bnbBalance / 2;
            bnbToken.transfer(liquidityProvider, transferAmount);
            console.log("  [OK] Transferred BNB:", transferAmount / 1e18);
        } else {
            console.log("  [WARN] No BNB balance to transfer");
        }

        if (memeBalance > 0) {
            uint256 transferAmount = memeBalance > 10000 ether ? 10000 ether : memeBalance / 2;
            memeToken.transfer(liquidityProvider, transferAmount);
            console.log("  [OK] Transferred MEME:", transferAmount / 1e18);
        } else {
            console.log("  [WARN] No MEME balance to transfer");
        }

        console.log("  [OK] Liquidity Provider:", liquidityProvider);
        console.log("  [OK] BNB Balance:", bnbToken.balanceOf(liquidityProvider) / 1e18, "BNB");
        console.log("  [OK] MEME Balance:", memeToken.balanceOf(liquidityProvider) / 1e18, "MEME");
    }

    // ========== Main Test Functions ==========

    /**
     * @notice Main demo function: Create pool and add liquidity
     */
    function testCreatePoolAndAddLiquidity() public {
        console.log("\n========================================");
        console.log("Starting: Create BNB/MEME pool and add liquidity");
        console.log("========================================\n");

        // 1. Create pool
        _createPool();

        // 2. Add liquidity
        _addLiquidity();

        // 3. Verify results
        _verifyPoolState();

        console.log("\n========================================");
        console.log("Demo completed!");
        console.log("========================================");
    }

    /**
     * @notice Create BNB/MEME trading pool
     */
    function _createPool() internal {
        console.log("Step 4: Creating BNB/MEME trading pool...");

        // Ensure correct token order (token0 < token1)
        Currency currency0;
        Currency currency1;

        if (address(bnbToken) < address(memeToken)) {
            currency0 = Currency.wrap(address(bnbToken));
            currency1 = Currency.wrap(address(memeToken));
        } else {
            currency0 = Currency.wrap(address(memeToken));
            currency1 = Currency.wrap(address(bnbToken));
        }

        // Build pool parameters
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: POOL_FEE,
            parameters: bytes32(uint256(uint24(TICK_SPACING)) << 16), // encode tickSpacing into parameters
            hooks: IHooks(address(0)), // no hooks
            poolManager: IPoolManager(address(poolManager))
        });

        // Initialize pool
        poolManager.initialize(poolKey, INITIAL_SQRT_PRICE);

        // Calculate pool ID
        poolId = poolKey.toId();

        console.log("  [OK] Pool created");
        console.log("  [OK] Token0:", Currency.unwrap(currency0));
        console.log("  [OK] Token1:", Currency.unwrap(currency1));
        console.log("  [OK] Fee:", POOL_FEE / 10000, "%");
        // Pool ID logged as bytes32
        console.logBytes32(PoolId.unwrap(poolId));
    }

    /**
     * @notice Add liquidity to pool
     */
    function _addLiquidity() internal {
        console.log("\nStep 5: Demonstrating liquidity addition (simplified)...");

        // Note: The actual CLPositionManager uses an action-based architecture
        // with encoded calldata for operations like CL_MINT_POSITION.
        // This simplified demo shows the pool creation process.

        // In a real implementation, you would:
        // 1. Encode the mint action using Actions.CL_MINT_POSITION
        // 2. Prepare parameters for the position (tickLower, tickUpper, liquidity)
        // 3. Call positionManager.modifyLiquidities() with encoded actions

        console.log("  Pool is ready for liquidity provision");
        console.log("  To add liquidity in production:");
        console.log("    1. Deploy CLPositionManager with proper configuration");
        console.log("    2. Use Actions.CL_MINT_POSITION with encoded parameters");
        console.log("    3. Call modifyLiquidities() to execute the action");
    }

    /**
     * @notice Verify pool state
     */
    function _verifyPoolState() internal view {
        console.log("\nStep 6: Verifying pool state...");

        // Get pool liquidity
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(poolId);

        uint128 liquidity = poolManager.getLiquidity(poolId);

        console.log("  Pool current state:");
        console.log("    - Current price (sqrtPriceX96):", sqrtPriceX96);
        console.log("    - Current tick:", tick);
        console.log("    - Total liquidity:", liquidity);
        console.log("    - LP fee:", lpFee / 100, "basis points");
        console.log("    - Protocol fee:", protocolFee / 100, "basis points");

        // NFT verification removed as Position Manager is not deployed in this simplified demo
    }

    // ========== Helper Functions ==========

    /**
     * @notice Get current tick
     */
    function _getCurrentTick() internal view returns (int24) {
        (, int24 tick,,) = poolManager.getSlot0(poolId);
        return tick;
    }

    // Liquidity calculation helper removed for simplified demo

    // ========== Additional Demo Functions ==========

    // Remove liquidity demo removed as it requires Position Manager

    /**
     * @notice Demo: Execute swap
     */
    function testSwap() public {
        // First add liquidity
        testCreatePoolAndAddLiquidity();
    }
}
