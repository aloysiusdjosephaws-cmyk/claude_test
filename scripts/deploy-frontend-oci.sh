#!/usr/bin/env bash
# Build Angular app and upload to OCI Object Storage for static hosting
#
# Prerequisites:
#   - Node 20+ and Angular CLI installed
#   - OCI CLI installed and configured (oci setup config)
#   - OCI Object Storage bucket created with public read access
#   - environment.prod.ts updated with your OCI API Gateway URL
#
# Usage:
#   export OCI_NAMESPACE=mytenancy
#   export OCI_BUCKET=my-frontend-bucket
#   export OCI_REGION=ap-sydney-1
#   ./scripts/deploy-frontend-oci.sh

set -euo pipefail

: "${OCI_NAMESPACE:?Set OCI_NAMESPACE (object storage namespace)}"
: "${OCI_BUCKET:?Set OCI_BUCKET (bucket name)}"
: "${OCI_REGION:?Set OCI_REGION (e.g. ap-sydney-1)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")/frontend"
DIST_DIR="${FRONTEND_DIR}/dist/frontend-client/browser"

echo "==> Building Angular app (production)"
cd "${FRONTEND_DIR}"
npm run build:prod

echo "==> Uploading to OCI Object Storage bucket: ${OCI_BUCKET}"
# Upload all files, preserving directory structure
find "${DIST_DIR}" -type f | while read -r file; do
  object_name="${file#${DIST_DIR}/}"
  content_type="application/octet-stream"

  case "${file##*.}" in
    html) content_type="text/html" ;;
    js)   content_type="application/javascript" ;;
    css)  content_type="text/css" ;;
    json) content_type="application/json" ;;
    ico)  content_type="image/x-icon" ;;
    png)  content_type="image/png" ;;
    svg)  content_type="image/svg+xml" ;;
    woff2) content_type="font/woff2" ;;
  esac

  echo "  Uploading: ${object_name} (${content_type})"
  oci os object put \
    --namespace "${OCI_NAMESPACE}" \
    --bucket-name "${OCI_BUCKET}" \
    --name "${object_name}" \
    --file "${file}" \
    --content-type "${content_type}" \
    --force \
    --region "${OCI_REGION}" > /dev/null
done

echo ""
echo "Done. Frontend deployed."
echo ""
echo "Object Storage URL:"
echo "  https://objectstorage.${OCI_REGION}.oraclecloud.com/n/${OCI_NAMESPACE}/b/${OCI_BUCKET}/o/index.html"
echo ""
echo "For a clean URL, configure:"
echo "  1. Bucket → Enable 'Emit Object Events'"
echo "  2. Add a pre-authenticated request or set the bucket as a static website"
echo "  3. Use OCI CDN / WAF for a custom domain"
