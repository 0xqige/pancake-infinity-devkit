// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

// Core contracts and types
import {Currency} from "@src/core/types/Currency.sol";
import {PoolKey} from "@src/core/types/PoolKey.sol";
import {PoolId} from "@src/core/types/PoolId.sol";
import {IVault} from "@src/core/interfaces/IVault.sol";
import {ILockCallback} from "@src/core/interfaces/ILockCallback.sol";
import {ICLPoolManager} from "@src/core/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "@src/core/pool-bin/interfaces/IBinPoolManager.sol";

// Types and libraries
import {BalanceDelta} from "@src/core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@src/core/types/BeforeSwapDelta.sol";
import {CLPoolParametersHelper} from "@src/core/pool-cl/libraries/CLPoolParametersHelper.sol";

// ERC20 interface
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title DEXInteractionHelpers
 * @notice DEX interaction helper tools providing advanced DEX operation functions
 * @dev Simplifies common DEX interactions such as swaps, liquidity management etc.
 */
contract DEXInteractionHelpers is ILockCallback {
    using CLPoolParametersHelper for bytes32;

    IVault public immutable vault;
    ICLPoolManager public immutable clPoolManager;
    IBinPoolManager public immutable binPoolManager;

    struct SwapParams {
        PoolKey poolKey;
        bool zeroForOne; // token0 for token1
        int256 amountSpecified; // Input amount (negative) or output amount (positive)
        uint160 sqrtPriceLimitX96; // Price limit
    }

    struct ExactInputSingleParams {
        PoolKey poolKey;
        Currency tokenIn;
        Currency tokenOut;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        PoolKey poolKey;
        Currency tokenIn;
        Currency tokenOut;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct CLLiquidityParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityDelta;
        bytes32 salt;
    }

    event SwapExecuted(
        PoolId indexed poolId,
        address indexed swapper,
        Currency tokenIn,
        Currency tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityAdded(
        PoolId indexed poolId, address indexed provider, int24 tickLower, int24 tickUpper, uint128 liquidity
    );

    event LiquidityRemoved(
        PoolId indexed poolId, address indexed provider, int24 tickLower, int24 tickUpper, uint128 liquidity
    );

    constructor(address _vault, address _clPoolManager, address _binPoolManager) {
        vault = IVault(_vault);
        clPoolManager = ICLPoolManager(_clPoolManager);
        binPoolManager = IBinPoolManager(_binPoolManager);
    }

    // ========== Swap Functions ==========

    /**
     * @notice Exact input single swap
     * @param params Swap parameters
     * @return amountOut Actual output amount
     */
    function exactInputSingle(ExactInputSingleParams memory params) external returns (uint256 amountOut) {
        // Determine swap direction
        bool zeroForOne = Currency.unwrap(params.tokenIn) < Currency.unwrap(params.tokenOut);

        // Transfer tokens in advance
        IERC20(Currency.unwrap(params.tokenIn)).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(Currency.unwrap(params.tokenIn)).approve(address(vault), params.amountIn);

        // Build swap parameters
        SwapParams memory swapParams = SwapParams({
            poolKey: params.poolKey,
            zeroForOne: zeroForOne,
            amountSpecified: -int256(params.amountIn), // Negative number means exact input
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        });

        // Execute swap
        bytes memory data = abi.encode("EXACT_INPUT_SINGLE", swapParams, msg.sender);
        bytes memory result = vault.lock(data);
        amountOut = abi.decode(result, (uint256));

        // Check slippage protection
        require(amountOut >= params.amountOutMinimum, "Too little received");

        // Record event
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit SwapExecuted(poolId, msg.sender, params.tokenIn, params.tokenOut, params.amountIn, amountOut);

        console.log("Exact input swap completed:");
        console.log("  Input:", params.amountIn, Currency.unwrap(params.tokenIn));
        console.log("  Output:", amountOut, Currency.unwrap(params.tokenOut));
    }

    /**
     * @notice Exact output single swap
     * @param params Swap parameters
     * @return amountIn Actual input amount
     */
    function exactOutputSingle(ExactOutputSingleParams memory params) external returns (uint256 amountIn) {
        // Determine swap direction
        bool zeroForOne = Currency.unwrap(params.tokenIn) < Currency.unwrap(params.tokenOut);

        // Transfer maximum token amount in advance
        IERC20(Currency.unwrap(params.tokenIn)).transferFrom(msg.sender, address(this), params.amountInMaximum);
        IERC20(Currency.unwrap(params.tokenIn)).approve(address(vault), params.amountInMaximum);

        // Build swap parameters
        SwapParams memory swapParams = SwapParams({
            poolKey: params.poolKey,
            zeroForOne: zeroForOne,
            amountSpecified: int256(params.amountOut), // Positive number means exact output
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        });

        // Execute swap
        bytes memory data = abi.encode("EXACT_OUTPUT_SINGLE", swapParams, msg.sender);
        bytes memory result = vault.lock(data);
        amountIn = abi.decode(result, (uint256));

        // Check slippage protection
        require(amountIn <= params.amountInMaximum, "Too much requested");

        // Return excess tokens
        if (params.amountInMaximum > amountIn) {
            IERC20(Currency.unwrap(params.tokenIn)).transfer(msg.sender, params.amountInMaximum - amountIn);
        }

        // Record event
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit SwapExecuted(poolId, msg.sender, params.tokenIn, params.tokenOut, amountIn, params.amountOut);

        console.log("Exact output swap completed:");
        console.log("  Input:", amountIn, Currency.unwrap(params.tokenIn));
        console.log("  Output:", params.amountOut, Currency.unwrap(params.tokenOut));
    }

    // ========== Liquidity Management ==========

    /**
     * @notice Add CL liquidity
     * @param params Liquidity parameters
     * @return liquidity Amount of liquidity added
     * @return amount0 Amount of token0
     * @return amount1 Amount of token1
     */
    function addCLLiquidity(CLLiquidityParams memory params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // Transfer tokens in advance (simplified implementation, using large amounts)
        uint256 maxAmount0 = 1000000 * 10 ** 18;
        uint256 maxAmount1 = 1000000 * 10 ** 18;

        if (!params.poolKey.currency0.isNative()) {
            IERC20(Currency.unwrap(params.poolKey.currency0)).transferFrom(msg.sender, address(this), maxAmount0);
            IERC20(Currency.unwrap(params.poolKey.currency0)).approve(address(vault), maxAmount0);
        }

        if (!params.poolKey.currency1.isNative()) {
            IERC20(Currency.unwrap(params.poolKey.currency1)).transferFrom(msg.sender, address(this), maxAmount1);
            IERC20(Currency.unwrap(params.poolKey.currency1)).approve(address(vault), maxAmount1);
        }

        // Execute liquidity addition
        bytes memory data = abi.encode("ADD_CL_LIQUIDITY", params, msg.sender);
        bytes memory result = vault.lock(data);
        (liquidity, amount0, amount1) = abi.decode(result, (uint128, uint256, uint256));

        // Record event
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit LiquidityAdded(poolId, msg.sender, params.tickLower, params.tickUpper, liquidity);

        console.log("CL liquidity added:");
        console.log("  Liquidity:", liquidity);
        console.log("  Token0 amount:", amount0);
        console.log("  Token1 amount:", amount1);
    }

    /**
     * @notice Remove CL liquidity
     * @param params Liquidity parameters (liquidityDelta should be negative)
     * @return amount0 Amount of token0 received
     * @return amount1 Amount of token1 received
     */
    function removeCLLiquidity(CLLiquidityParams memory params) external returns (uint256 amount0, uint256 amount1) {
        require(int128(params.liquidityDelta) < 0, "Liquidity delta must be negative");

        // Execute liquidity removal
        bytes memory data = abi.encode("REMOVE_CL_LIQUIDITY", params, msg.sender);
        bytes memory result = vault.lock(data);
        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        // Record event
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(params.poolKey)));
        emit LiquidityRemoved(poolId, msg.sender, params.tickLower, params.tickUpper, params.liquidityDelta);

        console.log("CL liquidity removed:");
        console.log("  Token0 received:", amount0);
        console.log("  Token1 received:", amount1);
    }

    // ========== Vault Lock Callback ==========

    /**
     * @notice Vault lock callback function
     */
    function lockAcquired(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(vault), "Only vault");

        (string memory action) = abi.decode(data, (string));

        if (keccak256(bytes(action)) == keccak256("EXACT_INPUT_SINGLE")) {
            (, SwapParams memory swapParams, address swapper) = abi.decode(data, (string, SwapParams, address));
            return _handleExactInputSwap(swapParams, swapper);
        } else if (keccak256(bytes(action)) == keccak256("EXACT_OUTPUT_SINGLE")) {
            (, SwapParams memory swapParams, address swapper) = abi.decode(data, (string, SwapParams, address));
            return _handleExactOutputSwap(swapParams, swapper);
        } else if (keccak256(bytes(action)) == keccak256("ADD_CL_LIQUIDITY")) {
            (, CLLiquidityParams memory params, address provider) =
                abi.decode(data, (string, CLLiquidityParams, address));
            return _handleAddLiquidity(params, provider);
        } else if (keccak256(bytes(action)) == keccak256("REMOVE_CL_LIQUIDITY")) {
            (, CLLiquidityParams memory params, address provider) =
                abi.decode(data, (string, CLLiquidityParams, address));
            return _handleRemoveLiquidity(params, provider);
        }

        revert("Unknown action");
    }

    /**
     * @notice Handle exact input swap
     */
    function _handleExactInputSwap(SwapParams memory params, address swapper) internal returns (bytes memory) {
        // Execute swap
        BalanceDelta delta = clPoolManager.swap(
            params.poolKey,
            ICLPoolManager.SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: params.amountSpecified,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            }),
            ""
        );

        // Settle tokens
        _settleSwap(params.poolKey, delta, swapper);

        // Calculate output amount
        uint256 amountOut = params.zeroForOne ? uint256(int256(delta.amount1())) : uint256(int256(delta.amount0()));

        return abi.encode(amountOut);
    }

    /**
     * @notice Handle exact output swap
     */
    function _handleExactOutputSwap(SwapParams memory params, address swapper) internal returns (bytes memory) {
        // Execute swap
        BalanceDelta delta = clPoolManager.swap(
            params.poolKey,
            ICLPoolManager.SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: params.amountSpecified,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            }),
            ""
        );

        // Settle tokens
        _settleSwap(params.poolKey, delta, swapper);

        // Calculate input amount
        uint256 amountIn = params.zeroForOne ? uint256(int256(-delta.amount0())) : uint256(int256(-delta.amount1()));

        return abi.encode(amountIn);
    }

    /**
     * @notice Handle liquidity addition
     */
    function _handleAddLiquidity(CLLiquidityParams memory params, address provider) internal returns (bytes memory) {
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

        // Settle liquidity
        _settleLiquidity(params.poolKey, delta, provider);

        uint256 amount0 = uint256(int256(-delta.amount0()));
        uint256 amount1 = uint256(int256(-delta.amount1()));

        return abi.encode(params.liquidityDelta, amount0, amount1);
    }

    /**
     * @notice Handle liquidity removal
     */
    function _handleRemoveLiquidity(CLLiquidityParams memory params, address provider)
        internal
        returns (bytes memory)
    {
        // Modify liquidity (decrease)
        (BalanceDelta delta,) = clPoolManager.modifyLiquidity(
            params.poolKey,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: -int128(params.liquidityDelta), // Negative means removal
                salt: params.salt
            }),
            ""
        );

        // Settle liquidity removal
        _settleLiquidityRemoval(params.poolKey, delta, provider);

        uint256 amount0 = uint256(int256(delta.amount0()));
        uint256 amount1 = uint256(int256(delta.amount1()));

        return abi.encode(amount0, amount1);
    }

    /**
     * @notice Settle swap
     */
    function _settleSwap(PoolKey memory poolKey, BalanceDelta delta, address swapper) internal {
        // Handle currency0
        if (delta.amount0() > 0) {
            vault.take(poolKey.currency0, swapper, uint256(int256(delta.amount0())));
        } else if (delta.amount0() < 0) {
            vault.settle();
        }

        // Handle currency1
        if (delta.amount1() > 0) {
            vault.take(poolKey.currency1, swapper, uint256(int256(delta.amount1())));
        } else if (delta.amount1() < 0) {
            vault.settle();
        }
    }

    /**
     * @notice Settle liquidity addition
     */
    function _settleLiquidity(PoolKey memory poolKey, BalanceDelta delta, address provider) internal {
        // When adding liquidity, user deposits tokens to pool (delta is negative)
        if (delta.amount0() < 0) {
            vault.settle();
        } else if (delta.amount0() > 0) {
            vault.take(poolKey.currency0, provider, uint256(int256(delta.amount0())));
        }

        if (delta.amount1() < 0) {
            vault.settle();
        } else if (delta.amount1() > 0) {
            vault.take(poolKey.currency1, provider, uint256(int256(delta.amount1())));
        }
    }

    /**
     * @notice Settle liquidity removal
     */
    function _settleLiquidityRemoval(PoolKey memory poolKey, BalanceDelta delta, address provider) internal {
        // When removing liquidity, user withdraws tokens from pool (delta is positive)
        if (delta.amount0() > 0) {
            vault.take(poolKey.currency0, provider, uint256(int256(delta.amount0())));
        }

        if (delta.amount1() > 0) {
            vault.take(poolKey.currency1, provider, uint256(int256(delta.amount1())));
        }
    }

    // ========== Query Functions ==========

    /**
     * @notice Get current pool state
     */
    function getPoolState(PoolKey memory poolKey)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity)
    {
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        (sqrtPriceX96, tick,,) = clPoolManager.getSlot0(poolId);
        liquidity = 0; // TODO: Get actual liquidity from pool
    }

    /**
     * @notice Estimate swap output (simplified implementation)
     * @dev Should use Quoter contract in practice
     */
    function quoteExactInputSingle(PoolKey memory poolKey, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        // TODO: Implement precise quotation logic
        // This is just a placeholder, should use complex mathematical calculations in practice
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        (uint160 sqrtPriceX96,,,) = clPoolManager.getSlot0(poolId);

        // Simplified calculation (needs to consider slippage, fees etc. in practice)
        if (zeroForOne) {
            amountOut = (amountIn * uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        } else {
            amountOut = (amountIn << 192) / (uint256(sqrtPriceX96) * uint256(sqrtPriceX96));
        }

        console.log("Swap estimate - Input:", amountIn, "Output:", amountOut);
    }

    /**
     * @notice Check if pool exists
     */
    function poolExists(PoolKey memory poolKey) external view returns (bool) {
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        try clPoolManager.getSlot0(poolId) {
            return true;
        } catch {
            return false;
        }
    }

    // ========== Convenience Functions ==========

    /**
     * @notice Quickly create exact input swap parameters
     */
    function createExactInputParams(
        PoolKey memory poolKey,
        Currency tokenIn,
        Currency tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external pure returns (ExactInputSingleParams memory) {
        return ExactInputSingleParams({
            poolKey: poolKey,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0 // No price limit
        });
    }

    /**
     * @notice Quickly create CL liquidity parameters
     */
    function createCLLiquidityParams(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        pure
        returns (CLLiquidityParams memory)
    {
        return CLLiquidityParams({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidity,
            salt: bytes32(0)
        });
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
     * @notice Get contract token balance
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
