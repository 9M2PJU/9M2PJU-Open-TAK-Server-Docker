#!/bin/bash
set -e

echo "============================================"
echo "  OpenTAKServer Docker Entrypoint"
echo "============================================"

export OTS_DATA_FOLDER="${OTS_DATA_FOLDER:-/data/ots}"
mkdir -p "${OTS_DATA_FOLDER}/logs"

# Run one-time initialization
/opt/ots/start.sh

echo "Starting OTS processes via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ots.conf
