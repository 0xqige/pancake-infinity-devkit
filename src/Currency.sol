// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

type Currency is address;

library CurrencyLibrary {
    function wrap(address addr) internal pure returns (Currency) {
        return Currency.wrap(addr);
    }
    
    function unwrap(Currency currency) internal pure returns (address) {
        return Currency.unwrap(currency);
    }
    
    function isNative(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == address(0);
    }
}