#!/bin/bash

echo "=== Fixing PostgreSQL pg_hba.conf ==="
docker exec postgresql bash -c "echo 'host all all 0.0.0.0/0 trust' >> /var/lib/postgresql/data/pg_hba.conf"
docker exec postgresql psql -U postgres -c "SELECT pg_reload_conf();"
echo "✓ PostgreSQL configuration reloaded"
echo ""

echo "=== Checking PostgreSQL logs ==="
docker logs postgresql --tail 5
echo ""

echo "=== Checking Kong certificate directory ==="
if [ -d "/volumes/supos/data/kong/certificationfile" ]; then
    ls -la /volumes/supos/data/kong/certificationfile/
else
    echo "Creating Kong certificate directory..."
    mkdir -p /volumes/supos/data/kong/certificationfile
    echo "✓ Directory created"
fi
echo ""

echo "=== Checking TSDB config ==="
if [ -f "/volumes/supos/data/tsdb/conf/postgresql.conf" ]; then
    echo "TSDB config file exists, checking first line:"
    head -5 /volumes/supos/data/tsdb/conf/postgresql.conf
else
    echo "TSDB config file not found at /volumes/supos/data/tsdb/conf/postgresql.conf"
fi
