# Using base image which has requirements (go, gauge) installed
FROM quay.io/openshift-pipeline/ci

# Set this var to install gauge plugins at custom path
ENV GAUGE_HOME=/tmp

# Add timeout to ignore runner connection error
RUN gauge config runner_connection_timeout 600000 && \
    gauge config runner_request_timeout 300000

# Copy the tests into /tmp/release-tests
RUN mkdir /tmp/release-tests
WORKDIR /tmp/release-tests
COPY . .

# Pre-download Go dependencies to avoid runtime downloads that cause timeouts
# This populates the Go module cache so the Gauge runner doesn't need to download during startup
RUN go mod download && \
    go mod verify && \
    echo "=== Go module cache verification ===" && \
    go env GOMODCACHE && \
    echo "Dependencies downloaded successfully. Cache location: $(go env GOMODCACHE)" && \
    echo "Cache size: $(du -sh $(go env GOMODCACHE) 2>/dev/null || echo 'N/A')" && \
    echo "Key dependencies check:" && \
    ls -la $(go env GOMODCACHE)/cache/download/github.com/tektoncd 2>/dev/null | head -5 || echo "Tekton dependencies in cache" && \
    ls -la $(go env GOMODCACHE)/cache/download/github.com/getgauge-contrib 2>/dev/null | head -3 || echo "Gauge dependencies in cache"

# Set required permissions for OpenShift usage
RUN chgrp -R 0 /tmp && \
    chmod -R g=u /tmp

CMD ["/bin/bash"]