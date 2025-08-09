#!/bin/bash

echo "=========================================="
echo "Running MEME Token Swap Test"
echo "=========================================="
echo ""

# Navigate to project root
cd "$(dirname "$0")"

# Build the project first
echo "Building contracts..."
forge build

echo ""
echo "Running swap tests..."
echo ""

# Run the test with detailed output
forge test --match-contract MEMETokenSwapTest -vvv --isolate

echo ""
echo "=========================================="
echo "Test execution complete!"
echo "=========================================="