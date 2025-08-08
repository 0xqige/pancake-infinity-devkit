// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

// Core contract imports
import {Currency} from "@src/core/types/Currency.sol";
import {PoolKey} from "@src/core/types/PoolKey.sol";
import {PoolId} from "@src/core/types/PoolId.sol";
import {IVault} from "@src/core/interfaces/IVault.sol";
import {ILockCallback} from "@src/core/interfaces/ILockCallback.sol";
import {ICLPoolManager} from "@src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "@src/core/pool-bin/interfaces/IBinPoolManager.sol";

// Types and libraries import
import {BalanceDelta} from "@src/core/types/BalanceDelta.sol";
import {CLPoolParametersHelper} from "@src/core/pool-cl/libraries/CLPoolParametersHelper.sol";
import {BinPoolParametersHelper} from "@src/core/pool-bin/libraries/BinPoolParametersHelper.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title LiquidityProvider
 * @notice Liquidity provider for adding initial liquidity to pools
 * @dev Supports liquidity management for CL pools and Bin pools
 */
contract LiquidityProvider is ILockCallback {
    using CLPoolParametersHelper for bytes32;
    using BinPoolParametersHelper for bytes32;

    IVault public immutable vault;
    ICLPoolManager public immutable clPoolManager;
    IBinPoolManager public immutable binPoolManager;

    struct CLLiquidityParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityDelta;
        bytes32 salt;
    }

    struct BinLiquidityParams {
        PoolKey poolKey;
        bytes32[] liquidityConfigs; // Bin liquidity configuration
        bytes32 amountIn; // Input amount (packed X,Y)
        bytes32 salt;
    }

    event CLLiquidityAdded(
        PoolId indexed poolId, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1
    );

    event BinLiquidityAdded(PoolId indexed poolId, uint256[] binIds, bytes32[] amounts, uint256[] liquidityMinted);

    constructor(address _vault, address _clPoolManager, address _binPoolManager) {
        vault = IVault(_vault);
        clPoolManager = ICLPoolManager(_clPoolManager);
        binPoolManager = IBinPoolManager(_binPoolManager);
    }

    /**
     * @notice Add liquidity to CL pool
     * @param params Liquidity parameters
     */
    function addCLLiquidity(CLLiquidityParams memory params) public {
        // Transfer tokens to this contract in advance
        _transferTokensIn(params.poolKey.currency0, params.poolKey.currency1);

        // Execute through Vault lock
        bytes memory data = abi.encode("CL_ADD_LIQUIDITY", params);
        vault.lock(data);
    }

    /**
     * @notice Add liquidity to Bin pool
     * @param params Liquidity parameters
     */
    function addBinLiquidity(BinLiquidityParams memory params) external {
        // Transfer tokens to this contract in advance
        _transferTokensIn(params.poolKey.currency0, params.poolKey.currency1);

        // Execute through Vault lock
        bytes memory data = abi.encode("BIN_ADD_LIQUIDITY", params);
        vault.lock(data);
    }

    /**
     * @notice Vault lock callback function
     */
    function lockAcquired(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(vault), "Only vault");

        (string memory action, bytes memory params) = abi.decode(data, (string, bytes));

        if (keccak256(bytes(action)) == keccak256("CL_ADD_LIQUIDITY")) {
            return _addCLLiquidityCallback(abi.decode(params, (CLLiquidityParams)));
        } else if (keccak256(bytes(action)) == keccak256("BIN_ADD_LIQUIDITY")) {
            return _addBinLiquidityCallback(abi.decode(params, (BinLiquidityParams)));
        }

        revert("Unknown action");
    }

    /**
     * @notice CL pool liquidity addition callback
     */
    function _addCLLiquidityCallback(CLLiquidityParams memory params) internal returns (bytes memory) {
        // Modify liquidity
        (BalanceDelta delta,) = clPoolManager.modifyLiquidity(
            params.poolKey,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: int128(params.liquidityDelta),
                salt: params.salt
            }),
            ""
        );

        // Settle tokens
        _settleCurrencies(params.poolKey.currency0, params.poolKey.currency1, delta);

        // Record event
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit CLLiquidityAdded(
            poolId,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            uint256(int256(-delta.amount0())),
            uint256(int256(-delta.amount1()))
        );

        console.log("Added liquidity to CL pool:");
        console.log("  Pool ID:", uint256(PoolId.unwrap(poolId)));
        console.log("  Tick Range:", uint256(int256(params.tickLower)), "to", uint256(int256(params.tickUpper)));
        console.log("  Liquidity:", params.liquidityDelta);

        return "";
    }

    /**
     * @notice Bin pool liquidity addition callback
     */
    function _addBinLiquidityCallback(BinLiquidityParams memory params) internal returns (bytes memory) {
        // TODO: Implement Bin pool liquidity addition logic
        // This needs to be implemented according to actual BinPoolManager interface

        console.log("Bin pool liquidity addition - to be implemented");
        return "";
    }

    /**
     * @notice Settle currency balances
     */
    function _settleCurrencies(Currency currency0, Currency currency1, BalanceDelta delta) internal {
        // Handle currency0
        if (delta.amount0() > 0) {
            // Take tokens from Vault
            vault.take(currency0, address(this), uint256(int256(delta.amount0())));
        } else if (delta.amount0() < 0) {
            // Deposit tokens to Vault
            vault.settle();
        }

        // Handle currency1
        if (delta.amount1() > 0) {
            // Take tokens from Vault
            vault.take(currency1, address(this), uint256(int256(delta.amount1())));
        } else if (delta.amount1() < 0) {
            // Deposit tokens to Vault
            vault.settle();
        }
    }

    /**
     * @notice Transfer tokens in advance (simplified implementation, should calculate precisely based on needs in practice)
     */
    function _transferTokensIn(Currency currency0, Currency currency1) internal {
        // Get sufficient token balance for adding liquidity
        uint256 amount0 = 1000000 * 10 ** 18; // Large amount, ensure sufficient
        uint256 amount1 = 1000000 * 10 ** 18;

        if (!currency0.isNative()) {
            IERC20(Currency.unwrap(currency0)).transferFrom(msg.sender, address(this), amount0);
            IERC20(Currency.unwrap(currency0)).approve(address(vault), amount0);
        }

        if (!currency1.isNative()) {
            IERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, address(this), amount1);
            IERC20(Currency.unwrap(currency1)).approve(address(vault), amount1);
        }
    }

    /**
     * @notice Convenience function: Add symmetric liquidity to CL pool
     */
    function addCLLiquiditySymmetric(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidityDelta)
        public
    {
        CLLiquidityParams memory params = CLLiquidityParams({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });

        addCLLiquidity(params);
    }

    /**
     * @notice Convenience function: Add liquidity around current price range of pool
     */
    function addCLLiquidityAroundCurrentPrice(
        PoolKey memory poolKey,
        int24 tickRange, // Price range scope (±tickRange)
        uint128 liquidityDelta
    ) public {
        // Get current price
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        (uint160 sqrtPriceX96, int24 currentTick,,) = clPoolManager.getSlot0(poolId);

        // Get tick spacing
        int24 tickSpacing = poolKey.parameters.getTickSpacing();

        // Calculate aligned tick boundaries
        int24 tickLower = ((currentTick - tickRange) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + tickRange) / tickSpacing) * tickSpacing;

        // Ensure tick is within valid range
        if (tickLower < -887272) tickLower = -887272;
        if (tickUpper > 887272) tickUpper = 887272;

        addCLLiquiditySymmetric(poolKey, tickLower, tickUpper, liquidityDelta);

        console.log("Added liquidity around current price:");
        console.log("  Current Tick:", uint256(int256(currentTick)));
        console.log("  Liquidity Range:", uint256(int256(tickLower)), "to", uint256(int256(tickUpper)));
    }

    /**
     * @notice Emergency token withdrawal
     */
    function emergencyWithdraw(Currency currency, uint256 amount) external {
        if (currency.isNative()) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(Currency.unwrap(currency)).transfer(msg.sender, amount);
        }
    }

    /**
     * @notice Batch add liquidity to multiple CL pools
     */
    function batchAddCLLiquidity(CLLiquidityParams[] memory paramsArray) external {
        for (uint256 i = 0; i < paramsArray.length; i++) {
            addCLLiquidity(paramsArray[i]);
        }
    }

    /**
     * @notice Check this contract's token balance
     */
    function getBalance(Currency currency) external view returns (uint256) {
        if (currency.isNative()) {
            return address(this).balance;
        } else {
            return IERC20(Currency.unwrap(currency)).balanceOf(address(this));
        }
    }

    // Receive ETH
    receive() external payable {}
}
