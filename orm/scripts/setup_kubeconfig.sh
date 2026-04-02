#!/usr/bin/env bash
# setup_kubeconfig.sh
# Configures kubectl to talk to the OKE cluster.
# Waits for the cluster to be ACTIVE before proceeding.
set -euo pipefail

echo "==> [setup_kubeconfig] Configuring kubectl for OKE cluster..."
echo "    Cluster ID : ${CLUSTER_ID}"
echo "    Region     : ${REGION}"

# ── Install kubectl if missing ────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "    Installing kubectl..."
  K8S_VERSION="v1.29.0"
  curl -sLO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  mv kubectl /usr/local/bin/kubectl
fi

# ── Install Helm if missing ───────────────────────────────────────────────────
if ! command -v helm &>/dev/null; then
  echo "    Installing Helm 3..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ── Wait for cluster to be ACTIVE ─────────────────────────────────────────────
echo "    Waiting for OKE cluster to be ACTIVE..."
MAX_WAIT=1800
ELAPSED=0
POLL_INTERVAL=30

while true; do
  STATUS=$(oci ce cluster get \
    --cluster-id "${CLUSTER_ID}" \
    --region "${REGION}" \
    --query 'data."lifecycle-state"' \
    --raw-output 2>/dev/null) || STATUS="UNKNOWN"

  echo "    [${ELAPSED}s] Cluster status: ${STATUS}"

  [ "${STATUS}" = "ACTIVE" ] && break

  if [ "${STATUS}" = "FAILED" ] || [ "${STATUS}" = "DELETED" ]; then
    echo "ERROR: OKE cluster is in state ${STATUS}."
    exit 1
  fi

  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Timed out waiting for OKE cluster to be ACTIVE."
    exit 1
  fi

  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# ── Wait for at least one node to be ACTIVE ───────────────────────────────────
echo "    Waiting for worker nodes to be ACTIVE..."
ELAPSED=0
while true; do
  ACTIVE_NODES=$(oci ce node-pool list \
    --cluster-id "${CLUSTER_ID}" \
    --region "${REGION}" \
    --compartment-id "$(oci ce cluster get --cluster-id "${CLUSTER_ID}" --region "${REGION}" --query 'data."compartment-id"' --raw-output)" \
    --query 'length(data[?"lifecycle-state"==`ACTIVE`])' \
    --raw-output 2>/dev/null) || ACTIVE_NODES=0

  echo "    [${ELAPSED}s] Active node pools: ${ACTIVE_NODES}"
  [ "${ACTIVE_NODES}" -ge 1 ] && break

  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "WARNING: Timed out waiting for node pool. Proceeding anyway..."
    break
  fi

  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# ── Create kubeconfig ─────────────────────────────────────────────────────────
echo "    Creating kubeconfig..."
mkdir -p ~/.kube
oci ce cluster create-kubeconfig \
  --cluster-id "${CLUSTER_ID}" \
  --region "${REGION}" \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT \
  --file ~/.kube/config

chmod 600 ~/.kube/config

# ── Verify connectivity ───────────────────────────────────────────────────────
echo "    Verifying kubectl connectivity..."
MAX_KUBECTL_WAIT=300
ELAPSED=0
while ! kubectl get nodes &>/dev/null 2>&1; do
  if [ "${ELAPSED}" -ge "${MAX_KUBECTL_WAIT}" ]; then
    echo "ERROR: kubectl cannot reach OKE API after ${MAX_KUBECTL_WAIT}s."
    exit 1
  fi
  echo "    Waiting for kubectl connectivity... [${ELAPSED}s]"
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done

kubectl get nodes
echo "==> [setup_kubeconfig] kubectl configured successfully."
