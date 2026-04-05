# Running the Application Manager

Two supported modes: **Local** and **Docker Compose**.

---

## Prerequisites

### For Local Development
| Tool | Version | How to install | Check |
|------|---------|----------------|-------|
| Java JDK | 17+ | https://adoptium.net | `java -version` |
| Maven | 3.8+ | https://maven.apache.org/download.cgi | `mvn -version` |
| Node.js | 18+ | https://nodejs.org | `node -v` |
| npm | 9+ | Included with Node.js | `npm -v` |
| Angular CLI | 19 | `npm install -g @angular/cli` | `ng version` |

### For Docker
| Tool | Version | How to install |
|------|---------|----------------|
| Docker Desktop | 24+ | https://www.docker.com/products/docker-desktop |

Docker Desktop includes both Docker and Docker Compose v2.

---

## Running Locally

All 5 processes run directly on your machine. Works from any terminal:
**Windows Terminal, PowerShell, Command Prompt, Git Bash, VS Code terminal, macOS Terminal, Linux bash — all work the same way.**

HSQLDB database files are stored in your home directory under `.appmanager/`.

---

### Step 1 — One-time setup (first time only)

**Install frontend dependencies:**

*Windows (Command Prompt / PowerShell / Windows Terminal)*
```cmd
cd frontend
npm install
cd ..
```

*macOS / Linux*
```bash
cd frontend
npm install
cd ..
```

---

### Step 2 — Open 5 terminal windows/tabs

You need one terminal per service. Open them however you prefer:
- Windows Terminal: new tabs with `Ctrl+Shift+T`
- PowerShell: open 5 separate windows
- VS Code: open integrated terminals with `` Ctrl+Shift+` `` and split with the split icon

All commands below assume your working directory starts at the **project root** (the folder containing `docker-compose.yml`).

---

### Step 3 — Start services in order

**⚠ Start each service and wait for the "Started" message before opening the next terminal.**

---

**Terminal 1 — Audit Service** *(start this first)*

*Windows*
```cmd
cd services\audit-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

*macOS / Linux*
```bash
cd services/audit-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for:
```
Started AuditApplication in X.XXX seconds
```

---

**Terminal 2 — User Management Service**

*Windows*
```cmd
cd services\user-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

*macOS / Linux*
```bash
cd services/user-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for:
```
Started UserManagementApplication in X.XXX seconds
```

---

**Terminal 3 — Application Management Service**

*Windows*
```cmd
cd services\application-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

*macOS / Linux*
```bash
cd services/application-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for:
```
Started ApplicationManagementApplication in X.XXX seconds
```

---

**Terminal 4 — Document Management Service**

*Windows*
```cmd
cd services\document-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

*macOS / Linux*
```bash
cd services/document-management-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for:
```
Started DocumentManagementApplication in X.XXX seconds
```

---

**Terminal 5 — Angular Frontend**

*Windows*
```cmd
cd frontend
npm start
```

*macOS / Linux*
```bash
cd frontend
npm start
```

Wait for:
```
compiled successfully
```

---

### Step 4 — Open the app

Go to **http://localhost:4200** in your browser.
The browser may open automatically.

---

### Verify all services are running

Open these URLs in your browser — each should show `{"status":"UP"}`:

```
http://localhost:8084/actuator/health   ← Audit Service
http://localhost:8081/actuator/health   ← User Management
http://localhost:8082/actuator/health   ← Application Management
http://localhost:8083/actuator/health   ← Document Management
http://localhost:4200                   ← Angular UI
```

---

### Stopping local services

Press **Ctrl+C** in each of the 5 terminals. HSQLDB shuts down cleanly on Ctrl+C.

---

### Where local data is stored

Database files are written to your home directory:

*Windows*
```
C:\Users\<YourName>\.appmanager\auditdb.*
C:\Users\<YourName>\.appmanager\userdb.*
C:\Users\<YourName>\.appmanager\appdb.*
C:\Users\<YourName>\.appmanager\docdb.*
```

*macOS / Linux*
```
~/.appmanager/auditdb.*
~/.appmanager/userdb.*
~/.appmanager/appdb.*
~/.appmanager/docdb.*
```

Delete these files to reset all data to a blank state.

---

### VS Code shortcuts (optional)

If you are using VS Code, the `.vscode/` folder includes pre-configured shortcuts:

**Run all services with one command:**
```
Ctrl+Shift+P → Tasks: Run Task → Start All Services
```

**Debug with breakpoints:**
```
Run & Debug panel → Debug: All Backend Services → F5
```

---

## Running with Docker Compose

Everything runs inside containers. **Java and Node.js do not need to be installed** on your machine — only Docker Desktop.

---

### Step 1 — Create the secrets file (first time only)

*Windows (Command Prompt)*
```cmd
copy .env.example .env
```

*Windows (PowerShell)*
```powershell
Copy-Item .env.example .env
```

*macOS / Linux*
```bash
cp .env.example .env
```

Open `.env` in any text editor and set your own values:
```
JWT_SECRET=replace-with-a-long-random-string-minimum-32-characters
INTERNAL_API_KEY=replace-with-another-secret-value
```

---

### Step 2 — Build images and start containers

```bash
docker compose up --build -d
```

This builds all 5 Docker images and starts them in the correct dependency order.
**The first build takes several minutes** — Maven downloads all Java dependencies inside the container.

---

### Step 3 — Open the app

**http://localhost:4200**

---

### Check that all containers are healthy

```bash
docker compose ps
```

All 5 services should show `healthy` in the Status column.

---

### View logs

```bash
# Stream all service logs together
docker compose logs -f

