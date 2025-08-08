// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

// Core contract imports
import {Currency} from "@src/core/types/Currency.sol";
import {PoolKey} from "@src/core/types/PoolKey.sol";
import {PoolId} from "@src/core/types/PoolId.sol";
import {IHooks} from "@src/core/interfaces/IHooks.sol";
import {IPoolManager} from "@src/core/interfaces/IPoolManager.sol";
import {ICLPoolManager} from "@src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "@src/core/pool-bin/interfaces/IBinPoolManager.sol";

// Parameter helper libraries
import {CLPoolParametersHelper} from "@src/core/pool-cl/libraries/CLPoolParametersHelper.sol";
import {BinPoolParametersHelper} from "@src/core/pool-bin/libraries/BinPoolParametersHelper.sol";

// Tick and Price related libraries
import {TickMath} from "@src/core/pool-cl/libraries/TickMath.sol";

/**
 * @title PoolInitializer
 * @notice Pool initializer for creating and initializing various types of trading pools
 * @dev Supports creation and initialization of CL pools and Bin pools
 */
contract PoolInitializer {
    using CLPoolParametersHelper for bytes32;
    using BinPoolParametersHelper for bytes32;

    ICLPoolManager public immutable clPoolManager;
    IBinPoolManager public immutable binPoolManager;

    struct CLPoolConfig {
        Currency currency0; // Token 0
        Currency currency1; // Token 1
        uint24 fee; // Fee tier
        int24 tickSpacing; // Tick spacing
        IHooks hooks; // Hook contract address
        uint160 sqrtPriceX96; // Initial price
    }

    struct BinPoolConfig {
        Currency currency0; // Token 0
        Currency currency1; // Token 1
        uint24 fee; // Fee tier
        uint16 binStep; // Bin step
        IHooks hooks; // Hook contract address
        uint24 activeId; // Initial active Bin ID
    }

    event CLPoolCreated(
        PoolId indexed poolId,
        Currency indexed currency0,
        Currency indexed currency1,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    );

    event BinPoolCreated(
        PoolId indexed poolId,
        Currency indexed currency0,
        Currency indexed currency1,
        uint24 fee,
        uint16 binStep,
        uint24 activeId
    );

    constructor(address _clPoolManager, address _binPoolManager) {
        clPoolManager = ICLPoolManager(_clPoolManager);
        binPoolManager = IBinPoolManager(_binPoolManager);
    }

    /**
     * @notice Create CL pool
     * @param config Pool configuration
     * @return poolKey Pool key
     * @return poolId Pool ID
     */
    function createCLPool(CLPoolConfig memory config) public returns (PoolKey memory poolKey, PoolId poolId) {
        // Ensure token order is correct
        require(Currency.unwrap(config.currency0) < Currency.unwrap(config.currency1), "Currencies not sorted");

        // Build pool key
        poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            hooks: config.hooks,
            poolManager: IPoolManager(address(clPoolManager)),
            fee: config.fee,
            parameters: CLPoolParametersHelper.setTickSpacing(bytes32(0), config.tickSpacing)
        });

        // Get pool ID
        poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));

        // Initialize pool
        clPoolManager.initialize(poolKey, config.sqrtPriceX96);

        emit CLPoolCreated(
            poolId, config.currency0, config.currency1, config.fee, config.tickSpacing, config.sqrtPriceX96
        );

        console.log("CL pool created:");
        console.log("  Pool ID:", uint256(PoolId.unwrap(poolId)));
        console.log("  Currency0:", Currency.unwrap(config.currency0));
        console.log("  Currency1:", Currency.unwrap(config.currency1));
        console.log("  Fee:", config.fee);
        console.log("  Tick Spacing:", uint256(int256(config.tickSpacing)));
    }

    /**
     * @notice Create Bin pool
     * @param config Pool configuration
     * @return poolKey Pool key
     * @return poolId Pool ID
     */
    function createBinPool(BinPoolConfig memory config) public returns (PoolKey memory poolKey, PoolId poolId) {
        // Ensure token order is correct
        require(Currency.unwrap(config.currency0) < Currency.unwrap(config.currency1), "Currencies not sorted");

        // Build pool key
        poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            hooks: config.hooks,
            poolManager: IPoolManager(address(binPoolManager)),
            fee: config.fee,
            parameters: BinPoolParametersHelper.setBinStep(bytes32(0), config.binStep)
        });

        // Get pool ID
        poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));

        // Initialize pool
        binPoolManager.initialize(poolKey, config.activeId);

        emit BinPoolCreated(poolId, config.currency0, config.currency1, config.fee, config.binStep, config.activeId);

        console.log("Bin pool created:");
        console.log("  Pool ID:", uint256(PoolId.unwrap(poolId)));
        console.log("  Currency0:", Currency.unwrap(config.currency0));
        console.log("  Currency1:", Currency.unwrap(config.currency1));
        console.log("  Fee:", config.fee);
        console.log("  Bin Step:", config.binStep);
        console.log("  Active ID:", config.activeId);
    }

    /**
     * @notice Create common stablecoin CL pool (USDC/USDT, 0.01% fee, 1 tick spacing)
     */
    function createStablecoinCLPool(Currency usdc, Currency usdt)
        public
        returns (PoolKey memory poolKey, PoolId poolId)
    {
        CLPoolConfig memory config = CLPoolConfig({
            currency0: usdc,
            currency1: usdt,
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(0)),
            sqrtPriceX96: 79228162514264337593543950336 // price = 1.0
        });

        return createCLPool(config);
    }

    /**
     * @notice Create ETH/USDC CL pool (0.3% fee, 60 tick spacing)
     */
    function createETHUSDCCLPool(Currency weth, Currency usdc, uint160 initialPrice)
        public
        returns (PoolKey memory poolKey, PoolId poolId)
    {
        CLPoolConfig memory config = CLPoolConfig({
            currency0: Currency.unwrap(weth) < Currency.unwrap(usdc) ? weth : usdc,
            currency1: Currency.unwrap(weth) < Currency.unwrap(usdc) ? usdc : weth,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(address(0)),
            sqrtPriceX96: initialPrice
        });

        return createCLPool(config);
    }

    /**
     * @notice Create volatile token Bin pool (1% fee, 25 binStep)
     */
    function createVolatileBinPool(Currency token0, Currency token1, uint24 activeId)
        public
        returns (PoolKey memory poolKey, PoolId poolId)
    {
        BinPoolConfig memory config = BinPoolConfig({
            currency0: Currency.unwrap(token0) < Currency.unwrap(token1) ? token0 : token1,
            currency1: Currency.unwrap(token0) < Currency.unwrap(token1) ? token1 : token0,
            fee: 10000, // 1%
            binStep: 25, // 0.25%
            hooks: IHooks(address(0)),
            activeId: activeId
        });

        return createBinPool(config);
    }

    /**
     * @notice Batch create common trading pair pools
     */
    function createCommonPools(Currency weth, Currency usdc, Currency usdt, Currency cake)
        external
        returns (PoolKey[] memory poolKeys, PoolId[] memory poolIds)
    {
        poolKeys = new PoolKey[](4);
        poolIds = new PoolId[](4);

        // 1. USDC/USDT stablecoin pool
        (poolKeys[0], poolIds[0]) = createStablecoinCLPool(
            Currency.unwrap(usdc) < Currency.unwrap(usdt) ? usdc : usdt,
            Currency.unwrap(usdc) < Currency.unwrap(usdt) ? usdt : usdc
        );

        // 2. WETH/USDC mainstream token pool
        (poolKeys[1], poolIds[1]) = createETHUSDCCLPool(weth, usdc, 1252685732681638614896909568); // ~$2000

        // 3. WETH/CAKE Bin pool
        (poolKeys[2], poolIds[2]) = createVolatileBinPool(weth, cake, 8388608); // 2^23

        // 4. CAKE/USDC CL pool
        CLPoolConfig memory cakeUsdcConfig = CLPoolConfig({
            currency0: Currency.unwrap(cake) < Currency.unwrap(usdc) ? cake : usdc,
            currency1: Currency.unwrap(cake) < Currency.unwrap(usdc) ? usdc : cake,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(address(0)),
            sqrtPriceX96: 499786143710555466608128000 // ~$4 CAKE
        });
        (poolKeys[3], poolIds[3]) = createCLPool(cakeUsdcConfig);

        console.log("Created", poolKeys.length, "common trading pair pools");
    }

    /**
     * @notice Calculate sqrtPriceX96 based on price
     * @param price0In1 Price of currency0 denominated in currency1 (18 decimals)
     * @return sqrtPriceX96
     */
    function encodePriceToSqrtPriceX96(uint256 price0In1) external pure returns (uint160 sqrtPriceX96) {
        // price0In1 = price * 1e18
        // sqrtPriceX96 = sqrt(price) * 2^96
        uint256 priceX192 = price0In1 * (2 ** 192) / 1e18;
        sqrtPriceX96 = uint160(sqrt(priceX192));
    }

    /**
     * @notice Calculate square root (for price conversion)
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
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

    /**
     * @notice Check if pool exists
     */
    function poolExists(PoolKey memory poolKey) external view returns (bool) {
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));

        // Try to check pool state to determine if it exists
        try clPoolManager.getSlot0(poolId) {
            return true;
        } catch {
            try binPoolManager.getSlot0(poolId) {
                return true;
            } catch {
                return false;
            }
        }
    }

    /**
     * @notice Get sqrtPrice corresponding to tick
     */
    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    /**
     * @notice Get corresponding tick based on price
     */
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) external pure returns (int24) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }
}
