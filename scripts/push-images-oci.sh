#!/usr/bin/env bash
# Build and push all 5 service images to OCI Container Registry (OCIR)
#
# Prerequisites:
#   - Docker installed and running
#   - Auth token created: OCI Console → Profile → My Profile → Auth Tokens → Generate Token
#
# Usage:
#   export OCI_REGION=ap-sydney-1
#   export OCI_TENANCY_NAMESPACE=mytenancy
#   export OCI_USERNAME=oracleidentitycloudservice/your@email.com   # IDCS/federated
#   # OR: export OCI_USERNAME=your_username                         # local IAM user
#   export OCI_AUTH_TOKEN=your-auth-token
#   ./scripts/push-images-oci.sh [TAG]
#
# TAG defaults to "latest" if not supplied.

set -euo pipefail

TAG="${1:-latest}"

: "${OCI_REGION:?Set OCI_REGION (e.g. ap-sydney-1)}"
: "${OCI_TENANCY_NAMESPACE:?Set OCI_TENANCY_NAMESPACE}"
: "${OCI_USERNAME:?Set OCI_USERNAME}"
: "${OCI_AUTH_TOKEN:?Set OCI_AUTH_TOKEN}"

REGISTRY="${OCI_REGION}.ocir.io"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

SERVICES=(
  "audit-service:services/audit-service"
  "user-management-service:services/user-management-service"
  "application-management-service:services/application-management-service"
  "document-management-service:services/document-management-service"
  "frontend-client:frontend"
)

echo "==> Logging in to OCIR: ${REGISTRY}"
echo "${OCI_AUTH_TOKEN}" | docker login "${REGISTRY}" \
  --username "${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" \
  --password-stdin

for ENTRY in "${SERVICES[@]}"; do
  NAME="${ENTRY%%:*}"
  CONTEXT="${ENTRY##*:}"
  IMAGE="${REGISTRY}/${OCI_TENANCY_NAMESPACE}/${NAME}:${TAG}"
  echo ""
  echo "==> Building ${IMAGE}"
  docker build -t "${IMAGE}" "${ROOT_DIR}/${CONTEXT}"
  echo "==> Pushing ${IMAGE}"
  docker push "${IMAGE}"
done

echo ""
echo "Done. All images pushed to ${REGISTRY}/${OCI_TENANCY_NAMESPACE}/ with tag: ${TAG}"
echo ""
echo "Next — deploy to OKE (edit values-oci.yaml with your region/namespace/tag first):"
echo ""
echo "  kubectl create secret docker-registry ocir-secret \\"
echo "    --docker-server=${REGISTRY} \\"
echo "    --docker-username='${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}' \\"
echo "    --docker-password='YOUR_OCI_AUTH_TOKEN'"
echo ""
echo "  helm upgrade --install my-release ./deploy/helm/fullstack-app \\"
echo "    -f ./deploy/helm/fullstack-app/values-oci.yaml \\"
echo "    --set audit.env.JWT_SECRET=<secret> \\"
echo "    --set audit.env.INTERNAL_API_KEY=<key> \\"
echo "    --set userManagement.env.JWT_SECRET=<secret> \\"
echo "    --set userManagement.env.INTERNAL_API_KEY=<key> \\"
echo "    --set applicationManagement.env.JWT_SECRET=<secret> \\"
echo "    --set applicationManagement.env.INTERNAL_API_KEY=<key> \\"
echo "    --set documentManagement.env.JWT_SECRET=<secret> \\"
echo "    --set documentManagement.env.INTERNAL_API_KEY=<key>"
