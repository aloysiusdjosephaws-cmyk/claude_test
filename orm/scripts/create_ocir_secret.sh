#!/usr/bin/env bash
# create_ocir_secret.sh
# Creates a Kubernetes docker-registry secret so OKE can pull images from OCIR.
set -euo pipefail

echo "==> [create_ocir_secret] Creating OCIR image pull secret in Kubernetes..."
echo "    OCIR server       : ${OCIR_SERVER}"
echo "    Docker username   : ${DEVOPS_GIT_USERNAME}"

SECRET_NAME="ocir-secret"

# Delete existing secret if it exists (idempotent)
kubectl delete secret "${SECRET_NAME}" --ignore-not-found=true

# Create the secret
kubectl create secret docker-registry "${SECRET_NAME}" \
  --docker-server="${OCIR_SERVER}" \
  --docker-username="${DEVOPS_GIT_USERNAME}" \
  --docker-password="${AUTH_TOKEN}" \
  --docker-email="orm-deploy@fileservice.local"

echo "    Secret '${SECRET_NAME}' created in namespace 'default'."
echo "==> [create_ocir_secret] Done."
