#!/usr/bin/env bash
# create_bundle.sh
# Creates the OCI Resource Manager (ORM) zip bundle from this directory.
#
# Usage:
#   cd /path/to/claude_test/orm
#   ./create_bundle.sh
#
# Output: ../fileservice-orm.zip  (ready to upload to OCI Resource Manager)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
OUTPUT_ZIP="${PROJECT_ROOT}/fileservice-orm.zip"
WORK_DIR=$(mktemp -d)

echo "================================================================"
echo " Building OCI Resource Manager Bundle"
echo "================================================================"
echo " Project root : ${PROJECT_ROOT}"
echo " Work dir     : ${WORK_DIR}"
echo " Output zip   : ${OUTPUT_ZIP}"
echo ""

# ── Validate source directories ───────────────────────────────────────────────
for DIR in "${PROJECT_ROOT}/backend" "${PROJECT_ROOT}/frontend"; do
  if [ ! -d "${DIR}" ]; then
    echo "ERROR: Required directory not found: ${DIR}"
    echo "       Run this script from the orm/ directory inside the project."
    exit 1
  fi
done

# ── Copy Terraform files to zip root ─────────────────────────────────────────
# ORM expects .tf files at the ROOT of the zip.
# Other directories (scripts/, build_specs/, helm/, app/) also sit at the root.
echo "--> Copying Terraform configuration files..."
cp "${SCRIPT_DIR}/terraform/"*.tf      "${WORK_DIR}/"
cp "${SCRIPT_DIR}/terraform/schema.yaml" "${WORK_DIR}/"

# ── Copy scripts ──────────────────────────────────────────────────────────────
echo "--> Copying shell scripts..."
mkdir -p "${WORK_DIR}/scripts"
cp "${SCRIPT_DIR}/scripts/"*.sh "${WORK_DIR}/scripts/"
chmod +x "${WORK_DIR}/scripts/"*.sh

# ── Copy build specs ──────────────────────────────────────────────────────────
echo "--> Copying DevOps build specs..."
mkdir -p "${WORK_DIR}/build_specs"
cp "${SCRIPT_DIR}/build_specs/"*.yaml "${WORK_DIR}/build_specs/"

# ── Copy Helm chart ───────────────────────────────────────────────────────────
echo "--> Copying Helm chart..."
cp -r "${SCRIPT_DIR}/helm" "${WORK_DIR}/helm"

# ── Copy application source code ─────────────────────────────────────────────
# Sits at zip_root/app/ — Terraform's archive_file references it as
# ${path.module}/app (path.module = zip root during ORM apply).
echo "--> Copying application source code..."
mkdir -p "${WORK_DIR}/app/backend" "${WORK_DIR}/app/frontend"

# Backend — exclude compiled artifacts and database files
if command -v rsync &>/dev/null; then
  rsync -a --exclude='target/' \
            --exclude='*.class' \
            --exclude='filedb.*' \
            --exclude='.git' \
            "${PROJECT_ROOT}/backend/" \
            "${WORK_DIR}/app/backend/"

  # Frontend — exclude node_modules and dist (npm ci runs inside DevOps; keeps zip small)
  rsync -a --exclude='node_modules/' \
            --exclude='dist/' \
            --exclude='.angular/' \
            --exclude='.git' \
            "${PROJECT_ROOT}/frontend/" \
            "${WORK_DIR}/app/frontend/"
else
  # Fallback if rsync is not available
  cp -r "${PROJECT_ROOT}/backend/." "${WORK_DIR}/app/backend/"
  cp -r "${PROJECT_ROOT}/frontend/." "${WORK_DIR}/app/frontend/"
  rm -rf "${WORK_DIR}/app/backend/target" \
         "${WORK_DIR}/app/backend/filedb."* \
         "${WORK_DIR}/app/frontend/node_modules" \
         "${WORK_DIR}/app/frontend/dist" \
         "${WORK_DIR}/app/frontend/.angular" 2>/dev/null || true
fi

# ── Show directory tree ───────────────────────────────────────────────────────
echo ""
echo "--> Bundle contents:"
if command -v tree &>/dev/null; then
  tree "${WORK_DIR}" -L 4 --dirsfirst
else
  find "${WORK_DIR}" -not -path '*/\.*' | sort | head -80
fi

# ── Create the zip ────────────────────────────────────────────────────────────
echo ""
echo "--> Creating zip archive..."
rm -f "${OUTPUT_ZIP}"
cd "${WORK_DIR}"
zip -r "${OUTPUT_ZIP}" . -x "*.DS_Store" -x "*/.git/*" -x "__MACOSX/*"
cd "${SCRIPT_DIR}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "${WORK_DIR}"

ZIP_SIZE=$(du -sh "${OUTPUT_ZIP}" | cut -f1)
echo ""
echo "================================================================"
echo " Bundle created successfully!"
echo "================================================================"
echo " File : ${OUTPUT_ZIP}"
echo " Size : ${ZIP_SIZE}"
echo ""
echo " Next steps:"
echo "   1. Log in to OCI Console"
echo "   2. Go to: Developer Services → Resource Manager → Stacks"
echo "   3. Click 'Create Stack'"
echo "   4. Select '.Zip file' and upload: fileservice-orm.zip"
echo "   5. Fill in the required variables (see ORM_GUIDE.md)"
echo "   6. Click 'Next' → 'Next' → 'Create'"
echo "   7. Click 'Terraform Actions → Apply'"
echo "   8. Monitor the apply log (takes ~30-40 minutes total)"
echo "================================================================"
