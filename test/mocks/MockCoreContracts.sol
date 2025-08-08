// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Currency} from "../../src/Currency.sol"; 
import {PoolKey} from "../../src/PoolKey.sol";
import {PoolId} from "../../src/PoolId.sol";
import {IHooks} from "../../src/IHooks.sol";
import {IPoolManager} from "../../src/IPoolManager.sol";

/**
 * @title MockVault
 * @notice Mock implementation of Vault for testing
 */
contract MockVault {
    mapping(address => mapping(Currency => uint256)) public balances;
    
    function lock(bytes calldata) external returns (bytes memory) {
        return "";
    }
    
    function settle() external payable returns (uint256) {
        return 0;
    }
    
    function take(Currency, address, uint256) external {
        // Mock implementation
    }
    
    function accountAppBalanceDelta(Currency, Currency, bytes32, address) external {
        // Mock implementation
    }
}

/**
 * @title MockCLPoolManager
 * @notice Mock implementation of CLPoolManager for testing
 */
contract MockCLPoolManager {
    mapping(PoolId => bool) public poolInitialized;
    mapping(PoolId => uint160) public poolPrices;
    mapping(PoolId => PoolKey) public poolIdToPoolKey;
    
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24) {
        PoolId id = PoolId.wrap(keccak256(abi.encode(key)));
        poolInitialized[id] = true;
        poolPrices[id] = sqrtPriceX96;
        poolIdToPoolKey[id] = key;
        return 0;
    }
    
    function getSlot0(PoolId id) external view returns (uint160, int24, uint24, uint24) {
        require(poolInitialized[id], "Pool not initialized");
        return (poolPrices[id], 0, 0, 3000);
    }
    
    function modifyLiquidity(PoolKey memory, bytes memory, bytes calldata) 
        external returns (bytes32, bytes32) {
        return (bytes32(0), bytes32(0));
    }
    
    function swap(PoolKey memory, bytes memory, bytes calldata) 
        external returns (bytes32) {
        return bytes32(0);
    }
}

/**
 * @title MockBinPoolManager  
 * @notice Mock implementation of BinPoolManager for testing
 */
contract MockBinPoolManager {
    function initialize(PoolKey memory, uint24 activeId) external returns (int24, uint24, uint24) {
        return (0, activeId, 3000);
    }
}

/**
 * @title MockProtocolFeeController
 * @notice Mock implementation of ProtocolFeeController for testing
 */
contract MockProtocolFeeController {
    function protocolFeeForPool(PoolKey memory) external pure returns (uint24) {
        return 0;
    }
}