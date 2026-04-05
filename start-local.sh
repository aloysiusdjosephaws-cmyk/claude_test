#!/usr/bin/env bash
# start-local.sh — Start all services locally for development
# Usage: ./start-local.sh
# Stop:  Ctrl+C (kills all background processes)

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Application Manager — Local Dev ==="
echo ""

# Verify prerequisites
check_cmd() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found. Please install it."; exit 1; }; }
check_cmd java
check_cmd mvn
check_cmd node
check_cmd npm

JAVA_VER=$(java -version 2>&1 | head -1 | grep -oP '(?<=version ")\d+')
if [ "$JAVA_VER" -lt 17 ]; then echo "ERROR: Java 17+ required (found $JAVA_VER)"; exit 1; fi
echo "✓ Java $JAVA_VER"
echo "✓ Maven $(mvn -v 2>&1 | head -1 | awk '{print $3}')"
echo "✓ Node $(node -v)"
echo ""

# Install Angular deps if needed
if [ ! -d "$ROOT/frontend/node_modules" ]; then
  echo "Installing frontend dependencies..."
  (cd "$ROOT/frontend" && npm install)
fi

# Create local DB directory
mkdir -p "$HOME/.appmanager"

# Kill background jobs on exit
trap 'echo ""; echo "Stopping all services..."; kill $(jobs -p) 2>/dev/null; wait' EXIT INT TERM

echo "Starting services (check individual logs below)..."
echo ""

# 1. Audit Service
echo "[1/5] Audit Service        → http://localhost:8084/actuator/health"
(cd "$ROOT/services/audit-service" && mvn spring-boot:run -Dspring-boot.run.profiles=local -q 2>&1 | sed 's/^/[audit] /') &
sleep 8

# 2. User Management Service
echo "[2/5] User Management      → http://localhost:8081/actuator/health"
(cd "$ROOT/services/user-management-service" && mvn spring-boot:run -Dspring-boot.run.profiles=local -q 2>&1 | sed 's/^/[user-mgmt] /') &
sleep 8

# 3. Application Management Service
echo "[3/5] Application Mgmt     → http://localhost:8082/actuator/health"
(cd "$ROOT/services/application-management-service" && mvn spring-boot:run -Dspring-boot.run.profiles=local -q 2>&1 | sed 's/^/[app-mgmt] /') &
sleep 8

# 4. Document Management Service
echo "[4/5] Document Mgmt        → http://localhost:8083/actuator/health"
(cd "$ROOT/services/document-management-service" && mvn spring-boot:run -Dspring-boot.run.profiles=local -q 2>&1 | sed 's/^/[doc-mgmt] /') &
sleep 8

# 5. Angular frontend
echo "[5/5] Angular Frontend      → http://localhost:4200"
(cd "$ROOT/frontend" && npm start 2>&1 | sed 's/^/[angular] /') &

echo ""
echo "All services started. Open http://localhost:4200"
echo "Press Ctrl+C to stop everything."
echo ""

wait
