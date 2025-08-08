# PancakeSwap Infinity Local DEX Testing Environment

This is a complete local testing environment for the PancakeSwap Infinity protocol, providing a one-click deployment DEX simulation environment for projects to conduct contract integration testing.

## 🚀 Quick Start

### 1. One-click deployment with TestDevKit

```solidity
// Deploy and initialize complete environment
TestDevKit devKit = new TestDevKit();
devKit.setCoreContracts(vault, clManager, binManager, feeController);
devKit.deployFullEnvironment(false);
```

### 2. Deploy with Foundry script

```bash
# Deploy TestDevKit
forge script test/local-dex-environment/deploy/DeployTestDevKit.s.sol \
    --rpc-url localhost \
    --broadcast
```

## 📁 Directory Structure

```
test/local-dex-environment/
├── TestDevKit.sol           # One-click deployment management contract
├── deploy/                  # Deployment scripts and configurations
│   ├── config/             # Configuration files
│   ├── LocalDevDeploy.s.sol
│   └── DeployTestDevKit.s.sol
├── tokens/                  # Test token system
│   ├── TestTokenFactory.sol
│   ├── TokenFaucet.sol
│   └── TestTokens.sol
├── pools/                   # Pool management tools
│   ├── PoolInitializer.sol
│   └── LiquidityProvider.sol
├── integration/             # Integration testing framework
│   ├── ProjectIntegrationTest.sol
│   └── DEXInteractionHelpers.sol
└── examples/                # Example tests
    └── ExampleIntegrationTest.t.sol
```

## 🎯 Main Features

### TestDevKit - Core Management Contract

- **One-click deployment**: Automatically deploy all test components
- **Token management**: 8 test tokens (standard + special)
- **Pool management**: 5 preset trading pairs
- **Account management**: 5 preset test accounts
- **Tool integration**: Complete DEX interaction toolchain

### Test Token Types

1. **Standard tokens**: WETH, USDC, USDT, CAKE, BNB
2. **Special tokens** (for edge case testing):
   - FeeOnTransferToken - Fee-on-transfer token
   - DeflationaryToken - Deflationary token
   - RebasingToken - Rebasing token
   - NonStandardToken - Non-standard ERC20

### Preset Pools

- WETH/USDC (0.3% fee) - Major trading pair
- USDC/USDT (0.01% fee) - Stablecoin pair
- WETH/CAKE (0.3% fee) - Platform token pair
- CAKE/USDC (0.3% fee)
- BNB/USDC (0.3% fee)

### Test Accounts

- Alice: `0x1111111111111111111111111111111111111111`
- Bob: `0x2222222222222222222222222222222222222222`
- Carol: `0x3333333333333333333333333333333333333333`
- Dave: `0x4444444444444444444444444444444444444444`
- Eve: `0x5555555555555555555555555555555555555555`

## 🔧 Usage Examples

### 1. Inherit from ProjectIntegrationTest

```solidity
contract MyDEXTest is ProjectIntegrationTest {
    function setUp() public override {
        setupDEXEnvironment();
    }
    
    function runCustomTests() internal override {
        // Implement custom test logic
        vm.prank(alice);
        weth.transfer(bob, 1 ether);
    }
}
```

### 2. Use TestDevKit directly

```solidity
contract MyTest is Test {
    TestDevKit devKit;
    
    function setUp() public {
        devKit = new TestDevKit();
        devKit.deployFullEnvironment(false);
    }
    
    function testSwap() public {
        // Get tokens and accounts
        IERC20 weth = devKit.weth();
        address alice = devKit.alice();
        
        // Execute swap
        vm.prank(alice);
        // ... swap logic
    }
}
```

### 3. Use DEXInteractionHelpers

```solidity
// Exact input swap
DEXInteractionHelpers.ExactInputSingleParams memory params = 
    DEXInteractionHelpers.ExactInputSingleParams({
        poolKey: poolKey,
        tokenIn: Currency.wrap(address(weth)),
        tokenOut: Currency.wrap(address(usdc)),
        amountIn: 1 ether,
        amountOutMinimum: 1900 * 10**6,
        sqrtPriceLimitX96: 0
    });

uint256 amountOut = dexHelpers.exactInputSingle(params);
```

### 4. Claim tokens from faucet

```solidity
// Single token
tokenFaucet.claimToken(address(weth));

// Batch claim
tokenFaucet.claimAllTokens();
```

## 🛠️ Tool Contracts Description

### TestTokenFactory
Creates various types of test tokens, supporting standard and special token types.

### TokenFaucet
Token faucet providing free test tokens for test users, with cooldown period and claim limits.

### PoolInitializer
Pool initializer that simplifies the creation process for CL pools and Bin pools.

### LiquidityProvider
Liquidity manager providing convenient methods for adding and removing liquidity.

### DEXInteractionHelpers
Advanced DEX interaction helpers, encapsulating common operations like swaps and liquidity management.

## 📝 Configuration Files

`deploy/config/local-dev.json` contains:
- Network configuration
- Test accounts
- Token configuration
- Initial pool parameters

## 🚨 Important Notes

1. This is a test environment, do not use in production
2. Test tokens have no real value
3. Core contract addresses must be deployed or set first
4. Some special tokens may affect normal DEX operation, only for edge case testing

## 📚 Related Documentation

- [PancakeSwap Infinity Documentation](https://docs.pancakeswap.finance)
- [Foundry Documentation](https://book.getfoundry.sh)

## 🤝 Contributing

Welcome to submit Issues and Pull Requests to improve the testing environment.

## 📄 License

UNLICENSED (For testing only)