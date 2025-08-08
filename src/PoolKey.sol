// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./Currency.sol";
import "./IHooks.sol";
import "./IPoolManager.sol";

struct PoolKey {
    Currency currency0;
    Currency currency1;
    IHooks hooks;
    IPoolManager poolManager;
    uint24 fee;
    bytes32 parameters;
}