# Stream a single service
docker compose logs -f audit-service
docker compose logs -f user-management-service
docker compose logs -f application-management-service
docker compose logs -f document-management-service
docker compose logs -f frontend-client
```

Press Ctrl+C to stop streaming logs (containers keep running).

---

### Stop containers

```bash
# Stop and remove containers — database volumes are kept
docker compose down

# Stop, remove containers AND delete all data (full reset)
docker compose down -v
```

---

### Rebuild after code changes

Only rebuild the service whose code changed — Docker reuses cached layers for everything else, so this is much faster than rebuilding all five.

```bash
# Rebuild and restart a single service
docker compose up --build -d <service-name>

# Rebuild and restart everything
docker compose up --build -d
```

| What you changed | Service name to rebuild |
|-----------------|------------------------|
| `services/audit-service/` | `audit-service` |
| `services/user-management-service/` | `user-management-service` |
| `services/application-management-service/` | `application-management-service` |
| `services/document-management-service/` | `document-management-service` |
| `frontend/` | `frontend-client` |

Verify after rebuild:
```bash
docker compose ps                        # all services should show healthy
docker compose logs -f <service-name>    # watch startup logs
```

---

## First Login — Creating the Initial User

The database starts completely empty. Before you can log in through the UI you must create a Super User via the API.

Run this command from any terminal **after all services are running** (local or Docker — same command either way):

*Windows (PowerShell)*
```powershell
Invoke-RestMethod -Uri "http://localhost:8081/users" -Method POST `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"Admin@123","firstName":"Super","lastName":"Admin","email":"admin@example.com","role":"SUPER_USER"}'
```

*Windows (Command Prompt) — requires curl, included in Windows 10/11*
```cmd
curl -X POST http://localhost:8081/users -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"Admin@123\",\"firstName\":\"Super\",\"lastName\":\"Admin\",\"email\":\"admin@example.com\",\"role\":\"SUPER_USER\"}"
```

