#!/bin/bash

PASS=0
FAIL=0

echo "================================"
echo "   NETOPS Network Diagnostics"
echo "================================"

echo ""
echo "[1] Checking network connectivity..."

if ping -c 4 -W 2 1.1.1.1 > /dev/null 2>&1; then
    echo "[PASS] Network connectivity successful"
    ((PASS++))
else
    echo "[FAIL] Network connectivity failed"
    ((FAIL++))
fi

echo ""
echo "Network connectivity check completed."

echo ""
echo "[2] Checking DNS resolution..."

if getent ahostsv4 google.com > /dev/null 2>&1; then
    echo "[PASS] DNS resolution successful"
    ((PASS++))
else
    echo "[FAIL] DNS resolution failed"
fi
echo ""
echo "[3] Checking TCP port 80..."

if timeout 3 bash -c 'echo > /dev/tcp/127.0.0.1/80' 2>/dev/null; then
    echo "[PASS] TCP port 80 is reachable"
    ((PASS++))
else
    echo "[FAIL] TCP port 80 is unreachable"
    ((FAIL++))
fi
echo ""
echo "[4] Checking HTTP response..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "[PASS] HTTP 200 OK"
    ((PASS++))
else
    echo "[FAIL] HTTP check failed (Status: $HTTP_STATUS)"
    ((FAIL++))
fi
echo ""
echo "[5] Checking Linux services..."

if systemctl is-active --quiet nginx; then
    echo "[PASS] Nginx service is running"
    ((PASS++))
else
    echo "[FAIL] Nginx service is not running"
    ((FAIL++))
fi

if systemctl is-active --quiet netops-backend; then
    echo "[PASS] Python backend service is running"
    ((PASS++))
else
    echo "[FAIL] Python backend service is not running"
    ((FAIL++))
fi
echo ""
echo "================================"
echo "     Diagnostic Summary"
echo "================================"

TOTAL=$((PASS + FAIL))

echo "Total Checks : $TOTAL"
echo "Passed       : $PASS"
echo "Failed       : $FAIL"

echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "Overall Status: HEALTHY"
    exit 0
else
    echo "Overall Status: UNHEALTHY"
    exit 1
fi
