#!/bin/bash
# Script to verify Go module cache is populated and working
# This helps verify that the Docker image has pre-downloaded dependencies

set -e

echo "=== Verifying Go Module Cache ==="
echo ""

# Check Go environment
echo "1. Go environment:"
echo "   GOMODCACHE: $(go env GOMODCACHE)"
echo "   GOPROXY: $(go env GOPROXY)"
echo ""

# Check if cache directory exists
CACHE_DIR=$(go env GOMODCACHE)
if [ -d "$CACHE_DIR" ]; then
    echo "2. Cache directory exists: ✓"
    echo "   Location: $CACHE_DIR"
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "   Size: $CACHE_SIZE"
else
    echo "2. Cache directory missing: ✗"
    exit 1
fi
echo ""

# Check for key dependencies
echo "3. Checking key dependencies in cache:"
KEY_DEPS=(
    "github.com/tektoncd/pipeline"
    "github.com/getgauge-contrib/gauge-go"
    "github.com/openshift/client-go"
    "k8s.io/client-go"
)

ALL_FOUND=true
for dep in "${KEY_DEPS[@]}"; do
    if find "$CACHE_DIR" -type d -path "*/$dep*" | head -1 | grep -q .; then
        echo "   ✓ $dep"
    else
        echo "   ✗ $dep (NOT FOUND)"
        ALL_FOUND=false
    fi
done
echo ""

# Try to verify modules without downloading
echo "4. Testing module verification (should use cache, not download):"
if go mod verify 2>&1 | grep -q "all modules verified\|modules verified"; then
    echo "   ✓ Modules verified successfully"
else
    echo "   ⚠ Module verification had issues (check output above)"
fi
echo ""

# Check if we can list modules without network
echo "5. Testing offline module operations:"
if GOPROXY=off go list -m all > /dev/null 2>&1; then
    echo "   ✓ Can list modules offline (cache is working)"
else
    echo "   ✗ Cannot list modules offline (cache may be incomplete)"
    ALL_FOUND=false
fi
echo ""

if [ "$ALL_FOUND" = true ]; then
    echo "=== Verification Result: PASSED ==="
    echo "Go module cache is properly populated and ready for use."
    exit 0
else
    echo "=== Verification Result: FAILED ==="
    echo "Some dependencies are missing from the cache."
    exit 1
fi

