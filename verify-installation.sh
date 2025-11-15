#!/bin/bash

echo "============================================"
echo "supOS-CE Fresh Installation Verification"
echo "============================================"
echo ""

# Check if running from correct directory
if [ ! -f "docker-compose-4c8g.yml" ]; then
    echo "ERROR: Please run this script from the supOS-CE installation directory"
    exit 1
fi

echo "[1/6] Checking Docker Compose services status..."
echo "-------------------------------------------"
docker-compose -f docker-compose-4c8g.yml ps
echo ""

echo "[2/6] Checking critical service health..."
echo "-------------------------------------------"
CRITICAL_SERVICES="keycloak backend frontend kong postgresql"
for service in $CRITICAL_SERVICES; do
    if docker ps | grep -q $service; then
        STATUS=$(docker inspect --format='{{.State.Status}}' $service 2>/dev/null)
        echo "✓ $service: $STATUS"
    else
        echo "✗ $service: NOT RUNNING"
    fi
done
echo ""

echo "[3/6] Waiting for services to initialize (30 seconds)..."
echo "-------------------------------------------"
sleep 30
echo "Done waiting."
echo ""

echo "[4/6] Checking Keycloak health..."
echo "-------------------------------------------"
KEYCLOAK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://172.17.5.239:8080/health 2>/dev/null)
if [ "$KEYCLOAK_STATUS" = "200" ]; then
    echo "✓ Keycloak is healthy (HTTP $KEYCLOAK_STATUS)"
else
    echo "⚠ Keycloak health check returned: $KEYCLOAK_STATUS"
    echo "Checking Keycloak logs:"
    docker logs keycloak --tail 10 | grep -i "started\|error\|exception"
fi
echo ""

echo "[5/6] Checking Backend service..."
echo "-------------------------------------------"
echo "Backend environment variables:"
docker exec backend printenv | grep -E "OAUTH_ISSUER_URI|KEYCLOAK" | head -5
echo ""
echo "Recent backend logs:"
docker logs backend --tail 20 | grep -i "started\|error\|keycloak\|oauth"
echo ""

echo "[6/6] Testing frontend access..."
echo "-------------------------------------------"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://172.17.5.239:8088/ 2>/dev/null)
echo "Frontend HTTP status: $FRONTEND_STATUS"
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✓ Frontend is accessible"
elif [ "$FRONTEND_STATUS" = "503" ]; then
    echo "⚠ Frontend returned 503 - backend services may still be initializing"
    echo "Kong error:"
    curl -s http://172.17.5.239:8088/ 2>&1 | head -3
else
    echo "✗ Unexpected status code"
fi
echo ""

echo "============================================"
echo "Verification Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. If services are still initializing, wait another 30-60 seconds"
echo "2. Open browser to: http://172.17.5.239:8088"
echo "3. Login with: username=supos, password=supos"
echo "4. If login fails, check: docker logs backend -f"
echo ""
