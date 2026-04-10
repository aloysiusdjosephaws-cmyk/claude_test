# UDS — Running & Deployment Guide

Two supported deployment targets:
- **Local** — Rancher Desktop + Helm (no cloud account needed)
- **OCI** — OKE + Helm (nginx ingress with OCI Load Balancer and self-signed TLS)

Both targets run the same Helm chart and the same Docker images. The only differences are the image registry, storage class, and TLS on OCI.

---

## Switching Between Local and OCI

All `kubectl` and `helm` commands are run from your **local laptop** — never from a cloud VM. They talk to whichever cluster your kubeconfig is currently pointing to.

Check which cluster you are currently connected to:
```bash
kubectl config current-context
```

Switch between targets:
```bash
# Point kubectl at local Rancher Desktop cluster
kubectl config use-context rancher-desktop

# Point kubectl at OCI OKE (context name from your kubeconfig)
kubectl config use-context <oke-context-name>
```

To see all available contexts:
```bash
kubectl config get-contexts
```

> Always confirm your current context before running `helm upgrade` or `kubectl` commands to avoid accidentally deploying to the wrong environment.

---

## Service Port Reference

| Service | Port |
|---------|------|
| Frontend (Angular + Nginx) | 80 (in-cluster) |
| User Management Service | 8081 |
| Application Management Service | 8082 |
| Document Management Service | 8083 |
| Audit Service | 8084 |

---

## First Login — Creating the Initial Admin User

The database starts empty. Before you can log in you must create a SUPER_USER via the API.

Run this after all pods are running:
- Local: replace `<HOST>` with `localhost`
- OCI: replace `<HOST>` with the OCI LB IP, and `http` with `https`

```bash
curl -X POST http://<HOST>/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Admin@123",
    "firstName": "Super",
    "lastName": "Admin",
    "email": "admin@example.com",
    "role": "SUPER_USER"
  }'
```

Then open the UI, log in as `admin` / `Admin@123`, and create other users from the Super User screen.

> The first user can be created without a JWT token. Once a SUPER_USER exists, all further `/users` calls require a valid JWT.

---

## Local — Rancher Desktop

### Prerequisites

| Tool | How you get it |
|------|----------------|
| Rancher Desktop | Install the Windows app from rancherdesktop.io — provides kubectl, helm, and nerdctl automatically in WSL2 |

**WSL2 users** — set memory before starting Rancher Desktop. Edit `C:\Users\<username>\.wslconfig`:
```ini
[wsl2]
memory=12GB
processors=4
```
Then run `wsl --shutdown` from Windows CMD/PowerShell and reopen your terminal.

### One-Time Setup (first use only)

**In Rancher Desktop (Windows app):**
1. Preferences → Container Engine → select **containerd**
2. Preferences → WSL → enable your Ubuntu distro
3. Restart Rancher Desktop

That's it. Traefik ingress is built into k3s — no ingress controller installation needed.

### Step 1 — Build Images

Build all images directly into the k8s.io containerd namespace so k3s can use them without a registry pull. Run from the project root in your **Ubuntu WSL2 terminal**:

```bash
nerdctl -n k8s.io build --no-cache --build-arg NG_CONFIG=development -t frontend-client:local ./frontend
nerdctl -n k8s.io build --no-cache -t audit-service:local                  ./services/audit-service
nerdctl -n k8s.io build --no-cache -t user-management-service:local        ./services/user-management-service
nerdctl -n k8s.io build --no-cache -t application-management-service:local ./services/application-management-service
nerdctl -n k8s.io build --no-cache -t document-management-service:local    ./services/document-management-service
```

### Step 2 — Deploy with Helm

Generate secrets once and reuse — all 4 services must share the same `JWT_SECRET`:

```bash
JWT_SECRET=$(openssl rand -hex 32)
INTERNAL_API_KEY=$(openssl rand -hex 16)

helm upgrade --install uds ./deploy/helm/uds \
  -f ./deploy/helm/uds/values-local.yaml \
  --set audit.env.JWT_SECRET=$JWT_SECRET \
  --set audit.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set userManagement.env.JWT_SECRET=$JWT_SECRET \
  --set userManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set applicationManagement.env.JWT_SECRET=$JWT_SECRET \
  --set applicationManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set documentManagement.env.JWT_SECRET=$JWT_SECRET \
  --set documentManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY
```

### Step 3 — Access the UI

Open **http://localhost** in your browser. No tunnel needed — Rancher Desktop exposes ingress on localhost directly.

