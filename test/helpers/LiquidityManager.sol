// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

// Core imports
import {IVault} from "../../src/core/interfaces/IVault.sol";
import {ILockCallback} from "../../src/core/interfaces/ILockCallback.sol";
import {ICLPoolManager} from "../../src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {Currency} from "../../src/core/types/Currency.sol";
import {PoolKey} from "../../src/core/types/PoolKey.sol";
import {PoolId} from "../../src/core/types/PoolId.sol";
import {BalanceDelta} from "../../src/core/types/BalanceDelta.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title LiquidityManager
 * @notice Manager contract for adding/removing liquidity through the real Vault and CLPoolManager
 * @dev Implements ILockCallback to interact with Vault's lock mechanism
 */
contract LiquidityManager is ILockCallback {
    IVault public immutable vault;
    ICLPoolManager public immutable clPoolManager;

    struct AddLiquidityParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityDelta;
        address recipient;
    }

    struct RemoveLiquidityParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityDelta;
        address recipient;
    }

    struct CallbackData {
        address sender;
        bool isAdd;
        AddLiquidityParams addParams;
        RemoveLiquidityParams removeParams;
    }

    event LiquidityAdded(
        address indexed provider,
        PoolId indexed poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event LiquidityRemoved(
        address indexed provider,
        PoolId indexed poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    constructor(address _vault, address _clPoolManager) {
        vault = IVault(_vault);
        clPoolManager = ICLPoolManager(_clPoolManager);
    }

    /**
     * @notice Add liquidity to a pool
     * @param params Add liquidity parameters
     * @return liquidity Amount of liquidity added
     * @return amount0 Amount of token0 added
     * @return amount1 Amount of token1 added
     */
    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // Prepare callback data
        CallbackData memory data = CallbackData({
            sender: msg.sender,
            isAdd: true,
            addParams: params,
            removeParams: RemoveLiquidityParams({
                poolKey: params.poolKey,
                tickLower: 0,
                tickUpper: 0,
                liquidityDelta: 0,
                recipient: address(0)
            })
        });

        // Execute through vault lock
        bytes memory result = vault.lock(abi.encode(data));
        (liquidity, amount0, amount1) = abi.decode(result, (uint128, uint256, uint256));

        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit LiquidityAdded(msg.sender, poolId, params.tickLower, params.tickUpper, liquidity, amount0, amount1);

        console.log("Liquidity added:");
        console.log("  Liquidity units:", liquidity);
        console.log("  Token0 amount:", amount0);
        console.log("  Token1 amount:", amount1);

        return (liquidity, amount0, amount1);
    }

    /**
     * @notice Remove liquidity from a pool
     * @param params Remove liquidity parameters
     * @return amount0 Amount of token0 received
     * @return amount1 Amount of token1 received
     */
    function removeLiquidity(RemoveLiquidityParams memory params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Prepare callback data
        CallbackData memory data = CallbackData({
            sender: msg.sender,
            isAdd: false,
            addParams: AddLiquidityParams({
                poolKey: params.poolKey,
                tickLower: 0,
                tickUpper: 0,
                liquidityDelta: 0,
                recipient: address(0)
            }),
            removeParams: params
        });

        // Execute through vault lock
        bytes memory result = vault.lock(abi.encode(data));
        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit LiquidityRemoved(
            msg.sender,
            poolId,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            amount0,
            amount1
        );

        console.log("Liquidity removed:");
        console.log("  Token0 received:", amount0);
        console.log("  Token1 received:", amount1);

        return (amount0, amount1);
    }

    /**
     * @notice Callback from Vault during lock
     * @dev This is where the actual liquidity management logic executes
     */
    function lockAcquired(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(vault), "Only vault");

        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        if (callbackData.isAdd) {
            return _handleAddLiquidity(callbackData);
        } else {
            return _handleRemoveLiquidity(callbackData);
        }
    }

    /**
     * @notice Handle add liquidity operation
     */
    function _handleAddLiquidity(CallbackData memory data) internal returns (bytes memory) {
        AddLiquidityParams memory params = data.addParams;

        // Call modifyLiquidity on CLPoolManager
        (BalanceDelta delta, BalanceDelta feeDelta) = clPoolManager.modifyLiquidity(
            params.poolKey,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: int128(params.liquidityDelta),
                salt: bytes32(0)
            }),
            ""
        );

        // Handle token settlement
        _settleLiquidity(data.sender, params.poolKey, delta);

        // Calculate actual amounts used
        uint256 amount0 = uint128(-delta.amount0());
        uint256 amount1 = uint128(-delta.amount1());

        return abi.encode(params.liquidityDelta, amount0, amount1);
    }

    /**
     * @notice Handle remove liquidity operation
     */
    function _handleRemoveLiquidity(CallbackData memory data) internal returns (bytes memory) {
        RemoveLiquidityParams memory params = data.removeParams;

        // Call modifyLiquidity with negative delta to remove
        (BalanceDelta delta, BalanceDelta feeDelta) = clPoolManager.modifyLiquidity(
            params.poolKey,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: -int128(params.liquidityDelta),
                salt: bytes32(0)
            }),
            ""
        );

        // Handle token settlement (tokens flow back to user)
        _settleLiquidityRemoval(params.recipient, params.poolKey, delta);

        // Calculate actual amounts received
        uint256 amount0 = uint128(delta.amount0());
        uint256 amount1 = uint128(delta.amount1());

        return abi.encode(amount0, amount1);
    }

    /**
     * @notice Settle liquidity addition with vault
     */
    function _settleLiquidity(address sender, PoolKey memory poolKey, BalanceDelta delta) internal {
        // Since LiquidityManager is registered as an App, CLPoolManager calls
        // accountAppBalanceDelta which records the delta to this contract.
        // We need to settle these deltas by transferring tokens from sender to vault.
        
        // The delta represents what this contract owes (negative) or is owed (positive)
        // For adding liquidity, deltas are negative (we owe tokens to the vault)
        
        // Handle currency0
        int256 delta0 = vault.currencyDelta(address(this), poolKey.currency0);
        if (delta0 < 0) {
            console.log("Currency0 delta (negative):", uint256(-delta0));
            uint256 amount = uint256(-delta0);
            console.log("Settling currency0 amount:", amount);
            // Transfer from sender to this contract, then to vault
            IERC20(Currency.unwrap(poolKey.currency0)).transferFrom(sender, address(this), amount);
            IERC20(Currency.unwrap(poolKey.currency0)).transfer(address(vault), amount);
            vault.sync(poolKey.currency0);
            vault.settle();
        }

        // Handle currency1
        int256 delta1 = vault.currencyDelta(address(this), poolKey.currency1);
        if (delta1 < 0) {
            console.log("Currency1 delta (negative):", uint256(-delta1));
            uint256 amount = uint256(-delta1);
            console.log("Settling currency1 amount:", amount);
            // Transfer from sender to this contract, then to vault
            IERC20(Currency.unwrap(poolKey.currency1)).transferFrom(sender, address(this), amount);
            IERC20(Currency.unwrap(poolKey.currency1)).transfer(address(vault), amount);
            vault.sync(poolKey.currency1);
            vault.settle();
        }
        
        // Check final deltas
        int256 finalDelta0 = vault.currencyDelta(address(this), poolKey.currency0);
        int256 finalDelta1 = vault.currencyDelta(address(this), poolKey.currency1);
        
        if (finalDelta0 < 0) {
            console.log("Final currency0 delta still negative:", uint256(-finalDelta0));
        } else if (finalDelta0 > 0) {
            console.log("Final currency0 delta positive:", uint256(finalDelta0));
        } else {
            console.log("Final currency0 delta is zero");
        }
        
        if (finalDelta1 < 0) {
            console.log("Final currency1 delta still negative:", uint256(-finalDelta1));
        } else if (finalDelta1 > 0) {
            console.log("Final currency1 delta positive:", uint256(finalDelta1));
        } else {
            console.log("Final currency1 delta is zero");
        }
    }

    /**
     * @notice Settle liquidity removal with vault
     */
    function _settleLiquidityRemoval(address recipient, PoolKey memory poolKey, BalanceDelta delta) internal {
        // For removing liquidity, delta is positive (user receives tokens)
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        
        if (amount0 > 0) {
            vault.take(poolKey.currency0, recipient, uint128(amount0));
        }

        if (amount1 > 0) {
            vault.take(poolKey.currency1, recipient, uint128(amount1));
        }
    }

    /**
     * @notice Helper to add liquidity around current price
     */
    function addLiquidityAroundCurrentPrice(
        PoolKey memory poolKey,
        int24 tickRange,
        uint128 liquidityDelta,
        address recipient
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        // Get current tick from pool
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        (, int24 currentTick, , ) = clPoolManager.getSlot0(poolId);

        // Calculate tick range
        int24 tickSpacing = _getTickSpacing(poolKey);
        int24 tickLower = ((currentTick - tickRange) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + tickRange) / tickSpacing) * tickSpacing;

        // Add liquidity (call this function internally)
        AddLiquidityParams memory params = AddLiquidityParams({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            recipient: recipient
        });
        
        // Execute through vault lock (internal implementation)
        CallbackData memory data = CallbackData({
            sender: msg.sender,
            isAdd: true,
            addParams: params,
            removeParams: RemoveLiquidityParams({
                poolKey: poolKey,
                tickLower: 0,
                tickUpper: 0,
                liquidityDelta: 0,
                recipient: address(0)
            })
        });

        bytes memory result = vault.lock(abi.encode(data));
        (liquidity, amount0, amount1) = abi.decode(result, (uint128, uint256, uint256));
        
        PoolId poolId2 = PoolId.wrap(keccak256(abi.encode(poolKey)));
        emit LiquidityAdded(msg.sender, poolId2, tickLower, tickUpper, liquidity, amount0, amount1);
        
        return (liquidity, amount0, amount1);
    }

    /**
     * @notice Get tick spacing from pool key parameters
     */
    function _getTickSpacing(PoolKey memory poolKey) internal pure returns (int24) {
        // Extract tick spacing from parameters
        // This is simplified - actual implementation would decode from parameters
        return 60; // Default tick spacing for 0.3% fee tier
    }
}