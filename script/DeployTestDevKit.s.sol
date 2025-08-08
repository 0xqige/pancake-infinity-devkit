// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../test/TestDevKit.sol";

/**
 * @title DeployTestDevKit
 * @notice Script to deploy TestDevKit
 * @dev Usage: forge script DeployTestDevKit --rpc-url localhost --broadcast
 */
contract DeployTestDevKit is Script {
    TestDevKit public devKit;

    // Configuration parameters
    bool constant DEPLOY_CORE = true; // Whether to deploy core contracts

    // Deployed core contract addresses (if DEPLOY_CORE = false)
    address constant VAULT_ADDRESS = address(0); // Need to fill in actual address
    address constant CL_POOL_MANAGER_ADDRESS = address(0); // Need to fill in actual address
    address constant BIN_POOL_MANAGER_ADDRESS = address(0); // Need to fill in actual address
    address constant PROTOCOL_FEE_CONTROLLER_ADDRESS = address(0); // Need to fill in actual address

    function run() public {
        // Get deployment account
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("TestDevKit deployment script");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TestDevKit
        devKit = new TestDevKit();
        console.log("TestDevKit deployed:", address(devKit));

        // 2. If not deploying core contracts, set existing addresses
        if (!DEPLOY_CORE) {
            if (VAULT_ADDRESS != address(0)) {
                devKit.setCoreContracts(
                    VAULT_ADDRESS, CL_POOL_MANAGER_ADDRESS, BIN_POOL_MANAGER_ADDRESS, PROTOCOL_FEE_CONTROLLER_ADDRESS
                );
                console.log("Core contract addresses set");
            } else {
                console.log("Warning: Need to set core contract addresses!");
                console.log("Please call setCoreContracts() to set addresses");
            }
        }

        // 3. Deploy complete environment
        if (VAULT_ADDRESS != address(0) || DEPLOY_CORE) {
            console.log("\nStarting deployment of complete testing environment...");
            devKit.deployFullEnvironment(DEPLOY_CORE);
            console.log("Testing environment deployment completed!");
        }

        vm.stopBroadcast();

        // 4. Print deployment info
        _printDeploymentInfo();
    }

    function _printDeploymentInfo() internal view {
        console.log("\n========================================");
        console.log("Deployment completed!");
        console.log("========================================");
        console.log("\nTestDevKit address:", address(devKit));

        if (devKit.isReady()) {
            console.log("\nTesting environment is ready!");
            console.log("\nMain contract addresses:");
            console.log("  Token Factory:", address(devKit.tokenFactory()));
            console.log("  Token Faucet:", address(devKit.tokenFaucet()));
            // console.log("  Pool Initializer:", address(devKit.poolInitializer()));
            // console.log("  Liquidity Provider:", address(devKit.liquidityProvider()));
            // console.log("  DEX Helpers:", address(devKit.dexHelpers()));

            console.log("\nTest tokens:");
            console.log("  WETH:", address(devKit.weth()));
            console.log("  USDC:", address(devKit.usdc()));
            console.log("  USDT:", address(devKit.usdt()));
            console.log("  CAKE:", address(devKit.cake()));
            console.log("  BNB:", address(devKit.bnb()));

            console.log("\nTest accounts:");
            console.log("  Alice:", devKit.alice());
            console.log("  Bob:", devKit.bob());
            console.log("  Carol:", devKit.carol());

            console.log("\nNext steps:");
            console.log("1. Use TestDevKit contract address for integration testing");
            console.log("2. Claim test tokens from faucet");
            console.log("3. Use DEXHelpers for swap and liquidity operations");
        } else {
            console.log("\nWarning: Testing environment not fully initialized");
            console.log("Please set core contract addresses and call deployFullEnvironment()");
        }

        console.log("\n========================================");
    }
}
