# OCI Resource Manager (ORM) Deployment Guide

Upload one zip file → click Apply → everything deploys automatically. No manual console work.

---

## What Gets Deployed

| Resource | Service | Purpose |
|----------|---------|---------|
| VCN + subnets | OCI Networking | Isolated network (public + private subnets, IGW, NAT) |
| OKE Cluster + Node Pool | Oracle Kubernetes Engine | Runs the Spring Boot backend |
| OCIR Repositories | OCI Container Registry | Stores built Docker images |
| DevOps Project + Pipelines | OCI DevOps | Builds Docker images (Maven + Node.js) automatically |
| Object Storage (source) | OCI Object Storage | Temporary: holds app source zip during build |
| Object Storage (frontend) | OCI Object Storage | Permanent: hosts Angular static files |
| API Gateway | OCI API Gateway | Public HTTPS endpoint routing to backend |
| IAM Policies | OCI Identity | Required permissions for DevOps, OKE, OCIR |
| OCI Logging | OCI Logging | Captures DevOps build/deploy logs |

**Total apply time: ~30–45 minutes** (most of that is OKE cluster provisioning and DevOps build pipelines running).

---

## Prerequisites

These must be done **once before** uploading the zip. They take about 10 minutes.

### 1. OCI account with sufficient permissions

You need one of:
- **Tenancy Administrator** role, OR
- A group with these policies in the **root compartment**:
  ```
  Allow group <YourGroup> to manage all-resources in compartment <YourCompartment>
  Allow group <YourGroup> to manage dynamic-groups in tenancy
  Allow group <YourGroup> to manage policies in tenancy
  ```

The stack creates IAM Dynamic Groups and Policies at the **tenancy level** — this requires tenancy-admin or equivalent permission.

### 2. Create an Auth Token

An Auth Token is used for OCIR (Docker registry) login and DevOps git push.

1. OCI Console → Profile icon (top right) → **My Profile**
2. In the left menu: **Auth Tokens**
3. Click **Generate Token**
4. Enter description: `fileservice-orm`
5. Click **Generate Token**
6. **Copy the token immediately** — it is shown only once
7. Save it somewhere safe — you will paste it into the ORM stack form

### 3. Find your DevOps git username

Your DevOps git username combines the **tenancy namespace** and your **OCI username**.

**Step 3a — Find your tenancy namespace:**
- OCI Console → **Developer Services → Container Registry**
- The namespace is shown at the top (e.g., `mytenancynamespace`)

**Step 3b — Determine your username format:**

| Account type | Username format | Example |
|--------------|----------------|---------|
| **Federated / IDCS** (most common — you log in with your email) | `NAMESPACE/oracleidentitycloudservice/your@email.com` | `myns/oracleidentitycloudservice/john@company.com` |
| **Local IAM user** (you log in with username, not email) | `NAMESPACE/your_username` | `myns/johndoe` |

To check: OCI Console → Profile icon → **My Profile** → look at the **User** field. If it says `oracleidentitycloudservice/...` you're federated.

### 4. Generate an SSH public key (for OKE nodes)

