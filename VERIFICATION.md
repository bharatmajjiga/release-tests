# Verification Guide: Go Module Cache Pre-download Fix

This document describes how to verify that the fix for Gauge timeout issues is working correctly.

## Problem
Gauge tests were timing out because the Go runner was downloading dependencies at runtime, which could take 6+ minutes and exceed the connection timeout.

## Solution
Pre-download Go dependencies during Docker image build using `go mod download`, so they're cached in the image and available immediately at runtime.

## Verification Methods

### 1. Build-Time Verification (Automatic)

The Dockerfile now includes verification steps that run during image build:

```dockerfile
RUN go mod download && \
    go mod verify && \
    echo "=== Go module cache verification ===" && \
    go env GOMODCACHE && \
    echo "Dependencies downloaded successfully..."
```

**What to look for in build logs:**
- ✅ "Dependencies downloaded successfully"
- ✅ Cache location and size information
- ✅ Key dependencies listed (Tekton, Gauge, etc.)
- ✅ No download errors

### 2. Manual Image Inspection

After building the Docker image, you can inspect it:

```bash
# Build the image
docker build -t release-tests:test -f Dockerfile .

# Run the verification script inside the container
docker run --rm release-tests:test /bin/bash -c "cd /tmp/release-tests && bash scripts/verify-go-cache.sh"

# Or manually check the cache
docker run --rm release-tests:test /bin/bash -c "go env GOMODCACHE && du -sh \$(go env GOMODCACHE)"
```

**Expected output:**
- Cache directory exists and has significant size (>100MB typically)
- Key dependencies are present
- Can list modules offline

### 3. Runtime Verification (During Test Execution)

Monitor the Gauge logs during test execution to confirm:

**Before fix (problematic):**
```
[go] [INFO] go: downloading github.com/tektoncd/pipeline v1.3.1
[go] [INFO] go: downloading github.com/operator-framework/operator-lifecycle-manager v0.22.0
... (many download lines, taking 6+ minutes)
[Gauge] [CRITICAL] Failed to start gauge API: Timed out connecting to 127.0.0.1:39029
```

**After fix (expected):**
```
[Gauge] [DEBUG] Starting go runner
[go] [INFO] (no download messages, or very few)
[Gauge] [DEBUG] Runner connected successfully
```

**Key indicators of success:**
- ✅ No or minimal "go: downloading" messages
- ✅ Runner connects within seconds (not minutes)
- ✅ No timeout errors
- ✅ Tests start executing quickly

### 4. Pipeline Log Analysis

In your pipeline runs, check for these success indicators:

1. **Build logs should show:**
   ```
   === Go module cache verification ===
   Dependencies downloaded successfully. Cache location: /go/pkg/mod
   Cache size: XXXM
   Key dependencies check:
   [list of dependencies]
   ```

2. **Test execution logs should show:**
   - Fast runner startup (< 30 seconds)
   - No timeout errors
   - Minimal network activity during startup

3. **Compare timing:**
   - **Before:** Runner startup takes 6-10 minutes → timeout
   - **After:** Runner startup takes < 1 minute → success

### 5. Test Script Execution

Run the verification script locally or in CI:

```bash
# In the container or local environment
cd /tmp/release-tests
bash scripts/verify-go-cache.sh
```

**Expected output:**
```
=== Verifying Go Module Cache ===

1. Go environment:
   GOMODCACHE: /go/pkg/mod
   GOPROXY: https://proxy.golang.org,direct

2. Cache directory exists: ✓
   Location: /go/pkg/mod
   Size: 250M

3. Checking key dependencies in cache:
   ✓ github.com/tektoncd/pipeline
   ✓ github.com/getgauge-contrib/gauge-go
   ✓ github.com/openshift/client-go
   ✓ k8s.io/client-go

4. Testing module verification (should use cache, not download):
   ✓ Modules verified successfully

5. Testing offline module operations:
   ✓ Can list modules offline (cache is working)

=== Verification Result: PASSED ===
Go module cache is properly populated and ready for use.
```

### 6. Network Activity Monitoring

To verify dependencies aren't being downloaded at runtime:

```bash
# Monitor network during test execution
# In the container, before running tests:
tcpdump -i any -n 'host proxy.golang.org or host github.com' &
GAUGE_PID=$!

# Run a test
gauge run specs/chains/chains.spec --tags e2e

# Check if there was significant network traffic
# If fix works: minimal to no traffic to proxy.golang.org
```

### 7. Comparison Test

**Test A: Without fix (old image)**
- Build image without `go mod download`
- Run test and measure time to runner connection
- Expected: 6-10 minutes, may timeout

**Test B: With fix (new image)**
- Build image with `go mod download`
- Run test and measure time to runner connection  
- Expected: < 1 minute, no timeout

## Success Criteria

The fix is working if:

1. ✅ Docker build completes with cache verification messages
2. ✅ Cache directory exists with substantial size (>100MB)
3. ✅ Key dependencies are present in cache
4. ✅ Gauge runner starts in < 1 minute
5. ✅ No timeout errors in test logs
6. ✅ Minimal "go: downloading" messages during test execution
7. ✅ Tests complete successfully

## Troubleshooting

If verification fails:

1. **Cache not found:**
   - Check `go env GOMODCACHE` location
   - Verify Docker build completed successfully
   - Check if cache is in a different location

2. **Dependencies missing:**
   - Verify `go.mod` and `go.sum` are correct
   - Check network connectivity during build
   - Ensure `go mod download` ran successfully

3. **Still seeing downloads at runtime:**
   - Verify the image being used has the fix
   - Check if cache location is accessible at runtime
   - Ensure `GOPROXY` is set correctly

4. **Timeout still occurring:**
   - Check if timeout is due to other reasons (not dependency downloads)
   - Verify timeout values are sufficient
   - Check network conditions during test execution

## Monitoring in Production

Add these checks to your pipeline:

1. Build step should verify cache population
2. Test execution should log runner startup time
3. Alert if startup time exceeds threshold (> 2 minutes)
4. Track timeout error rates (should drop to near zero)

