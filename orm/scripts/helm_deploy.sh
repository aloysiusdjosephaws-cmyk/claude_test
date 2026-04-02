#!/usr/bin/env bash
# helm_deploy.sh
# Deploys (or upgrades) the fullstack-app Helm chart to OKE.
# Uses the OCI-specific values: LoadBalancer service, no frontend K8s deployment
# (frontend is served from Object Storage), OCIR images, oci-bv storage class.
set -euo pipefail

echo "==> [helm_deploy] Deploying ${RELEASE_NAME} via Helm..."
echo "    Chart dir   : ${HELM_CHART_DIR}"
echo "    Backend img : ${BACKEND_IMAGE_REPO}:${IMAGE_TAG}"

# ── Write OCI-specific values override file ───────────────────────────────────
VALUES_FILE=$(mktemp /tmp/helm-values-oci-XXXXXX.yaml)
trap 'rm -f "${VALUES_FILE}"' EXIT

cat > "${VALUES_FILE}" <<EOF
backend:
  image:
    repository: ${BACKEND_IMAGE_REPO}
    tag: "${IMAGE_TAG}"
    pullPolicy: Always
  replicaCount: 2
  service:
    type: LoadBalancer
    port: 8080
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
  hsqldb:
    storage:
      size: 5Gi
      storageClassName: "oci-bv"
      mountPath: /data
  env:
    SPRING_DATASOURCE_URL: "jdbc:hsqldb:file:/data/filedb;shutdown=true"
    SPRING_JPA_HIBERNATE_DDL_AUTO: "update"
    SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE: "10MB"
    SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE: "10MB"

frontend:
  image:
    repository: ${FRONTEND_IMAGE_REPO}
    tag: "${IMAGE_TAG}"
    pullPolicy: Always
  replicaCount: 0
  ingress:
    enabled: false

imagePullSecrets:
  - name: ocir-secret
EOF

echo "    Generated values file: ${VALUES_FILE}"

# ── Helm upgrade --install (idempotent) ───────────────────────────────────────
helm upgrade --install "${RELEASE_NAME}" "${HELM_CHART_DIR}" \
  -f "${VALUES_FILE}" \
  --namespace default \
  --create-namespace \
  --timeout 10m \
  --wait \
  --atomic

echo "    Helm release status:"
helm status "${RELEASE_NAME}" --namespace default

echo "==> [helm_deploy] Helm deploy completed successfully."
