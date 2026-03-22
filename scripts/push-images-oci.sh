#!/usr/bin/env bash
# Push backend and frontend images to OCI Container Registry (OCIR)
#
# Prerequisites:
#   - Docker installed and running
#   - OCI CLI configured (oci setup config) or env vars set
#   - Auth token created in OCI Console (User Settings → Auth Tokens)
#
# Usage:
#   export OCI_REGION=ap-sydney-1
#   export OCI_TENANCY_NAMESPACE=mytenancy
#   export OCI_USERNAME=myuser@example.com
#   export OCI_AUTH_TOKEN=your-auth-token
#   ./scripts/push-images-oci.sh [TAG]

set -euo pipefail

TAG="${1:-latest}"

: "${OCI_REGION:?Set OCI_REGION (e.g. ap-sydney-1)}"
: "${OCI_TENANCY_NAMESPACE:?Set OCI_TENANCY_NAMESPACE}"
: "${OCI_USERNAME:?Set OCI_USERNAME (your OCI login email or tenancy/username)}"
: "${OCI_AUTH_TOKEN:?Set OCI_AUTH_TOKEN}"

REGISTRY="${OCI_REGION}.ocir.io"
BACKEND_IMAGE="${REGISTRY}/${OCI_TENANCY_NAMESPACE}/file-service:${TAG}"
FRONTEND_IMAGE="${REGISTRY}/${OCI_TENANCY_NAMESPACE}/frontend-client:${TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Logging in to OCIR: ${REGISTRY}"
echo "${OCI_AUTH_TOKEN}" | docker login "${REGISTRY}" \
  --username "${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" \
  --password-stdin

echo "==> Building backend image: ${BACKEND_IMAGE}"
docker build -t "${BACKEND_IMAGE}" "${ROOT_DIR}/backend"

echo "==> Building frontend image: ${FRONTEND_IMAGE}"
docker build -t "${FRONTEND_IMAGE}" "${ROOT_DIR}/frontend"

echo "==> Pushing backend image"
docker push "${BACKEND_IMAGE}"

echo "==> Pushing frontend image"
docker push "${FRONTEND_IMAGE}"

echo ""
echo "Done. Images pushed:"
echo "  ${BACKEND_IMAGE}"
echo "  ${FRONTEND_IMAGE}"
echo ""
echo "Next — deploy to OKE:"
echo "  kubectl create secret docker-registry ocir-secret \\"
echo "    --docker-server=${REGISTRY} \\"
echo "    --docker-username='${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}' \\"
echo "    --docker-password='YOUR_OCI_AUTH_TOKEN'"
echo ""
echo "  helm upgrade --install my-release ./deploy/helm/fullstack-app \\"
echo "    -f ./deploy/helm/fullstack-app/values-oci.yaml \\"
echo "    --set backend.image.tag=${TAG}"
