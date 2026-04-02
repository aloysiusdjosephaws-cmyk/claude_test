#!/usr/bin/env bash
# create_api_gw_deployment.sh
# 1. Waits for the OKE backend LoadBalancer IP to be assigned.
# 2. Creates the OCI API Gateway deployment with routes pointing to that IP.
set -euo pipefail

echo "==> [api_gw_deployment] Waiting for backend LoadBalancer IP..."
echo "    Release name : ${RELEASE_NAME}"
echo "    Gateway ID   : ${GATEWAY_ID}"

# ── Wait for LoadBalancer IP ───────────────────────────────────────────────────
MAX_WAIT=900  # 15 minutes
ELAPSED=0
POLL_INTERVAL=20
LB_IP=""

SVC_NAME="${RELEASE_NAME}-fullstack-app-backend"

while true; do
  LB_IP=$(kubectl get service "${SVC_NAME}" \
    --namespace default \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null) || LB_IP=""

  if [ -n "${LB_IP}" ] && [ "${LB_IP}" != "null" ]; then
    echo "    LoadBalancer IP: ${LB_IP}"
    break
  fi

  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Timed out waiting for LoadBalancer IP after ${MAX_WAIT}s."
    kubectl describe service "${SVC_NAME}" --namespace default || true
    exit 1
  fi

  echo "    [${ELAPSED}s] Waiting for LoadBalancer IP (service: ${SVC_NAME})..."
  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

BACKEND_URL="http://${LB_IP}:8080"
echo "    Backend URL: ${BACKEND_URL}"

# ── Build the API Gateway deployment spec JSON ────────────────────────────────
SPEC_JSON=$(python3 - <<PYEOF
import json

spec = {
  "requestPolicies": {
    "cors": {
      "type": "CORS",
      "allowedOrigins": ["*"],
      "allowedMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      "allowedHeaders": ["Content-Type", "Authorization", "X-Requested-With"],
      "exposedHeaders": ["Content-Disposition"],
      "isAllowCredentialsEnabled": False,
      "maxAgeInSeconds": 3600
    }
  },
  "routes": [
    {
      "path": "/files",
      "methods": ["GET"],
      "backend": {"type": "HTTP_BACKEND", "url": "${BACKEND_URL}/files"}
    },
    {
      "path": "/files/upload",
      "methods": ["POST"],
      "backend": {"type": "HTTP_BACKEND", "url": "${BACKEND_URL}/files/upload"}
    },
    {
      "path": "/files/download/{id}",
      "methods": ["GET"],
      "backend": {"type": "HTTP_BACKEND", "url": "${BACKEND_URL}/files/download/\${request.path[id]}"}
    },
    {
      "path": "/actuator/health",
      "methods": ["GET"],
      "backend": {"type": "HTTP_BACKEND", "url": "${BACKEND_URL}/actuator/health"}
    }
  ]
}
print(json.dumps(spec))
PYEOF
)

# ── Create or update the API Gateway deployment ───────────────────────────────

# Check for existing deployment
EXISTING_DEPLOYMENT_ID=$(oci api-gateway deployment list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --gateway-id "${GATEWAY_ID}" \
  --region "${REGION}" \
  --query 'data.items[0].id' \
  --raw-output 2>/dev/null) || EXISTING_DEPLOYMENT_ID=""

DEPLOYMENT_JSON=$(python3 - <<PYEOF
import json

display_name = "${APP_NAME}-v1"
path_prefix = "/v1"
spec = json.loads('''${SPEC_JSON}''')
payload = {
  "displayName": display_name,
  "gatewayId": "${GATEWAY_ID}",
  "compartmentId": "${COMPARTMENT_OCID}",
  "pathPrefix": path_prefix,
  "specification": spec
}
print(json.dumps(payload))
PYEOF
)

if [ -n "${EXISTING_DEPLOYMENT_ID}" ] && [ "${EXISTING_DEPLOYMENT_ID}" != "null" ]; then
  echo "    Updating existing API Gateway deployment: ${EXISTING_DEPLOYMENT_ID}"
  oci api-gateway deployment update \
    --deployment-id "${EXISTING_DEPLOYMENT_ID}" \
    --specification "$(echo "${DEPLOYMENT_JSON}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['specification']))")" \
    --region "${REGION}" \
    --force \
    --wait-for-state ACTIVE \
    --wait-interval-seconds 15 \
    --max-wait-seconds 300
  DEPLOYMENT_ID="${EXISTING_DEPLOYMENT_ID}"
else
  echo "    Creating new API Gateway deployment (path prefix: /v1)..."
  CREATE_RESPONSE=$(oci api-gateway deployment create \
    --from-json "${DEPLOYMENT_JSON}" \
    --region "${REGION}" \
    --wait-for-state ACTIVE \
    --wait-interval-seconds 15 \
    --max-wait-seconds 300 \
    2>&1)
  DEPLOYMENT_ID=$(echo "${CREATE_RESPONSE}" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null) || true
fi

echo "    API Gateway deployment ID: ${DEPLOYMENT_ID:-created}"

# ── Verify ────────────────────────────────────────────────────────────────────
GATEWAY_HOSTNAME=$(oci api-gateway gateway get \
  --gateway-id "${GATEWAY_ID}" \
  --region "${REGION}" \
  --query 'data.hostname' \
  --raw-output 2>/dev/null) || GATEWAY_HOSTNAME="(check OCI Console)"

echo ""
echo "================================================================"
echo " Deployment Complete!"
echo "================================================================"
echo " Backend API:  https://${GATEWAY_HOSTNAME}/v1/files"
echo " Health check: https://${GATEWAY_HOSTNAME}/v1/actuator/health"
echo " Frontend:     https://objectstorage.${REGION}.oraclecloud.com/n/${TENANCY_NAMESPACE}/b/${FRONTEND_BUCKET}/o/index.html"
echo "================================================================"

echo "==> [api_gw_deployment] API Gateway deployment complete."