### Useful Commands

```bash
kubectl get pods                          # check all pods are Running
kubectl logs -l app.kubernetes.io/name=uds-frontend --tail=50
kubectl logs -l app.kubernetes.io/name=uds-user-mgmt --tail=50
helm uninstall uds                        # tear down all resources
```

Rancher Desktop cluster lifecycle is managed from the Windows app (quit to stop, reopen to resume). The cluster and all pods persist across restarts.

  ┌──────────────────────────────────┬───────────────────────────────────────────────────────┐
  │             Action               │                        Effect                         │
  ├──────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Quit Rancher Desktop             │ Stops cluster; everything preserved                   │
  ├──────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Open Rancher Desktop             │ Resumes cluster; pods restart automatically           │
  ├──────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Factory Reset (Preferences menu) │ Wipes cluster entirely — full rebuild needed          │
  └──────────────────────────────────┴───────────────────────────────────────────────────────┘
  
### Rebuild After Code Changes

```bash
# Rebuild only the changed image, e.g. frontend:
nerdctl -n k8s.io build --no-cache --build-arg NG_CONFIG=development -t frontend-client:local ./frontend

# Restart the deployment to pick up the new image:
kubectl rollout restart deployment -l app.kubernetes.io/name=uds-frontend
```

---

## OCI — OKE

### Prerequisites

| Tool | Install |
|------|---------|
| terraform | https://developer.hashicorp.com/terraform/install |
| oci cli | https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm |
| kubectl | https://kubernetes.io/docs/tasks/tools |
| helm 3 | https://helm.sh/docs/intro/install |
| docker | https://docs.docker.com/engine/install |

You also need an OCI account with permissions to create: VCN, OKE, OCIR repositories.

### Step 1 — Configure OCI Credentials

```bash
oci setup config    # follow the prompts
```

### Step 2 — Provision OKE

Generate an SSH key for the worker nodes if you don't have one:
```bash
ssh-keygen -t rsa -b 4096   # press Enter for all prompts
cat ~/.ssh/id_rsa.pub        # copy this value into terraform.tfvars
```

```bash
cd deploy/terraform/oke
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in:
- `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`, `region`
- `compartment_ocid` — same as `tenancy_ocid` if using the root compartment
- `ssh_public_key` — paste the output of `cat ~/.ssh/id_rsa.pub`

Recommended node settings (A1.Flex ARM is frequently unavailable — use VM.Standard3.Flex):
```ini
kubernetes_version = "v1.32.1"
node_shape         = "VM.Standard3.Flex"
node_ocpus         = 2
node_memory_gb     = 8
```

> If `kubernetes_version` is rejected, OCI will list the supported versions in the error message — update accordingly.

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

When complete, configure kubectl:
```bash
# Copy the kubeconfig_command from terraform output and run it:
oci ce cluster create-kubeconfig --cluster-id <cluster-id> \
  --file $HOME/.kube/config --region <region> \
  --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT
```

Install the nginx ingress controller. OCI will automatically provision a standard **OCI Load Balancer** (Layer 7) for the ingress service — no special annotation required.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Wait for the OCI Load Balancer to get an external IP (2-3 minutes):
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Wait until EXTERNAL-IP shows a real IP address
```

### Step 3 — Generate TLS Certificate

A self-signed certificate is used for now — browsers will show a "Not secure" warning.
See **Upgrading to a Trusted Certificate** below to replace it with a free Let's Encrypt cert
once you have a domain name. That upgrade requires no image rebuild and no downtime.

```bash
# Generate a self-signed cert valid for 10 years
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=uds-oke/O=UDS"

# Store as a Kubernetes TLS secret
kubectl create secret tls uds-tls --cert=tls.crt --key=tls.key

# tls.key and tls.crt are gitignored — do not commit them
```

### Step 4 — Push Images to OCIR

Authenticate Docker to OCIR:
```bash
# Find your namespace: OCI Console → Profile → Tenancy
# Generate a token: OCI Console → Profile → Auth Tokens → Generate Token
docker login YOUR_REGION.ocir.io \
  -u 'YOUR_NAMESPACE/oracleidentitycloudservice/your@email.com' \
  -p 'YOUR_AUTH_TOKEN'
```

Example:
```bash
docker login us-phoenix-1.ocir.io \
  -u 'abcdefgh1234/you@example.com' \
  -p 'your-auth-token-here'
```

