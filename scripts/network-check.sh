#!/usr/bin/env bash

set -u

TARGET_HOST="${1:-example.com}"
TARGET_PORT="${2:-443}"
APP_URL="http://localhost:8080/health"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
LOG_FILE="$LOG_DIR/network-check.log"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== NETOPS DIAGNOSTIC START =========="
log "Target: $TARGET_HOST:$TARGET_PORT"

# DNS check
if getent ahosts "$TARGET_HOST" >/dev/null 2>&1; then
    log "PASS: DNS resolution successful"
else
    log "FAIL: DNS resolution failed"
fi

# TCP connectivity check
if timeout 5 bash -c 'echo > /dev/tcp/"$1"/"$2"' _ \
    "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
    log "PASS: TCP connection successful"
else
    log "FAIL: TCP connection failed"
fi

# HTTP health check
HTTP_CODE=$(curl -sS -o /dev/null -w '%{http_code}' \
    --max-time 5 "$APP_URL" 2>/dev/null || true)

if [[ "$HTTP_CODE" == "200" ]]; then
    log "PASS: Application HTTP health check"
else
    log "FAIL: Application HTTP health check (HTTP $HTTP_CODE)"
fi

# Docker container checks
for CONTAINER in netops-app netops-nginx; do
    STATUS=$(docker inspect -f '{{.State.Running}}' \
        "$CONTAINER" 2>/dev/null || true)

    if [[ "$STATUS" == "true" ]]; then
        log "PASS: Container $CONTAINER is running"
    else
        log "FAIL: Container $CONTAINER is not running"
    fi
done

log "========== NETOPS DIAGNOSTIC END =========="