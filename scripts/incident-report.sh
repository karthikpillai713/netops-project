#!/usr/bin/env bash
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$PROJECT_DIR/logs/incidents"
mkdir -p "$REPORT_DIR"

REPORT="$REPORT_DIR/incident-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "========================================"
    echo "NETOPS AUTOMATED INCIDENT REPORT"
    echo "========================================"
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo

    echo "=== APPLICATION HEALTH ==="
    curl -sS -i --max-time 5 \
        http://localhost:8080/health || true
    echo
    echo

    echo "=== DOCKER CONTAINER STATUS ==="
    docker ps -a \
        --filter "name=netops-" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo

    echo "=== DOCKER NETWORK ==="
    docker network inspect netops-project_netops-internal \
        --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' \
        2>&1 || true
    echo

    echo "=== NGINX LOGS (LAST 20 LINES) ==="
    docker logs --tail 20 netops-nginx 2>&1 || true
    echo

    echo "=== FASTAPI LOGS (LAST 20 LINES) ==="
    docker logs --tail 20 netops-app 2>&1 || true
    echo

    echo "=== DNS RESOLUTION ==="
    getent ahosts example.com || true
    echo

    echo "=== INCIDENT REPORT COMPLETE ==="
} > "$REPORT" 2>&1

echo "NETOPS incident report saved:"
echo "$REPORT"
