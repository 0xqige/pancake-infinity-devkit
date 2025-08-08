// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TestDevKit} from "./TestDevKit.sol";

/**
 * @title TestDevKitTest
 * @notice 测试 TestDevKit 的功能
 */
contract TestDevKitTest is Test {
    TestDevKit public devKit;
    
    function setUp() public {
        // 部署 TestDevKit
        devKit = new TestDevKit();
        
        // 部署完整环境
        devKit.deployFullEnvironment(true);
    }
    
    function testDevKitInitialization() public {
        // 验证环境已初始化
        assertTrue(devKit.isReady(), "DevKit should be ready");
        
        // 验证核心合约
        assertTrue(address(devKit.vault()) != address(0), "Vault should be deployed");
        assertTrue(address(devKit.clPoolManager()) != address(0), "CL Pool Manager should be deployed");
        assertTrue(address(devKit.binPoolManager()) != address(0), "Bin Pool Manager should be deployed");
        
        // 验证测试工具
        assertTrue(address(devKit.tokenFactory()) != address(0), "Token Factory should be deployed");
        assertTrue(address(devKit.tokenFaucet()) != address(0), "Token Faucet should be deployed");
        
        console.log("TestDevKit initialized successfully");
    }
    
    function testTokensCreated() public {
        // 验证标准代币
        assertTrue(address(devKit.weth()) != address(0), "WETH should be created");
        assertTrue(address(devKit.usdc()) != address(0), "USDC should be created");
        assertTrue(address(devKit.usdt()) != address(0), "USDT should be created");
        assertTrue(address(devKit.cake()) != address(0), "CAKE should be created");
        assertTrue(address(devKit.bnb()) != address(0), "BNB should be created");
        
        // 验证特殊代币
        assertTrue(address(devKit.feeToken()) != address(0), "Fee Token should be created");
        assertTrue(address(devKit.defToken()) != address(0), "Deflationary Token should be created");
        assertTrue(address(devKit.rebaseToken()) != address(0), "Rebase Token should be created");
        
        console.log("All test tokens created successfully");
    }
    
    function testTestAccounts() public {
        // 验证测试账户
        assertTrue(devKit.alice() != address(0), "Alice should be set");
        assertTrue(devKit.bob() != address(0), "Bob should be set");
        assertTrue(devKit.carol() != address(0), "Carol should be set");
        assertTrue(devKit.dave() != address(0), "Dave should be set");
        assertTrue(devKit.eve() != address(0), "Eve should be set");
        
        // 验证账户有ETH
        assertTrue(devKit.alice().balance > 0, "Alice should have ETH");
        assertTrue(devKit.bob().balance > 0, "Bob should have ETH");
        
        console.log("Test accounts setup successfully");
    }
    
    function testTokenBalances() public {
        // 检查测试账户的代币余额
        address alice = devKit.alice();
        
        uint256 wethBalance = devKit.weth().balanceOf(alice);
        uint256 usdcBalance = devKit.usdc().balanceOf(alice);
        uint256 usdtBalance = devKit.usdt().balanceOf(alice);
        uint256 cakeBalance = devKit.cake().balanceOf(alice);
        
        assertTrue(wethBalance > 0, "Alice should have WETH");
        assertTrue(usdcBalance > 0, "Alice should have USDC");
        assertTrue(usdtBalance > 0, "Alice should have USDT");
        assertTrue(cakeBalance > 0, "Alice should have CAKE");
        
        console.log("Alice WETH balance:", wethBalance);
        console.log("Alice USDC balance:", usdcBalance);
        console.log("Alice USDT balance:", usdtBalance);
        console.log("Alice CAKE balance:", cakeBalance);
        
        console.log("Token distribution successful");
    }
    
    function testPools() public {
        // 获取所有池名称
        string[] memory poolNames = devKit.getAllPoolNames();
        assertTrue(poolNames.length > 0, "Should have pools created");
        
        for (uint256 i = 0; i < poolNames.length; i++) {
            console.log("Pool:", poolNames[i]);
        }
        
        console.log("Trading pools created successfully, total:", poolNames.length, "pools");
    }
    
    function testFaucet() public {
        address newUser = makeAddr("newUser");
        vm.deal(newUser, 1 ether);
        
        // 等待冷却时间过去
        vm.warp(block.timestamp + 3601);
        
        // 从水龙头领取代币
        vm.startPrank(newUser);
        devKit.tokenFaucet().claimToken(address(devKit.weth()));
        vm.stopPrank();
        
        // 验证余额
        uint256 balance = devKit.weth().balanceOf(newUser);
        assertTrue(balance > 0, "User should receive WETH from faucet");
        
        console.log("Token faucet working normally, user received", balance, "WETH");
    }
}