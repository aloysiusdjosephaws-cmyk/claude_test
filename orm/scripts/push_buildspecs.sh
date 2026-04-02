#!/usr/bin/env bash
# push_buildspecs.sh
# Pushes the build spec YAML files to the OCI DevOps Code Repository via git HTTPS.
# Called by Terraform null_resource.push_buildspecs.
set -euo pipefail

echo "==> [push_buildspecs] Pushing build specs to DevOps Code Repository..."
echo "    Repository URL : ${REPO_HTTPS_URL}"
echo "    Git username   : ${GIT_USERNAME}"
echo "    Specs dir      : ${SPECS_DIR}"

# ── Install git if missing ────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "    Installing git..."
  yum install -y git -q 2>/dev/null || apt-get install -y git -q 2>/dev/null || true
fi

# ── Configure git credential store (one-time, non-interactive) ───────────────
git config --global credential.helper store
git config --global user.email "orm-deploy@fileservice.local"
git config --global user.name  "ORM Deployer"

# Embed credentials in the URL for the credential store
ENCODED_TOKEN=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "${AUTH_TOKEN}")
CRED_URL=$(echo "${REPO_HTTPS_URL}" | sed "s|https://|https://${GIT_USERNAME}:${ENCODED_TOKEN}@|")

# Write credentials to git credential store
echo "$(echo "${REPO_HTTPS_URL}" | sed 's|/namespaces.*||') username=${GIT_USERNAME}
password=${AUTH_TOKEN}" > ~/.git-credentials
chmod 600 ~/.git-credentials

# ── Clone the empty repository ────────────────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "    Cloning repository to ${WORK_DIR}..."
git clone "${CRED_URL}" "${WORK_DIR}" 2>/dev/null || {
  # Repository might be empty (no commits yet) — initialize it
  cd "${WORK_DIR}"
  git init
  git remote add origin "${CRED_URL}"
}

# ── Copy build spec files ─────────────────────────────────────────────────────
mkdir -p "${WORK_DIR}/build_specs"
cp "${SPECS_DIR}/backend_build_spec.yaml"  "${WORK_DIR}/build_specs/"
cp "${SPECS_DIR}/frontend_build_spec.yaml" "${WORK_DIR}/build_specs/"

# ── Commit and push ───────────────────────────────────────────────────────────
cd "${WORK_DIR}"

# Create README if repository is empty
if [ ! -f README.md ]; then
  echo "# Build Specs for File Service CI/CD" > README.md
fi

git add -A
git diff --cached --quiet && { echo "    No changes to commit."; exit 0; }

git commit -m "chore: update build spec files [ORM deploy]"

# Push — try main branch first, fall back to master
git push origin HEAD:main 2>/dev/null || git push origin HEAD:master 2>/dev/null || {
  # First push to empty repo
  git push --set-upstream origin HEAD:main
}

echo "==> [push_buildspecs] Build specs pushed successfully."
