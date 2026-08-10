#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================"
echo "  Starting Auth & Users Services"
echo "================================================"
echo ""

"$SCRIPT_DIR/microservice-auth-service/start.sh"
echo ""
"$SCRIPT_DIR/microservice-users-service/start.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Both services are running!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Access via nginx gateway:"
echo "    http://localhost/auth/*"
echo "    http://localhost/users/*"
echo ""
echo "  View logs:"
echo "    docker logs -f microservice-auth-service-app"
echo "    docker logs -f microservice-users-service-app"
echo ""
echo "  Stop services:"
echo "    $SCRIPT_DIR/stop-services.sh"
echo ""
