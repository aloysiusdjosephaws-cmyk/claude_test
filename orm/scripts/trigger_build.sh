#!/usr/bin/env bash
# trigger_build.sh
# Triggers an OCI DevOps Build Pipeline run and waits for it to succeed.
# Called by Terraform null_resource.trigger_backend_build and trigger_frontend_build.
set -euo pipefail

echo "==> [trigger_build:${PIPELINE_TYPE}] Starting build pipeline..."
echo "    Pipeline ID : ${PIPELINE_ID}"
echo "    Image repo  : ${IMAGE_REPO}:${IMAGE_TAG}"

# ── Build the arguments JSON ──────────────────────────────────────────────────
COMMON_ARGS='[
  {"name":"REGION",            "value":"'"${REGION}"'"},
  {"name":"TENANCY_NAMESPACE", "value":"'"${TENANCY_NAMESPACE}"'"},
  {"name":"IMAGE_TAG",         "value":"'"${IMAGE_TAG}"'"},
  {"name":"SOURCE_BUCKET",     "value":"'"${SOURCE_BUCKET}"'"},
  {"name":"DEVOPS_GIT_USERNAME","value":"'"${DEVOPS_GIT_USERNAME}"'"},
  {"name":"AUTH_TOKEN",        "value":"'"${AUTH_TOKEN}"'"}
]'

if [ "${PIPELINE_TYPE}" = "backend" ]; then
  EXTRA_ARGS='[{"name":"BACKEND_IMAGE_REPO","value":"'"${IMAGE_REPO}"'"}]'
else
  EXTRA_ARGS='[
    {"name":"FRONTEND_IMAGE_REPO","value":"'"${IMAGE_REPO}"'"},
    {"name":"API_GATEWAY_URL",    "value":"'"${API_GATEWAY_URL:-}"'"},
    {"name":"FRONTEND_BUCKET",    "value":"'"${FRONTEND_BUCKET:-}"'"}
  ]'
fi

# Merge arrays
ALL_ARGS=$(python3 -c "
import json,sys
a = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
print(json.dumps(a+b))
" "${COMMON_ARGS}" "${EXTRA_ARGS}")

ARGS_PAYLOAD='{"items":'"${ALL_ARGS}"'}'

# ── Trigger the build run ────────────────────────────────────────────────────
echo "    Triggering build pipeline..."
RUN_RESPONSE=$(oci devops build-run create \
  --build-pipeline-id "${PIPELINE_ID}" \
  --build-run-arguments "${ARGS_PAYLOAD}" \
  --display-name "orm-deploy-$(date +%Y%m%d%H%M%S)" \
  --region "${REGION}" \
  2>&1)

BUILD_RUN_ID=$(echo "${RUN_RESPONSE}" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(data['data']['id'])
" 2>/dev/null) || {
  echo "ERROR: Failed to trigger build pipeline."
  echo "${RUN_RESPONSE}"
  exit 1
}

echo "    Build run ID: ${BUILD_RUN_ID}"

# ── Poll until the build run completes ───────────────────────────────────────
echo "    Waiting for build to complete (this may take 10-20 minutes)..."
MAX_WAIT=1800   # 30 minutes
POLL_INTERVAL=30
ELAPSED=0

while true; do
  STATUS=$(oci devops build-run get \
    --build-run-id "${BUILD_RUN_ID}" \
    --region "${REGION}" \
    --query 'data."lifecycle-state"' \
    --raw-output 2>/dev/null) || STATUS="UNKNOWN"

  echo "    [${ELAPSED}s] Status: ${STATUS}"

  case "${STATUS}" in
    SUCCEEDED)
      echo "==> [trigger_build:${PIPELINE_TYPE}] Build pipeline SUCCEEDED."
      exit 0
      ;;
    FAILED|CANCELING|CANCELED)
      echo "ERROR: Build pipeline ${STATUS}. Check DevOps build logs in OCI Console."
      exit 1
      ;;
    IN_PROGRESS|ACCEPTED|WAITING_FOR_APPROVAL)
      ;;
    *)
      echo "    Unknown status '${STATUS}', continuing to poll..."
      ;;
  esac

  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Timed out waiting for build pipeline after ${MAX_WAIT}s."
    exit 1
  fi

  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done