If you already have one at `~/.ssh/id_rsa.pub`, skip this step.

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/oci_oke_key -N ""
cat ~/.ssh/oci_oke_key.pub
# Copy the output — you'll paste it into the ORM form
```

### 5. Check OKE Kubernetes version availability

To find available Kubernetes versions in your region:
1. OCI Console → **Developer Services → Kubernetes Clusters (OKE)**
2. Click **Create cluster** (just to see options, don't proceed)
3. Note the available Kubernetes versions shown in the dropdown
4. Use one of those in the ORM form (default `v1.29.1` may need updating)

Or via OCI CLI:
```bash
oci ce cluster-options get --cluster-option-id all --region your-region | grep kubernetesVersions
```

---

## Step 1 — Build the ORM Zip Bundle

```bash
cd /path/to/claude_test/orm
./create_bundle.sh
```

This creates `../fileservice-orm.zip` (~5–10 MB). The zip contains:
- All Terraform infrastructure code
- Shell automation scripts
- OCI DevOps build specs (for backend Docker build + frontend Angular build)
- Helm chart for OKE deployment
- Full application source code (backend + frontend)

---

## Step 2 — Create the ORM Stack

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Navigate to: **Developer Services → Resource Manager → Stacks**
3. Click **Create Stack**
4. Under **Stack Configuration**, select **`.Zip file`**
5. Upload `fileservice-orm.zip`
6. ORM will display the form based on `schema.yaml` — fill in the fields:

| Field | Where to find it | Example |
|-------|-----------------|---------|
| **Compartment** | Dropdown — select your compartment | `MyCompartment` |
| **Region** | Dropdown — select your OCI region | `ap-singapore-1` |
| **OCI Auth Token** | From Prerequisite step 2 | `xxxxxxxxxxxxxxxxxxxx` |
| **DevOps Git Username** | From Prerequisite step 3 | `myns/oracleidentitycloudservice/john@company.com` |
| **SSH Public Key for OKE Nodes** | From Prerequisite step 4 | `ssh-rsa AAAA...` |
| **Kubernetes Version** | From Prerequisite step 5 | `v1.29.1` |
| **Worker Node Shape** | Choose from dropdown | `VM.Standard.E4.Flex` |
| **OCPUs per Node** | Leave default or adjust | `2` |
| **Memory per Node (GB)** | Leave default or adjust | `16` |
| **Number of Worker Nodes** | Leave default or adjust | `2` |
| **Application Name** | Lowercase prefix for resource names | `fileservice` |
| **Docker Image Tag** | Tag for built images | `latest` |

7. Click **Next**
8. Review the variable summary
9. Click **Next**
10. Under **Advanced options**, optionally enable **Run apply** on create
11. Click **Create**

---

## Step 3 — Apply the Stack

1. On the stack detail page, click **Terraform Actions → Apply**
2. Click **Apply** in the confirmation dialog
3. The apply job starts. Click **Logs** (bottom of page) to follow progress in real time

**What happens during apply (in order):**

| Phase | Duration | What's happening |
|-------|----------|-----------------|
| Infrastructure | 5–8 min | VCN, subnets, OCIR repos, Object Storage, API Gateway, IAM policies, DevOps project created |
| OKE Cluster | 8–15 min | Kubernetes control plane provisioned |
| Source upload | 1–2 min | App source code zipped and uploaded to Object Storage by Terraform |
| Build specs push | 1 min | Build spec YAML files pushed to DevOps Code Repository via git |
| OKE Node Pool | 5–10 min | Worker nodes provisioned and join the cluster |
| Backend build | 5–10 min | DevOps pipeline: Maven builds JAR, Docker builds image, pushes to OCIR |
| Frontend build | 5–10 min | DevOps pipeline: npm ci, ng build, uploads static files to Object Storage |
| Helm deploy | 2–3 min | Spring Boot deployed to OKE with LoadBalancer service |
| LoadBalancer | 2–5 min | OCI creates Load Balancer for backend service |
| API Gateway | 1–2 min | API Gateway deployment created with backend routes |

4. When apply completes, scroll down to **Outputs** to see the URLs

---

## Step 4 — Verify the Deployment

Copy the output URLs from the ORM stack **Outputs** tab:

```bash
# 1. Check backend health via API Gateway
curl https://YOUR_GATEWAY.apigateway.REGION.oci.customer-oci.com/v1/actuator/health
# Expected: {"status":"UP",...}

# 2. Upload a test file
curl -X POST https://YOUR_GATEWAY.apigateway.REGION.oci.customer-oci.com/v1/files/upload \
  -F "file=@/tmp/test.txt"
# Expected: {"id":1,"filename":"test.txt","contentType":"text/plain"}

# 3. List files
curl https://YOUR_GATEWAY.apigateway.REGION.oci.customer-oci.com/v1/files

# 4. Open frontend in browser
open https://objectstorage.REGION.oraclecloud.com/n/NAMESPACE/b/BUCKET_NAME/o/index.html
```

All output values are also printed at the end of the ORM apply log.

---

## Post-Deployment

### Updating the application

When you modify the application code:

```bash
# 1. Rebuild the bundle
cd orm && ./create_bundle.sh

# 2. In OCI Console: Stack → Edit Stack → upload new zip → Save

# 3. Run Apply again — Terraform detects changed source hash
#    and re-triggers only the DevOps build pipelines + Helm upgrade
```

### Accessing the Kubernetes cluster locally

```bash
# Install OCI CLI locally, then:
oci ce cluster create-kubeconfig \
  --cluster-id <oke_cluster_id from Outputs> \
  --region <your-region> \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

kubectl get pods
kubectl get services
kubectl logs -l app.kubernetes.io/name=fullstack-app-backend -f
```

### Scaling the backend

```bash
kubectl scale deployment <release>-fullstack-app-backend --replicas=3
# or update the Helm values:
helm upgrade <release> ./orm/helm/fullstack-app \
  --set backend.replicaCount=3 \
  --reuse-values
