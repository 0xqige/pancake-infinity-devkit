// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

type PoolId is bytes32;

library PoolIdLibrary {
    function wrap(bytes32 value) internal pure returns (PoolId) {
        return PoolId.wrap(value);
    }
    
    function unwrap(PoolId id) internal pure returns (bytes32) {
        return PoolId.unwrap(id);
    }
}