Build and push all images:
```bash
REGION=YOUR_REGION
NS=YOUR_NAMESPACE
TAG=1.0.0

docker build --no-cache --build-arg NG_CONFIG=production \
  -t $REGION.ocir.io/$NS/frontend-client:$TAG ./frontend
docker build --no-cache -t $REGION.ocir.io/$NS/audit-service:$TAG                  ./services/audit-service
docker build --no-cache -t $REGION.ocir.io/$NS/user-management-service:$TAG        ./services/user-management-service
docker build --no-cache -t $REGION.ocir.io/$NS/application-management-service:$TAG ./services/application-management-service
docker build --no-cache -t $REGION.ocir.io/$NS/document-management-service:$TAG    ./services/document-management-service

docker push $REGION.ocir.io/$NS/frontend-client:$TAG
docker push $REGION.ocir.io/$NS/audit-service:$TAG
docker push $REGION.ocir.io/$NS/user-management-service:$TAG
docker push $REGION.ocir.io/$NS/application-management-service:$TAG
docker push $REGION.ocir.io/$NS/document-management-service:$TAG
```

### Step 5 — Create OCIR Pull Secret

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server=YOUR_REGION.ocir.io \
  --docker-username='YOUR_NAMESPACE/oracleidentitycloudservice/your@email.com' \
  --docker-password='YOUR_AUTH_TOKEN'
```

### Step 6 — Deploy with Helm

Update `deploy/helm/uds/values-oci.yaml` — replace `YOUR_REGION`, `YOUR_NAMESPACE`, and `1.0.0` with your actual values, then:

```bash
JWT_SECRET=$(openssl rand -hex 32)
INTERNAL_API_KEY=$(openssl rand -hex 16)
(or)
kubectl get secrets
JWT_SECRET=$(kubectl get secret uds-tls -o jsonpath='{.data.JWT_SECRET}' | base64 -d 2>/dev/null)
INTERNAL_API_KEY=$(kubectl get secret uds-tls -o jsonpath='{.data.INTERNAL_API_KEY}' | base64 -d 2>/dev/null)

helm upgrade --install uds ./deploy/helm/uds \
  -f ./deploy/helm/uds/values-oci.yaml \
  --set audit.env.JWT_SECRET=$JWT_SECRET \
  --set audit.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set userManagement.env.JWT_SECRET=$JWT_SECRET \
  --set userManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set applicationManagement.env.JWT_SECRET=$JWT_SECRET \
  --set applicationManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY \
  --set documentManagement.env.JWT_SECRET=$JWT_SECRET \
  --set documentManagement.env.INTERNAL_API_KEY=$INTERNAL_API_KEY
```

### Step 7 — Access the App

```
kubectl get svc -n ingress-nginx ingress-nginx-controller
https://<lb-external-ip>
```

Accept the browser certificate warning (self-signed cert — see Step 3). The OCI Load Balancer forwards traffic to nginx ingress, which handles everything over HTTPS:
- `https://ip/` → Angular SPA (JS/CSS cached in browser for 1 year)
- `https://ip/api/*` → proxied to backend microservices (ClusterIP, not internet-accessible)

### Upgrading to a Trusted Certificate

When you have a domain name, upgrading to a free Let's Encrypt certificate is a three-step change — no downtime, no image rebuild:

```bash
# 1. Point an A record at your domain → OCI LB IP

# 2. Install cert-manager
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# 3. Create a Let's Encrypt ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

Then update `deploy/helm/uds/values-oci.yaml` — add to `frontend.ingress.annotations`:
```yaml
cert-manager.io/cluster-issuer: letsencrypt
```
And set `frontend.ingress.host` to your domain. Run `helm upgrade` — cert-manager issues and auto-renews the cert, nginx reloads it automatically.

### Upgrade After Code Changes

```bash
REGION=us-phoenix-1
NS=YOUR_NAMESPACE
TAG=1.0.1   # bump the tag

# Rebuild and push the changed image(s) — always NG_CONFIG=production for frontend:
docker build --no-cache --build-arg NG_CONFIG=production \
  -t $REGION.ocir.io/$NS/frontend-client:$TAG ./frontend
docker push $REGION.ocir.io/$NS/frontend-client:$TAG

# Update the tag in values-oci.yaml, then:
kubectl rollout restart deployment -l app.kubernetes.io/name=uds-frontend
```

Or bump the image tag in `values-oci.yaml` and run `helm upgrade` again.

### Tear Down

```bash
helm uninstall uds
kubectl delete namespace ingress-nginx

