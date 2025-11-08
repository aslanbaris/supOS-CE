#!/bin/bash
cd /home/user/supOS-CE

echo "Stopping and removing backend container..."
docker-compose -f docker-compose-4c8g.yml stop backend
docker-compose -f docker-compose-4c8g.yml rm -f backend

echo "Recreating backend container with updated environment variables..."
docker-compose -f docker-compose-4c8g.yml up -d backend

echo "Waiting for backend to start..."
sleep 10

echo "Checking backend environment variables:"
docker exec backend printenv | grep OAUTH_ISSUER_URI

echo ""
echo "Checking backend logs for Keycloak connection:"
docker logs backend --tail 20 | grep -i "issuer\|keycloak\|oauth"
