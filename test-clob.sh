#!/bin/bash

echo "🧪 CLOB Testing Script"
echo "====================="

# Change to project directory
cd "$(dirname "$0")"

echo "📁 Current directory: $(pwd)"

echo ""
echo "1️⃣ Compiling contracts..."
npx hardhat compile

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""
echo "2️⃣ Running simple connectivity test..."
npx hardhat run scripts/simple-clob-test.js --network riseTestnet

if [ $? -eq 0 ]; then
    echo "✅ Connectivity test passed"
else
    echo "❌ Connectivity test failed"
    exit 1
fi

echo ""
echo "3️⃣ Running full CLOB functionality test..."
npx hardhat run scripts/test-clob.js --network riseTestnet

if [ $? -eq 0 ]; then
    echo "✅ Full CLOB test passed"
    echo ""
    echo "🎉 All tests completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "   - Test the frontend at http://localhost:3000"
    echo "   - Try placing limit and market orders"
    echo "   - Check instant execution functionality"
else
    echo "❌ Full CLOB test failed"
    exit 1
fi