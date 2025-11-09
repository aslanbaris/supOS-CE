#!/bin/bash

echo "============================================"
echo "supOS-CE Login Test & Monitor"
echo "============================================"
echo ""

echo "This script will monitor backend logs while you test login."
echo "Please open your browser to: http://172.17.5.239:8088"
echo "Then login with: username=supos, password=supos"
echo ""
echo "Press Enter to start monitoring backend logs..."
read

echo "-------------------------------------------"
echo "Monitoring backend logs (Ctrl+C to stop)..."
echo "-------------------------------------------"
echo ""

# Monitor backend logs with relevant filters
docker logs backend -f --tail 50 2>&1 | grep --line-buffered -E "token|auth|keycloak|error|exception|login|OAuth|issuer|admin" | while read line; do
    # Colorize important messages if terminal supports it
    if echo "$line" | grep -qi "error\|exception\|failed"; then
        echo -e "\033[0;31m$line\033[0m"  # Red for errors
    elif echo "$line" | grep -qi "success\|token.*获取成功"; then
        echo -e "\033[0;32m$line\033[0m"  # Green for success
    else
        echo "$line"
    fi
done
