#!/bin/bash
# Quick test script to verify Gauge runner starts quickly (indicating cache is working)
# This simulates what happens when Gauge starts and should complete in < 1 minute if fix works

set -e

echo "=== Testing Gauge Runner Startup Time ==="
echo ""

# Record start time
START_TIME=$(date +%s)

# Set a timeout (2 minutes should be more than enough if cache works)
TIMEOUT=120

echo "Starting Gauge runner test..."
echo "Expected: Should complete in < 1 minute if dependencies are cached"
echo ""

# Try to start gauge and check if runner can initialize
# We'll use a dry-run approach to test startup without running actual tests
cd /tmp/release-tests || cd "$(dirname "$0")/.."

# Check if we can list specs (this triggers runner initialization)
if timeout $TIMEOUT gauge --version > /dev/null 2>&1 && \
   timeout $TIMEOUT gauge --machine-readable specs/chains/chains.spec 2>&1 | head -20 > /dev/null; then
    
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    echo "✓ Gauge runner initialized successfully"
    echo "  Time taken: ${ELAPSED} seconds"
    echo ""
    
    if [ $ELAPSED -lt 60 ]; then
        echo "=== Result: PASSED ==="
        echo "Runner started quickly (${ELAPSED}s < 60s), indicating cache is working."
        exit 0
    elif [ $ELAPSED -lt 120 ]; then
        echo "=== Result: WARNING ==="
        echo "Runner started but took longer than expected (${ELAPSED}s)."
        echo "Cache may be working but startup is slower than ideal."
        exit 0
    else
        echo "=== Result: FAILED ==="
        echo "Runner took too long (${ELAPSED}s > 120s)."
        echo "This suggests dependencies are still being downloaded."
        exit 1
    fi
else
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    echo "✗ Gauge runner failed to initialize or timed out"
    echo "  Time elapsed: ${ELAPSED} seconds"
    echo ""
    echo "=== Result: FAILED ==="
    echo "Runner could not start within timeout period."
    echo "Check logs above for details."
    exit 1
fi