# Delete PVCs (block volumes) — not removed by helm uninstall:
kubectl get pvc
kubectl delete pvc --all

cd deploy/terraform/oke
terraform destroy
```

---

## Common Problems

**Pods stuck in `Pending`**
```bash
kubectl describe pod <pod-name>
```
Usually a storage class mismatch. Local needs `local-path`, OKE needs `oci-bv`. Check your values file.

**`ImagePullBackOff` (local)**

With containerd + `pullPolicy: Never`, this means the image wasn't built into the k8s.io namespace. Rebuild:
```bash
nerdctl -n k8s.io build --no-cache -t <service>:local ./services/<service>
kubectl rollout restart deployment -l app.kubernetes.io/name=uds-<service>
```

Verify the image exists in the k8s.io namespace:
```bash
nerdctl -n k8s.io images | grep local
```

**`ImagePullBackOff` (OCI)**

Check the OCIR pull secret exists and the image path in `values-oci.yaml` is correct:
```bash
kubectl describe pod <pod-name>
kubectl get secret ocir-secret
```

**Services not responding after deploy**

Check pods are all `Running` and `Ready`:
```bash
kubectl get pods
kubectl logs <pod-name>
```

**JWT errors / login fails**

The 4 services have different `JWT_SECRET` values — this happens if you ran `openssl rand` separately for each `--set`. Generate once and reuse (see deployment commands above).

**Browser certificate warning (OCI)**

Expected with a self-signed certificate. Click "Advanced" → "Proceed" to access the app. To permanently remove the warning, import `tls.crt` into your OS or browser trust store, or upgrade to a Let's Encrypt certificate (see above).

**Login endpoint brute-force protection**

For a public-facing deployment, add rate limiting to `frontend/nginx.conf`:
```nginx
# Add in the http block (outside server):
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Add inside the /api/auth location:
limit_req zone=login burst=3 nodelay;
```
Then rebuild and push the frontend image.


APPENDIX:
Cost Estimate:
● Good — 4 PVCs: 3 × 1GB + 1 × 5GB = 8GB total. Very cheap.

  ---
  Cost Estimate

  Node pool = 0 (paused):

  ┌──────────────────────────────────────────────────────────┬──────────────┐
  │                         Resource                         │     Cost     │
  ├──────────────────────────────────────────────────────────┼──────────────┤
  │ OKE control plane                                        │ Free         │
  ├──────────────────────────────────────────────────────────┼──────────────┤
  │ 4 block volumes (8GB total)                              │ ~$0.20/month │
  ├──────────────────────────────────────────────────────────┼──────────────┤
  │ OCI Load Balancer (stays running; delete with helm stop) │ ~$4.38/month │
  ├──────────────────────────────────────────────────────────┼──────────────┤
  │ Total paused                                             │ ~$5/month    │
  └──────────────────────────────────────────────────────────┴──────────────┘

  Node pool = 1 (running, VM.Standard3.Flex 2OCPU/8GB):

  ┌────────────────────────┬──────────────┐
  │        Resource        │     Cost     │
  ├────────────────────────┼──────────────┤
  │ Compute (2 OCPU + 8GB) │ ~$44/month   │
  ├────────────────────────┼──────────────┤
  │ OCI Load Balancer      │ ~$4.38/month │
  ├────────────────────────┼──────────────┤
  │ Block volumes          │ ~$0.20/month │
  ├────────────────────────┼──────────────┤
  │ Total running          │ ~$49/month   │
  └────────────────────────┴──────────────┘

  So if you run it 5 days/month and have it off the rest: ~$5 + (5/30 × $44) ≈ ~$12/month.

  ---
  Console Steps

  To pause (node pool → 0)

  1. OCI Console → Kubernetes Clusters (OKE)
  2. Click your cluster → Node Pools tab
  3. Click your node pool → Edit
  4. Change Number of nodes from 1 to 0
  5. Click Save changes

  Wait ~2 minutes. All pods stop, compute billing stops. Your data (PVCs) is safe.

  To resume (node pool → 1)

  1. Same path: OCI Console → OKE → cluster → Node Pools → Edit
  2. Change Number of nodes from 0 to 1
  3. Click Save changes

  Wait ~3-4 minutes for node to become Ready, then all pods restart automatically (Kubernetes reschedules them). App
  will be accessible at the same LB IP as before.

  ▎ Note: The OCI LB IP stays the same as long as you don't delete the ingress-nginx helm release.