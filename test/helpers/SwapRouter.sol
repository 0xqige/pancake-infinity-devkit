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
import {BeforeSwapDelta} from "../../src/core/types/BeforeSwapDelta.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title SwapRouter
 * @notice Router contract for executing swaps through the real Vault and CLPoolManager
 * @dev Implements ILockCallback to interact with Vault's lock mechanism
 */
contract SwapRouter is ILockCallback {
    IVault public immutable vault;
    ICLPoolManager public immutable clPoolManager;

    struct SwapParams {
        PoolKey poolKey;
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
        address recipient;
    }

    struct CallbackData {
        address sender;
        SwapParams params;
        Currency tokenIn;
        Currency tokenOut;
    }

    event SwapExecuted(
        address indexed sender,
        Currency indexed tokenIn,
        Currency indexed tokenOut,
        int256 amountIn,
        int256 amountOut
    );

    constructor(address _vault, address _clPoolManager) {
        vault = IVault(_vault);
        clPoolManager = ICLPoolManager(_clPoolManager);
    }

    /**
     * @notice Execute a swap
     * @param params Swap parameters
     * @return amountIn Actual input amount
     * @return amountOut Actual output amount
     */
    function swap(SwapParams memory params) external returns (int256 amountIn, int256 amountOut) {
        // Determine input and output tokens
        Currency tokenIn = params.zeroForOne ? params.poolKey.currency0 : params.poolKey.currency1;
        Currency tokenOut = params.zeroForOne ? params.poolKey.currency1 : params.poolKey.currency0;

        // Prepare callback data
        CallbackData memory data = CallbackData({
            sender: msg.sender,
            params: params,
            tokenIn: tokenIn,
            tokenOut: tokenOut
        });

        // Execute swap through vault lock
        bytes memory result = vault.lock(abi.encode(data));
        (amountIn, amountOut) = abi.decode(result, (int256, int256));

        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        console.log("Swap executed:");
        if (amountIn > 0) {
            console.log("  Input:", uint256(amountIn));
        } else {
            console.log("  Input:", uint256(-amountIn));
        }
        if (amountOut > 0) {
            console.log("  Output:", uint256(amountOut));
        } else {
            console.log("  Output:", uint256(-amountOut));
        }

        return (amountIn, amountOut);
    }

    /**
     * @notice Callback from Vault during lock
     * @dev This is where the actual swap logic executes
     */
    function lockAcquired(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(vault), "Only vault");

        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        // Execute the swap on CLPoolManager
        BalanceDelta delta = clPoolManager.swap(
            callbackData.params.poolKey,
            ICLPoolManager.SwapParams({
                zeroForOne: callbackData.params.zeroForOne,
                amountSpecified: callbackData.params.amountSpecified,
                sqrtPriceLimitX96: callbackData.params.sqrtPriceLimitX96
            }),
            ""
        );

        // Handle token settlement
        _settleSwap(callbackData, delta);

        // Calculate actual amounts
        int256 amountIn;
        int256 amountOut;

        if (callbackData.params.zeroForOne) {
            amountIn = -delta.amount0();
            amountOut = delta.amount1();
        } else {
            amountIn = -delta.amount1();
            amountOut = delta.amount0();
        }

        return abi.encode(amountIn, amountOut);
    }

    /**
     * @notice Settle swap balances with vault
     */
    function _settleSwap(CallbackData memory data, BalanceDelta delta) internal {
        // Handle input token (negative delta = user owes tokens)
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        
        if (amount0 < 0) {
            // Transfer from user and settle with vault
            uint256 absAmount = uint128(-amount0);
            IERC20(Currency.unwrap(data.params.poolKey.currency0)).transferFrom(
                data.sender,
                address(this),
                absAmount
            );
            // Transfer to vault
            IERC20(Currency.unwrap(data.params.poolKey.currency0)).transfer(
                address(vault),
                absAmount
            );
            // Sync and settle
            vault.sync(data.params.poolKey.currency0);
            vault.settle();
        } else if (amount0 > 0) {
            // Take tokens from vault to recipient
            vault.take(data.params.poolKey.currency0, data.params.recipient, uint128(amount0));
        }

        if (amount1 < 0) {
            // Transfer from user and settle with vault
            uint256 absAmount = uint128(-amount1);
            IERC20(Currency.unwrap(data.params.poolKey.currency1)).transferFrom(
                data.sender,
                address(this),
                absAmount
            );
            // Transfer to vault
            IERC20(Currency.unwrap(data.params.poolKey.currency1)).transfer(
                address(vault),
                absAmount
            );
            // Sync and settle
            vault.sync(data.params.poolKey.currency1);
            vault.settle();
        } else if (amount1 > 0) {
            // Take tokens from vault to recipient
            vault.take(data.params.poolKey.currency1, data.params.recipient, uint128(amount1));
        }
    }

    /**
     * @notice Helper to create swap params for exact input
     */
    function createExactInputParams(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        address recipient
    ) external pure returns (SwapParams memory) {
        return SwapParams({
            poolKey: poolKey,
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // Negative for exact input
            sqrtPriceLimitX96: sqrtPriceLimitX96,
            recipient: recipient
        });
    }

    /**
     * @notice Helper to create swap params for exact output
     */
    function createExactOutputParams(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96,
        address recipient
    ) external pure returns (SwapParams memory) {
        return SwapParams({
            poolKey: poolKey,
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut), // Positive for exact output
            sqrtPriceLimitX96: sqrtPriceLimitX96,
            recipient: recipient
        });
    }
}