```

### Viewing build logs

OCI Console → **Developer Services → DevOps → Projects → your-project → Build History**

Click any build run to see detailed logs for each step.

---

## Cleanup / Destroy

To delete all resources:

1. OCI Console → **Developer Services → Resource Manager → Stacks**
2. Select your stack
3. **Terraform Actions → Destroy**
4. Click **Destroy** in the confirmation dialog

**Important notes about destroy:**
- The OKE PersistentVolumeClaim (HSQLDB data) is **not** automatically deleted by Helm. To delete it: `kubectl delete pvc -l app.kubernetes.io/instance=<release_name>` before destroying the stack.
- Object Storage buckets containing objects may fail to delete — manually empty them first via OCI Console → Storage → Object Storage → your bucket → Delete All.
- OCIR repositories with images may need to be emptied first via: OCI Console → Developer Services → Container Registry → your repo → Delete All.

---

## Troubleshooting

### Apply fails at IAM policy creation

**Symptom:** `Error: 409-Conflict` or `403-NotAuthorized` when creating dynamic groups or policies.

**Cause:** The user running the ORM stack doesn't have tenancy-admin IAM permissions.

**Fix:** Ask your tenancy administrator to:
1. Add you to a group with `manage dynamic-groups in tenancy` and `manage policies in tenancy` permissions, OR
2. Run the stack themselves, OR
3. Pre-create the dynamic groups and policies listed in `orm/terraform/iam.tf` and remove `iam.tf` from the zip before uploading.

---

### Build pipeline fails: "docker login failed"

**Symptom:** Backend or frontend build pipeline fails at the Docker login step.

**Cause:** Incorrect `devops_git_username` format or expired/wrong auth token.

**Fix:**
1. Verify the auth token hasn't expired (OCI Console → My Profile → Auth Tokens)
2. Check the username format — for IDCS users it must include `oracleidentitycloudservice/`
3. Edit the ORM stack variables to correct them, then re-apply

---

### Build pipeline fails: "object not found in Object Storage"

**Symptom:** Build pipeline fails when downloading `app_source.zip`.

**Cause:** The IAM policy for DevOps build runners to read Object Storage was not yet active when the pipeline ran (IAM policies can take up to 1–2 minutes to propagate).

**Fix:** Re-trigger the build pipeline from OCI Console → DevOps → Build Pipelines → Run.

---

### kubectl / helm not found on ORM runner

**Symptom:** `null_resource.configure_kubectl` fails with `kubectl: command not found`.

**Cause:** The ORM executor image may not include kubectl/helm.

**Fix:** The `setup_kubeconfig.sh` script auto-installs kubectl and helm if missing. If it fails to download (no internet from executor), contact OCI Support to confirm the executor has outbound internet access.

---

### LoadBalancer IP never assigned

**Symptom:** `create_api_gw_deployment.sh` times out waiting for LoadBalancer IP.

**Cause:** Usually a security list issue — the public subnet security list must allow port 80/443 ingress.

**Fix:** Check the public subnet security list in OCI Console → Networking → Virtual Cloud Networks → your VCN → Subnets → public → Security Lists. Ensure port 80, 443, and 10256 are open from `0.0.0.0/0`.

---

### Frontend shows "Upload failed" or no files load

**Symptom:** The Angular UI loads but API calls fail (CORS error in browser console).

**Cause:** CORS is not configured to allow the Object Storage origin.

**Fix:** In the API Gateway deployment, update the CORS `allowedOrigins` to include the exact Object Storage URL of the frontend bucket. You can do this via: OCI Console → Developer Services → API Management → Gateways → your gateway → Deployments → Edit → CORS settings.

---

## Architecture Diagram

```
Browser
  │
  ▼
OCI Object Storage (Angular static files: index.html, main.js, styles.css)
  │  (API calls from Angular JavaScript)
  ▼
OCI API Gateway (HTTPS, /v1/*)
  │  CORS: allows Object Storage origin
  │  Routes: /files, /files/upload, /files/download/{id}, /actuator/health
  ▼
OCI Load Balancer (created automatically by OKE for service type: LoadBalancer)
  │
  ▼
OKE Worker Nodes (private subnet)
  │
  ▼
Spring Boot Pod (port 8080, 2 replicas)
  │
  ▼
HSQLDB files on OCI Block Volume (oci-bv, 5Gi PersistentVolumeClaim)

─── Build/CI flow ───────────────────────────────────────────────────

ORM Apply
  │
  ├─► Terraform archives app source → uploads to OCI Object Storage
  │
  ├─► null_resource: git push build specs → OCI DevOps Code Repository
  │
  ├─► null_resource: trigger Backend Build Pipeline (OCI DevOps)
  │     DevOps managed runner: downloads source → docker build → push to OCIR
  │
  ├─► null_resource: trigger Frontend Build Pipeline (OCI DevOps)
  │     DevOps managed runner: downloads source → npm ci → ng build
  │                          → uploads dist/ to Object Storage
  │                          → docker build → push to OCIR
  │
  ├─► null_resource: setup kubectl (OCI CLI → kubeconfig)
  ├─► null_resource: create OCIR pull secret in Kubernetes
  ├─► null_resource: helm upgrade --install (deploys backend to OKE)
  ├─► null_resource: wait for LoadBalancer IP
  └─► null_resource: create API Gateway deployment (routes → LB IP)
```