*macOS / Linux / Git Bash*
```bash
curl -X POST http://localhost:8081/users \
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

Then go to **http://localhost:4200**, log in with `admin` / `Admin@123`, and use the Super User screen to create other users.

> **Note:** The first user can be created without a token. Once a SUPER_USER exists, all further `/users` calls require a valid JWT.

---

## Service Port Reference

| Service | Port |
|---------|------|
| Angular UI | 4200 |
| User Management Service | 8081 |
| Application Management Service | 8082 |
| Document Management Service | 8083 |
| Audit Service | 8084 |

---

## API Routing

The Angular app always calls `/api/*`. In local dev the Angular proxy (`proxy.conf.json`) forwards these. In Docker, Nginx does the same job.

| Path prefix | Forwarded to |
|-------------|-------------|
| `/api/auth/` | :8081 — User Management |
| `/api/users/` | :8081 — User Management |
| `/api/applications/` | :8082 — Application Management |
| `/api/documents/` | :8083 — Document Management |
| `/api/groups/` | :8083 — Document Management |
| `/api/help/` | :8083 — Document Management |
| `/api/audit/` | :8084 — Audit Service |

---

## Common Problems

**"Port already in use" when starting a service**

Find and stop whatever is using the port:

*Windows*
```cmd
netstat -ano | findstr :8081
taskkill /PID <pid> /F
```

*macOS / Linux*
```bash
lsof -i :8081
kill -9 <pid>
```

If you were previously running Docker, stop those containers first:
```bash
docker compose down
```

---

**Maven downloads everything on first run**

This is normal. Maven caches dependencies in `~/.m2/` after the first download. Subsequent starts are much faster. Ensure you have internet access on first run.

---

**`ng: command not found` or `ng` is not recognized**

```bash
npm install -g @angular/cli
```

On Windows you may need to run PowerShell as Administrator.

---

**`npm start` fails with `node_modules not found`**

```bash
cd frontend
npm install
```

---

**Docker: "Cannot connect to the Docker daemon"**

Docker Desktop is not running. Open Docker Desktop from the Start Menu and wait until the whale icon in the taskbar shows "Docker Desktop is running".

---

**Switching between local and Docker**

You cannot run both at the same time on the same ports. Before switching:
- Stopping local → press Ctrl+C in all 5 terminals
- Stopping Docker → `docker compose down`

---

## Running with Kubernetes (Helm — local cluster)

Use this to test the Helm chart locally before deploying to OCI.

### Prerequisites

| Tool | Check |
|------|-------|
| Docker Desktop (with Kubernetes enabled) **or** kind/Minikube | `kubectl cluster-info` |
| Helm 3 | `helm version` |

---

### Step 1 — Build images into the cluster

**Docker Desktop (Kubernetes enabled):**
```bash
docker build -t audit-service:latest            ./services/audit-service
docker build -t user-management-service:latest  ./services/user-management-service
docker build -t application-management-service:latest ./services/application-management-service
docker build -t document-management-service:latest    ./services/document-management-service
docker build -t frontend-client:latest          ./frontend
```

**kind:**
kind get clusters (app-manager)
```bash
# Build images as above, then load each one:
  kind load docker-image audit-service:latest --name app-manager
  kind load docker-image user-management-service:latest --name app-manager
  kind load docker-image application-management-service:latest --name app-manager
  kind load docker-image document-management-service:latest --name app-manager
  kind load docker-image frontend-client:latest --name app-manager
```

**Minikube:**
```bash
#eval $(minikube docker-env)
# Then build images as above — they are built directly inside Minikube
```

---

### Step 2 — Deploy

kind uses the `standard` storage class (local-path). The `-f values-oci.yaml` override is **not** used here — that is only for OKE.

```bash
set -a && source .env && set +a

helm upgrade --install my-release ./deploy/helm/fullstack-app \
  --set audit.hsqldb.storage.storageClassName=standard \
  --set userManagement.hsqldb.storage.storageClassName=standard \
  --set applicationManagement.hsqldb.storage.storageClassName=standard \
  --set documentManagement.hsqldb.storage.storageClassName=standard \
  --set audit.env.JWT_SECRET="${JWT_SECRET}" \
  --set audit.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set userManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set userManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set applicationManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set applicationManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set documentManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set documentManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}"
```

Watch pods start:
```bash
kubectl get pods -w
```

---

### Step 3 — Access the UI

Open two terminals and run one port-forward in each (both must stay running):

**Terminal A — frontend:**
```bash
kubectl port-forward svc/my-release-fullstack-app-frontend 8080:80
```

**Terminal B — user-management (needed for first login):**
```bash
kubectl port-forward svc/user-management-service 8081:8081
```

Open **http://localhost:8080**, then follow the [First Login](#first-login--creating-the-initial-user) steps using port 8081.

```bash
curl -X POST http://localhost:8081/users \
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

---

### Uninstall

```bash
helm uninstall my-release
kubectl delete pvc -l app.kubernetes.io/instance=my-release
```

---

## Deploying to OCI — Docker Compose

Runs the same Docker Compose setup as local on a free OCI ARM VM (`VM.Standard.A1.Flex` — Always Free). No Kubernetes required.

---

### 1. Using Terraform

Terraform provisions the VM, VCN, subnets, security lists, and internet gateway automatically.

#### Prerequisites

Install Terraform:
```bash
sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

Terraform authenticates to OCI using the API key from `~/.oci/config` (created by `oci setup config`). You need these values for `terraform.tfvars`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...          ← user_ocid
fingerprint=xx:xx:xx:xx:...           ← fingerprint
key_file=~/.oci/oci_api_key.pem       ← private_key_path
tenancy=ocid1.tenancy.oc1..aaaa...    ← tenancy_ocid
region=us-phoenix-1                   ← region
```

Your **compartment_ocid** is found in OCI Console → **Identity → Compartments** → click your compartment → copy the OCID.

Generate an SSH key pair for VM access:
```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub   # paste this into terraform.tfvars as ssh_public_key
```

> **Never commit `terraform.tfvars`** — it contains your OCI credentials. It is already listed in `deploy/terraform/.gitignore`.

#### Step 1 — Provision the VM

```bash
cd deploy/terraform/option-a-vm
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # fill in your values

terraform init
terraform plan -out=tfplan
terraform apply tfplan

terraform output               # shows public IP and SSH command
```

#### Step 2 — Install Docker on the VM

SSH into the VM using the IP from `terraform output`:
```bash
ssh ubuntu@<PUBLIC-IP>
```

Install Docker:
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker ubuntu
newgrp docker
```

Verify:
```bash
docker version
docker compose version
```

#### Step 3 — Configure and start

Copy the project to the VM (from your local machine):
```bash
scp -r /path/to/claude_test ubuntu@<PUBLIC-IP>:~/app-manager
```

Or clone from git:
```bash
git clone <your-repo-url> app-manager
```

Then on the VM:
```bash
cd ~/app-manager
cp .env.example .env
nano .env   # set JWT_SECRET and INTERNAL_API_KEY
docker compose up --build -d
docker compose ps
```

  To confirm it's downloading (not hung):
  # In another SSH session on the VM
  watch -n2 'cat /proc/net/dev | grep -E "ens|eth" | awk "{print \$1, \$2, \$10}"'
  # You should see RX bytes incrementing

  Or simpler:
  docker stats --no-stream
  # Should show CPU/network activity on the build container
  
#### Step 4 — Access the UI

Open **http://\<PUBLIC-IP\>:4200** in your browser.

Then follow the [First Login](#first-login--creating-the-initial-user) steps. Run the curl from inside the VM (no extra firewall rule needed):
```bash
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123","firstName":"Super","lastName":"Admin","email":"admin@example.com","role":"SUPER_USER"}'
```

#### Stopping / starting

```bash
# Stop containers (data volumes preserved)
docker compose down

# Start again
docker compose up -d

# Full reset including data
docker compose down -v
```

#### Destroy

```bash
cd deploy/terraform/option-a-vm
terraform destroy
```

This deletes the VM, VCN, subnets, security list, and internet gateway — everything Terraform created.

---

### 2. Manual

#### Step 1 — Create a Free ARM VM

1. OCI Console → **Compute → Instances → Create Instance**
2. Set the following:

| Field | Value |
|-------|-------|
| Name | `app-manager-vm` |
| Image | Canonical Ubuntu 22.04 |
| Shape | Click **Change Shape** → **Ampere** → `VM.Standard.A1.Flex` |
| OCPUs | `1` |
| Memory | `6 GB` |
| SSH keys | Upload your public key or generate a new pair |

3. Under **Networking**, ensure a **public subnet** is selected and **Assign a public IPv4 address** is checked
4. Click **Create**
5. Wait until the instance shows **Running** — note the **Public IP address**

#### Step 2 — Open Port 4200

By default OCI blocks all inbound traffic. Open port 4200 for the UI:

1. OCI Console → **Networking → Virtual Cloud Networks**
2. Click your VCN → **Subnets** → click the **public subnet**
3. Click the **Security List**
4. Click **Add Ingress Rules** and add:

| Field | Value |
|-------|-------|
| Source CIDR | `0.0.0.0/0` |
| IP Protocol | TCP |
| Destination Port Range | `4200` |

5. Click **Add Ingress Rules**

#### Step 3 — Install Docker on the VM

SSH into the VM:
```bash
ssh ubuntu@<PUBLIC-IP>
```

Install Docker:
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker ubuntu
newgrp docker
```

Verify:
```bash
docker version
docker compose version
```

#### Step 4 — Copy the project to the VM

From your local machine:
```bash
scp -r /path/to/claude_test ubuntu@<PUBLIC-IP>:~/app-manager
```

Or clone from git:
```bash
git clone <your-repo-url> app-manager
```

#### Step 5 — Configure and start

On the VM:
```bash
cd ~/app-manager
cp .env.example .env
nano .env   # set JWT_SECRET and INTERNAL_API_KEY
docker compose up --build -d
docker compose ps
```

#### Step 6 — Access the UI

Open **http://\<PUBLIC-IP\>:4200** in your browser.

Then follow the [First Login](#first-login--creating-the-initial-user) steps. Run the curl from inside the VM:
```bash
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123","firstName":"Super","lastName":"Admin","email":"admin@example.com","role":"SUPER_USER"}'
```

> **Note:** To run the curl from outside the VM, also open port 8081 in the Security List.

#### Stopping / starting

```bash
# Stop containers (data volumes preserved)
docker compose down

# Start again
docker compose up -d

# Full reset including data
docker compose down -v
```

---

### Updating after code changes (both Terraform and Manual)

The process is the same whether the VM was provisioned by Terraform or manually.

#### Step 1 — Get your changes onto the VM

**If using a git repository (recommended):**
```bash
# On your local machine — commit and push
git add .
git commit -m "describe your change"
git push origin main

# SSH into the VM, then pull
ssh ubuntu@<PUBLIC-IP>
cd ~/app-manager
git pull
```

**If not using git — copy only what changed:**
```bash
# From your local machine
scp -r ./services/document-management-service ubuntu@<PUBLIC-IP>:~/app-manager/services/
# or for frontend changes
scp -r ./frontend/src ubuntu@<PUBLIC-IP>:~/app-manager/frontend/
```

#### Step 2 — Rebuild and restart only the changed service

```bash
# On the VM
cd ~/app-manager
docker compose up --build -d <service-name>
```

| What you changed | Service name |
|-----------------|-------------|
| `services/audit-service/` | `audit-service` |
| `services/user-management-service/` | `user-management-service` |
| `services/application-management-service/` | `application-management-service` |
| `services/document-management-service/` | `document-management-service` |
| `frontend/` | `frontend-client` |

Docker reuses the cached dependency layer — only the changed service rebuilds, so this is much faster than the first build.

#### Step 3 — Verify

```bash
docker compose ps                        # all services should show healthy
docker compose logs -f <service-name>    # watch startup logs
```

---

---

## Appendix: Deploying to OCI with OKE + Helm

Runs the Helm chart on Oracle Kubernetes Engine with images stored in OCI Container Registry (OCIR).

> **Note:** OKE worker node VMs are billed by the hour. Use `VM.Standard.A1.Flex` (ARM) nodes to minimise cost. ARM capacity in some regions is limited — if you get "Out of host capacity" errors, try a different Availability Domain or switch to `VM.Standard.E4.Flex` (x86).

### Prerequisites (local machine)

| Tool | Install | Check |
|------|---------|-------|
| Docker | docker.com | `docker version` |
| OCI CLI | `sudo apt install pipx && pipx install oci-cli && pipx ensurepath` then `oci setup config` | `oci --version` |
| kubectl | OCI Console → OKE cluster → Access Cluster | `kubectl cluster-info` |
| Helm 3 | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` | `helm version` |

---

### 1. Using Terraform

#### Prerequisites

Install Terraform:
```bash
sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

Terraform authenticates to OCI using `~/.oci/config`. Values needed for `terraform.tfvars`:

```ini
user_ocid        = ocid1.user.oc1..aaaa...
fingerprint      = xx:xx:xx:xx:...
private_key_path = ~/.oci/oci_api_key.pem
tenancy_ocid     = ocid1.tenancy.oc1..aaaa...
region           = us-phoenix-1
compartment_ocid = ocid1.compartment.oc1..aaaa...
```

> **Never commit `terraform.tfvars`** — it is already listed in `deploy/terraform/.gitignore`.

#### Step 1 — Provision the OKE cluster

```bash
cd deploy/terraform/option-b-oke
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # fill in your values

terraform init
terraform plan -out=tfplan
terraform apply tfplan

terraform output               # shows kubeconfig_command
```

Run the `kubeconfig_command` from the output to connect kubectl to OKE:
```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc1... \
  --file $HOME/.kube/config \
  --region us-phoenix-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

Verify:
```bash
kubectl config current-context
kubectl get nodes
```

#### Step 2 — Get OCI credentials

| Value | Where to find it |
|-------|----------------|
| **Region** | OCI Console top bar (e.g. `us-phoenix-1`) |
| **Tenancy namespace** | OCI Console → **Developer Services → Container Registry** → shown at top |
| **Auth token** | OCI Console → Profile → **My Profile → Auth Tokens → Generate Token** — copy immediately, shown only once |
| **Username** | Federated/IDCS: `<namespace>/oracleidentitycloudservice/your@email.com` · Local IAM: `<namespace>/your_username` |

#### Step 3 — Authenticate Docker to OCIR

```bash
docker login <region>.ocir.io \
  -u <namespace>/<username> \
  -p "<auth-token>"
```

#### Step 4 — Build and push images

Edit `deploy/helm/fullstack-app/values-oci.yaml` — replace `YOUR_REGION`, `YOUR_NAMESPACE`, and `YOUR_TAG` with your actual values.

Then build and push:
```bash
export REGION=us-phoenix-1
export NAMESPACE=mytenancy
export TAG=1.0.0

for SERVICE in audit-service user-management-service application-management-service document-management-service; do
  docker build -t ${REGION}.ocir.io/${NAMESPACE}/${SERVICE}:${TAG} ./services/${SERVICE}
  docker push ${REGION}.ocir.io/${NAMESPACE}/${SERVICE}:${TAG}
done

docker build -t ${REGION}.ocir.io/${NAMESPACE}/frontend-client:${TAG} ./frontend
docker push ${REGION}.ocir.io/${NAMESPACE}/frontend-client:${TAG}
```

#### Step 5 — Create OCIR pull secret in OKE

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server="${REGION}.ocir.io" \
  --docker-username="${NAMESPACE}/oracleidentitycloudservice/your@email.com" \
  --docker-password="<auth-token>"
```

#### Step 6 — Deploy with Helm

```bash
set -a && source .env && set +a

helm upgrade --install my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set audit.env.JWT_SECRET="${JWT_SECRET}" \
  --set audit.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set userManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set userManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set applicationManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set applicationManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set documentManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set documentManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}"
```

Watch pods start:
```bash
kubectl get pods -w
```

If pods stay Pending, verify the storage class:
```bash
kubectl get storageclass
# OKE should show oci-bv — if not, update storageClassName in values-oci.yaml
```

#### Step 7 — Access the UI

```bash
kubectl get svc my-release-fullstack-app-frontend
# Note the EXTERNAL-IP (may take 2-3 minutes to appear)
```

Open **http://\<EXTERNAL-IP\>** in your browser.

For the [First Login](#first-login--creating-the-initial-user), port-forward user-management:
```bash
kubectl port-forward svc/user-management-service 8081:8081
```

Then run the curl to `http://localhost:8081/users`.

#### Upgrade after code changes

Only rebuild and push the image for the service that changed. Use a new tag each time — OKE will not re-pull an image if the tag is unchanged.

```bash
export REGION=us-phoenix-1
export NAMESPACE=mytenancy
export TAG=1.1.0          # increment this each deploy
```

**Step 1 — Rebuild and push only the changed image:**

```bash
# Example: document-management-service changed
docker build -t ${REGION}.ocir.io/${NAMESPACE}/document-management-service:${TAG} \
  ./services/document-management-service
docker push ${REGION}.ocir.io/${NAMESPACE}/document-management-service:${TAG}
```

| What you changed | Image to rebuild |
|-----------------|-----------------|
| `services/audit-service/` | `audit-service` |
| `services/user-management-service/` | `user-management-service` |
| `services/application-management-service/` | `application-management-service` |
| `services/document-management-service/` | `document-management-service` |
| `frontend/` | `frontend-client` |

**Step 2 — Deploy only the changed service:**

```bash
# Example: only document-management-service changed
helm upgrade my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set documentManagement.image.tag=${TAG} \
  --reuse-values
```

`--reuse-values` keeps all other services and settings unchanged — only the updated service is redeployed.

If all services changed, update all tags at once:
```bash
helm upgrade my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set audit.image.tag=${TAG} \
  --set userManagement.image.tag=${TAG} \
  --set applicationManagement.image.tag=${TAG} \
  --set documentManagement.image.tag=${TAG} \
  --set frontend.image.tag=${TAG} \
  --reuse-values
```

**Step 3 — Verify:**

```bash
kubectl rollout status deployment/my-release-fullstack-app-document-management
kubectl logs -f deployment/my-release-fullstack-app-document-management
```

#### Destroy

Helm and Terraform create resources independently — clean up both:

**Step 1 — Remove Helm release and PVCs** (must be done before `terraform destroy`, otherwise block volumes keep the VCN attached and destroy will hang):
```bash
helm uninstall my-release
kubectl delete pvc -l app.kubernetes.io/instance=my-release

# Wait for PVCs to be fully deleted
kubectl get pvc -w
# Press Ctrl+C once all PVCs are gone
```

**Step 2 — Remove OCIR images** (Terraform does not manage these):
- OCI Console → **Developer Services → Container Registry**
- Delete each repository: `audit-service`, `user-management-service`, `application-management-service`, `document-management-service`, `frontend-client`

**Step 3 — Destroy Terraform resources:**
```bash
cd deploy/terraform/option-b-oke
terraform destroy
```

**Step 4 — Remove the OKE kubeconfig context locally:**
```bash
kubectl config get-contexts   # note the OKE context name
kubectl config delete-context <oke-context-name>
kubectl config delete-cluster <oke-cluster-name>
kubectl config delete-user <oke-user-name>
```

---

### 2. Manual

#### Step 1 — Create an OKE Cluster

1. OCI Console → **Developer Services → Kubernetes Clusters (OKE)**
2. Click **Create Cluster → Quick Create**
3. Set the following:

| Field | Value |
|-------|-------|
| Name | `app-manager` |
| Kubernetes version | Latest available |
| Shape | `VM.Standard.A1.Flex` (ARM) |
| OCPUs per node | `1` |
| Memory per node | `6 GB` |
| Node count | `1` |

4. Click **Next → Create Cluster**
5. Wait ~10–15 minutes for status to show **Active**

> If you get "Out of host capacity", try changing the **Availability Domain** (AD-1 → AD-2 → AD-3) in the node pool settings, or switch to `VM.Standard.E4.Flex` (x86).

**Connect kubectl to OKE:**

Once Active, click **Access Cluster** → copy and run the command shown:
```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc1... \
  --file $HOME/.kube/config \
  --region us-phoenix-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

Verify:
```bash
kubectl config current-context
kubectl get nodes
```

#### Step 2 — Get OCI credentials

| Value | Where to find it |
|-------|----------------|
| **Region** | OCI Console top bar (e.g. `us-phoenix-1`) |
| **Tenancy namespace** | OCI Console → **Developer Services → Container Registry** → shown at top |
| **Auth token** | OCI Console → Profile → **My Profile → Auth Tokens → Generate Token** — copy immediately, shown only once |
| **Username** | Federated/IDCS: `<namespace>/oracleidentitycloudservice/your@email.com` · Local IAM: `<namespace>/your_username` |

#### Step 3 — Authenticate Docker to OCIR

```bash
docker login <region>.ocir.io \
  -u <namespace>/<username> \
  -p "<auth-token>"
```

#### Step 4 — Build and push images

Edit `deploy/helm/fullstack-app/values-oci.yaml` — replace `YOUR_REGION`, `YOUR_NAMESPACE`, and `YOUR_TAG` with your actual values.

Then build and push:
```bash
export REGION=us-phoenix-1
export NAMESPACE=mytenancy
export TAG=1.0.0

for SERVICE in audit-service user-management-service application-management-service document-management-service; do
  docker build -t ${REGION}.ocir.io/${NAMESPACE}/${SERVICE}:${TAG} ./services/${SERVICE}
  docker push ${REGION}.ocir.io/${NAMESPACE}/${SERVICE}:${TAG}
done

docker build -t ${REGION}.ocir.io/${NAMESPACE}/frontend-client:${TAG} ./frontend
docker push ${REGION}.ocir.io/${NAMESPACE}/frontend-client:${TAG}
```

#### Step 5 — Create OCIR pull secret in OKE

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server="${REGION}.ocir.io" \
  --docker-username="${NAMESPACE}/oracleidentitycloudservice/your@email.com" \
  --docker-password="<auth-token>"
```

#### Step 6 — Deploy with Helm

```bash
set -a && source .env && set +a

helm upgrade --install my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set audit.env.JWT_SECRET="${JWT_SECRET}" \
  --set audit.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set userManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set userManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set applicationManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set applicationManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  --set documentManagement.env.JWT_SECRET="${JWT_SECRET}" \
  --set documentManagement.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}"
```

Watch pods start:
```bash
kubectl get pods -w
```

If pods stay Pending, verify the storage class:
```bash
kubectl get storageclass
# OKE should show oci-bv — if not, update storageClassName in values-oci.yaml
```

#### Step 7 — Access the UI

```bash
kubectl get svc my-release-fullstack-app-frontend
# Note the EXTERNAL-IP (may take 2-3 minutes to appear)
```

Open **http://\<EXTERNAL-IP\>** in your browser.

For the [First Login](#first-login--creating-the-initial-user), port-forward user-management:
```bash
kubectl port-forward svc/user-management-service 8081:8081
```

Then run the curl to `http://localhost:8081/users`.

#### Upgrade after code changes

Only rebuild and push the image for the service that changed. Use a new tag each time — OKE will not re-pull an image if the tag is unchanged.

```bash
export REGION=us-phoenix-1
export NAMESPACE=mytenancy
export TAG=1.1.0          # increment this each deploy
```

**Step 1 — Rebuild and push only the changed image:**

```bash
# Example: document-management-service changed
docker build -t ${REGION}.ocir.io/${NAMESPACE}/document-management-service:${TAG} \
  ./services/document-management-service
docker push ${REGION}.ocir.io/${NAMESPACE}/document-management-service:${TAG}
```

| What you changed | Image to rebuild |
|-----------------|-----------------|
| `services/audit-service/` | `audit-service` |
| `services/user-management-service/` | `user-management-service` |
| `services/application-management-service/` | `application-management-service` |
| `services/document-management-service/` | `document-management-service` |
| `frontend/` | `frontend-client` |

**Step 2 — Deploy only the changed service:**

```bash
# Example: only document-management-service changed
helm upgrade my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set documentManagement.image.tag=${TAG} \
  --reuse-values
```

`--reuse-values` keeps all other services and settings unchanged — only the updated service is redeployed.

If all services changed, update all tags at once:
```bash
helm upgrade my-release ./deploy/helm/fullstack-app \
  -f ./deploy/helm/fullstack-app/values-oci.yaml \
  --set audit.image.tag=${TAG} \
  --set userManagement.image.tag=${TAG} \
  --set applicationManagement.image.tag=${TAG} \
  --set documentManagement.image.tag=${TAG} \
  --set frontend.image.tag=${TAG} \
  --reuse-values
```

**Step 3 — Verify:**

```bash
kubectl rollout status deployment/my-release-fullstack-app-document-management
kubectl logs -f deployment/my-release-fullstack-app-document-management
```

#### Destroy

**Step 1 — Remove Helm release and PVCs:**
```bash
helm uninstall my-release
kubectl delete pvc -l app.kubernetes.io/instance=my-release

kubectl get pvc -w
# Press Ctrl+C once all PVCs are gone
```

**Step 2 — Remove OCIR images:**
- OCI Console → **Developer Services → Container Registry**
- Delete each repository: `audit-service`, `user-management-service`, `application-management-service`, `document-management-service`, `frontend-client`

**Step 3 — Delete the OKE cluster and node pool:**
- OCI Console → **Developer Services → Kubernetes Clusters (OKE)**
- Click your cluster → **Delete**

**Step 4 — Delete remaining OCI resources:**
- **Block Volumes:** OCI Console → Storage → Block Storage → Block Volumes → delete any volumes from the cluster
- **Load Balancer:** OCI Console → Networking → Load Balancers → delete the load balancer created for the frontend service
- **VCN:** OCI Console → Networking → Virtual Cloud Networks → delete the VCN (only after cluster is fully deleted)

**Step 5 — Remove the OKE kubeconfig context locally:**
```bash
kubectl config get-contexts   # note the OKE context name
kubectl config delete-context <oke-context-name>
kubectl config delete-cluster <oke-cluster-name>
kubectl config delete-user <oke-user-name>
```