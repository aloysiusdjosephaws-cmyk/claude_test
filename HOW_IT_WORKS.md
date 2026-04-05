# How It All Works — A Beginner's Guide

This document explains how the Application Manager works end-to-end, in plain language. No prior knowledge of containers, cloud, or security is assumed.

---

## Part 1 — The Big Picture

The Application Manager is a web application made up of several programs that talk to each other. Instead of being one giant program, it is split into smaller programs called **services**, each responsible for one job:

| Service | Job |
|---------|-----|
| **User Management** | Handles login and manages user accounts |
| **Application Management** | Manages applications and who can access them |
| **Document Management** | Handles file upload, download, and search |
| **Audit** | Records a log of every important action taken |
| **Frontend** | The web page you see in your browser |

The reason for splitting things up this way is maintainability — if the document upload feature breaks, the login system keeps working. Each service can also be updated independently.

---

## Part 2 — What Is a Container?

### The problem containers solve

Imagine you write a Java program on your laptop. It works perfectly. You copy it to a colleague's laptop — it crashes, because they have a different version of Java installed. You move it to a server — it crashes again, because the server is missing a library your program depends on.

This is the classic "works on my machine" problem.

### What a container is

A **container** is a self-contained package that includes your program *and* everything it needs to run — the right version of Java, the right libraries, the right configuration — bundled together in a single unit.

Think of it like a shipping container. A shipping container holds goods in a standardised box. It doesn't matter whether it goes on a ship, a truck, or a train — the box fits the same way everywhere and its contents are protected.

A software container works the same way. It runs identically on your laptop, your colleague's laptop, or a server in a data centre.

### Docker

**Docker** is the tool that creates and runs containers. When you run `docker compose up`, Docker:

1. Reads a description of what each container should look like (called a `Dockerfile`)
2. Builds a container image — a snapshot of the program and everything it needs
3. Starts each container as a running instance of that image

### Docker Compose

Running five separate containers by hand would be tedious. **Docker Compose** lets you describe all five services in one file (`docker-compose.yml`) and start them all with a single command. It also handles:

- Starting services in the right order (audit service starts before the others need to send it events)
- Giving containers a private network so they can talk to each other by name (e.g. `audit-service:8084`)
- Mounting **volumes** — persistent storage that survives container restarts (your database files)

### What a volume is

By default, when a container stops, any files it created are gone. A **volume** is a folder on your real machine that is shared into the container. When the document management service writes a database file to `/data/docdb` inside its container, that file actually lives on your machine's disk and survives restarts.

---

## Part 3 — How the Services Connect

Here is a map of how the five services are connected:

```
Browser
   │
   ▼
┌─────────────────────────────────────────────────┐
│              frontend-client (port 4200)         │
│   Angular web app + Nginx reverse proxy          │
└───┬─────────┬──────────┬────────────┬────────────┘
    │         │          │            │
    ▼         ▼          ▼            ▼
 :8081      :8082      :8083        :8084
 User       App        Document     Audit
 Mgmt       Mgmt       Mgmt         Service
    │         │          │
    └────────►└─────────►└──────────► Audit Service
              (all three send audit events to :8084)
```

### What Nginx does

The browser only ever talks to one address: `http://localhost:4200`. It never directly calls port 8081, 8082, or 8083. **Nginx** (a web server running inside the frontend container) acts as a **reverse proxy** — it receives all requests from the browser and forwards them to the right backend service based on the URL path:

| URL the browser requests | Nginx forwards to |
|--------------------------|-------------------|
| `/api/auth/login` | User Management :8081 |
| `/api/users/...` | User Management :8081 |
| `/api/applications/...` | Application Management :8082 |
| `/api/documents/...` | Document Management :8083 |
| `/api/audit/...` | Audit Service :8084 |

The browser thinks it is talking to one server. In reality, Nginx is routing traffic to whichever service is responsible.

This design means:
- The backend services are never exposed directly to the internet (only Nginx's port is open)
- You can change which port a backend service runs on without changing anything in the browser

---

## Part 4 — Security: Keys and Tokens Explained

Security in this application uses three different mechanisms, each solving a different problem.

---

### 4.1 — Passwords and Login (JWT Tokens)

#### How login works

When you type your username and password and click Login, the browser sends those credentials to the User Management service. The service checks the database — if the credentials are correct, it does *not* send back "OK, you're logged in". Instead it sends back a small piece of text called a **JWT** (JSON Web Token).

A JWT looks like this:
```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJTVVBFUl9VU0VSIn0.abc123xyz
```

It is three Base64-encoded sections separated by dots:
1. **Header** — describes the token type and signing algorithm
2. **Payload** — contains data like your username and role (e.g. `SUPER_USER`)
3. **Signature** — a cryptographic seal that proves the token hasn't been tampered with

#### Why not just use a session?

Traditional web apps store a "session" on the server — a record saying "user X is logged in". Every request the browser makes, the server looks up the session. This works but requires the server to remember everyone's sessions.

A JWT is different — it is **stateless**. The server doesn't store anything. Instead, the token itself carries the proof. When the browser sends a JWT with a request, any service can verify it independently, without asking the user management service.

#### The JWT_SECRET

The signature on a JWT is created using a secret key — the `JWT_SECRET` you set in the `.env` file. Think of it as a password that only your servers know.

When the User Management service creates a JWT, it signs it using the secret. When any other service receives a JWT from the browser, it can verify the signature using the same secret. If the signature is valid, the token is genuine. If someone tries to create a fake JWT or tamper with the payload (e.g. changing their role to `SUPER_USER`), the signature won't match and the request is rejected.

**This is why all four backend services share the same `JWT_SECRET`** — so any of them can independently verify a token the user obtained from the login service.

#### How the browser uses the JWT

After login, the Angular app stores the JWT and attaches it to every subsequent API request in a header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

The backend reads this header, verifies the signature, reads the role from the payload, and decides what the user is allowed to do — all without touching a database.

---

### 4.2 — Service-to-Service Communication (INTERNAL_API_KEY)

The audit service records every important action. But only the other three backend services should be allowed to send audit events — not random internet users.

JWT tokens don't work here because there is no "logged-in user" when one service calls another. Instead, the calling service includes a secret header with every request:

```
X-Internal-Key: <INTERNAL_API_KEY>
```

The audit service checks this header. If it matches the configured key, the request is accepted. If not, it is rejected.

This `INTERNAL_API_KEY` is set in your `.env` file and passed to all containers via Docker Compose. It never leaves your server — browsers never see it.

---

### 4.3 — SSH Keys (Accessing the Cloud VM)

When you deploy to OCI, you provision a virtual machine in the cloud. You need a way to connect to that machine remotely to install software and run commands. This is done using **SSH** (Secure Shell).

SSH uses **asymmetric cryptography** — a pair of mathematically linked keys:

- **Private key** — stays on your laptop. Never shared with anyone.
- **Public key** — placed on the cloud VM. Can be shared freely.

When you connect with `ssh ubuntu@<PUBLIC-IP>`, your SSH client uses your private key to prove your identity. The VM checks the proof against the public key it has stored. If they match, you are let in — no password required.

Why is this more secure than a password?
- A private key is much longer and more complex than any password
- It cannot be guessed or brute-forced
- Even if someone intercepts the communication, they cannot derive your private key from the public key

To generate a key pair:
```bash
ssh-keygen -t ed25519
# Creates: ~/.ssh/id_ed25519 (private) and ~/.ssh/id_ed25519.pub (public)
```

You give the **public key** to OCI when creating the VM. You keep the **private key** on your machine.

> **If using Terraform:** Instead of pasting your public key into the OCI Console, you put it in `terraform.tfvars` as the `ssh_public_key` value. Terraform provisions the VM with that key automatically — no manual steps in the console.

---

### 4.4 — OCI API Key (Terraform and OCI CLI)

Whether you deploy with Docker Compose or Kubernetes, if you use Terraform to provision OCI infrastructure you need an **OCI API key**. This is a separate key from your SSH key and serves a completely different purpose.

#### What it is for

Terraform needs to call OCI's APIs to create resources — VMs, networks, Kubernetes clusters, etc. It authenticates those API calls using the OCI API key. Without it, Terraform has no way to prove to OCI that it is acting on your behalf.

The OCI CLI (used for managing OKE with `kubectl`) uses the same key for the same reason.

#### How it is created

Unlike SSH keys (which you generate locally), the OCI API key is **created in the OCI Console**:

1. OCI Console → Profile (top right) → My Profile → API Keys → Add API Key
2. Choose **Generate API Key Pair**
3. Download the **private key** — save it to `~/.oci/oci_api_key.pem`
4. OCI shows you a config snippet — paste it into `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=xx:xx:xx:xx:...
tenancy=ocid1.tenancy.oc1..aaaa...
region=us-phoenix-1
key_file=~/.oci/oci_api_key.pem
```

The **public key** stays registered in the OCI Console. The **private key** lives on your machine at `~/.oci/oci_api_key.pem` and is never shared.

#### How Terraform uses it

Terraform reads `~/.oci/config` automatically. When you run `terraform apply`, it signs every OCI API request with your private key. OCI verifies the signature against the public key registered in your profile and either allows or rejects the operation.

You also copy the key values into `terraform.tfvars` so Terraform knows which credentials to use:

```ini
user_ocid        = ocid1.user.oc1..aaaa...
fingerprint      = xx:xx:xx:xx:...
private_key_path = ~/.oci/oci_api_key.pem
tenancy_ocid     = ocid1.tenancy.oc1..aaaa...
region           = us-phoenix-1
compartment_ocid = ocid1.compartment.oc1..aaaa...
```

> **Never commit `terraform.tfvars`** — it contains paths and identifiers tied to your OCI account. It is already listed in `deploy/terraform/.gitignore`.

#### Summary: SSH key vs OCI API key

| | SSH key | OCI API key |
|-|---------|------------|
| **Created** | Locally with `ssh-keygen` | In the OCI Console |
| **Private key lives** | `~/.ssh/id_ed25519` | `~/.oci/oci_api_key.pem` |
| **Public key goes to** | OCI Console / `terraform.tfvars` as `ssh_public_key` | Stays registered in OCI Console |
| **Used for** | SSH access to a VM | Terraform API calls, OCI CLI, kubectl |
| **Needed for Docker Compose deploy** | Yes — to SSH into the VM | Yes — if using Terraform to provision the VM |
| **Needed for OKE deploy** | No — you don't SSH into OKE nodes | Yes — Terraform + kubectl both use it |

---

### 4.5 — The .env File

The `.env` file holds secrets that should never be hard-coded in your code or committed to Git. It looks like:

```
JWT_SECRET=some-long-random-string-here
INTERNAL_API_KEY=another-secret-value
```

Docker Compose reads this file and injects these values into the containers as environment variables. Each service reads them at startup.

**Why not just put these values in `docker-compose.yml`?**

`docker-compose.yml` is checked into Git. If you put secrets there, anyone with access to your repository can see them. The `.env` file is listed in `.gitignore`, so it is never committed. The `.env.example` file (which *is* committed) shows the structure without real values.

---

## Part 5 — How a Request Flows End-to-End

Let's trace what happens when a user logs in and uploads a document.

### Step 1 — Login

1. User opens `http://localhost:4200` in a browser
2. Angular loads the login page
3. User types `admin` / `Admin@123` and clicks Login
4. Angular sends a `POST` request to `/api/auth/login` with the credentials
5. Nginx receives the request, sees `/api/auth/` in the URL, and forwards it to User Management on port 8081
6. User Management checks the database — credentials match
7. User Management creates a JWT with payload `{"sub":"admin","role":"SUPER_USER"}`, signs it with `JWT_SECRET`, and sends it back
8. Angular stores the JWT in memory
9. Angular reads the `role` from the JWT payload and redirects the user to the `/super-user` screen

### Step 2 — Loading a protected page

1. User navigates to the Super User screen
2. Angular's route guard checks: does the stored JWT contain `SUPER_USER` role? Yes — allow navigation
3. Angular sends `GET /api/applications/` with `Authorization: Bearer <token>`
4. Nginx forwards to Application Management on port 8082
5. Application Management verifies the JWT signature using `JWT_SECRET`
6. The role in the token is `SUPER_USER` — access allowed
7. Application Management queries its database and returns the list of applications
8. Angular renders the data on screen

### Step 3 — Uploading a document

1. User selects an application and uploads a file
2. Angular sends `POST /api/documents/upload` with the file and `Authorization: Bearer <token>`
3. Nginx forwards to Document Management on port 8083
4. Document Management verifies the JWT — role is valid
5. Document Management saves the file to its database
6. Document Management sends a `POST` to the Audit Service at `http://audit-service:8084/audit/events` with the `X-Internal-Key` header
7. Audit Service checks the header — key matches — records the event
8. Document Management returns success to Angular
9. Angular refreshes the document list

Notice that the browser is never involved in step 6-7. That is a server-to-server call that happens invisibly inside Docker's private network.

---

## Part 6 — The Database

Each service has its own database using **HSQLDB** — a simple database that stores everything in files. There is no separate database server to install or manage. HSQLDB runs inside each service's Java process and writes its data to files in a Docker volume.

| Service | Database files |
|---------|---------------|
| User Management | `/data/userdb` |
| Application Management | `/data/appdb` |
| Document Management | `/data/docdb` |
| Audit | `/data/auditdb` |

Each service only accesses its own database. Services do not share databases — if the Document Management service needs to know if a user exists, it calls the User Management service's API rather than reading its database directly.

---

## Part 7 — Deploying to the Cloud

Running on your laptop is convenient for development. Deploying to OCI means the application runs on a computer in Oracle's data centre, accessible over the internet.

### What changes

| | Local | Cloud (OCI) |
|--|-------|-------------|
| Where it runs | Your laptop | Oracle's data centre |
| How you access it | `localhost:4200` | `<PUBLIC-IP>:4200` |
| How you manage it | Terminal on your machine | SSH into the VM |
| Uptime | Only when your laptop is on | 24/7 |

### What stays the same

Everything else is identical. The same Docker Compose file, the same container images, the same `.env` secrets. Docker ensures the application behaves the same regardless of where it runs.

### Networking on OCI

OCI wraps your VM in a **Virtual Cloud Network (VCN)** — a private network isolated from the internet. By default, all inbound traffic is blocked. You must explicitly open ports in the **Security List** to allow traffic in.

For this application, port 4200 must be open so users can reach the UI. The backend ports (8081–8084) can stay closed — they are only accessible from within the VM itself, via Nginx.

> **If using Terraform:** The VCN, subnets, internet gateway, and Security List rule opening port 4200 are all created automatically by `terraform apply`. You do not need to touch the OCI Console for any networking setup — Terraform handles it using your OCI API key credentials (see Section 4.4). When you run `terraform destroy`, all of those resources are removed cleanly.

---

## Part 8 — Putting It All Together

Here is the complete picture of a production deployment on OCI:

```
Internet
    │
    ▼  port 4200 (open in OCI Security List)
┌────────────────────────────────┐
│         OCI ARM VM             │
│                                │
│  ┌──────────────────────────┐  │
│  │  Docker (private network)│  │
│  │                          │  │
│  │  [Nginx :4200]           │  │
│  │      │ routes /api/*     │  │
│  │      ▼                   │  │
│  │  [user-mgmt  :8081]      │  │
│  │  [app-mgmt   :8082]      │  │
│  │  [doc-mgmt   :8083]      │  │
│  │  [audit      :8084]      │  │
│  │                          │  │
│  │  Volumes: /data/*db      │  │
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

**The security layers:**
1. OCI Security List — blocks all ports except 4200 from the internet
2. Nginx — only accepts requests it knows how to route
3. JWT verification — every API call must carry a valid signed token
4. Role checks — each endpoint enforces which roles are allowed
5. Internal API key — audit events can only be sent by trusted services
6. SSH keys — only authorised operators can access the VM itself

Each layer is independent. If one were bypassed, the others would still protect the system.

---

## Quick Reference — Key Terms

| Term | What it means |
|------|--------------|
| **Container** | A self-contained package with an app and everything it needs to run |
| **Docker** | The tool that builds and runs containers |
| **Docker Compose** | Runs multiple containers together from one config file |
| **Volume** | Persistent storage shared between your machine and a container |
| **Nginx** | A web server acting as a reverse proxy — routes requests to the right service |
| **JWT** | A signed token proving who you are and what role you have |
| **JWT_SECRET** | The shared secret used to sign and verify JWTs |
| **INTERNAL_API_KEY** | A shared secret used for service-to-service calls |
| **SSH key pair** | Created locally with `ssh-keygen`. Public key is pasted into OCI/Terraform. Used only for `ssh` access to VMs. |
| **OCI API key** | Created in the OCI Console; private key is downloaded to `~/.oci/`. Used by Terraform and OCI CLI to authenticate API calls. Not used for SSH. |
| **.env file** | Holds secrets; never committed to Git |
| **VCN** | Oracle's virtual private network that wraps your cloud VM |
| **Security List** | OCI firewall rules that control which ports are open |
| **Microservice** | A small, focused service responsible for one area of functionality |
| **Reverse proxy** | A server that receives requests and forwards them to backend services |
| **Pod** | The smallest runnable unit in Kubernetes — one or more containers grouped together |
| **Deployment** | Kubernetes object that keeps a set of pods running and restarts them if they crash |
| **K8s Service** | A stable network address that routes traffic to the right pods |
| **ClusterIP Service** | A Service with an internal-only address — not reachable from outside the cluster |
| **PVC** | PersistentVolumeClaim — a request for storage in Kubernetes (like a Docker volume) |
| **Helm** | A package manager for Kubernetes — bundles all YAML config into a deployable chart |
| **Helm chart** | A collection of Kubernetes config templates with configurable values |
| **Ingress** | A Kubernetes object defining HTTP routing rules (host/path → service) |
| **Ingress Controller** | A pod in the cluster that reads Ingress rules and implements them |
| **OCIR** | OCI Container Registry — where Docker images are stored for OKE to pull |
| **imagePullSecret** | A Kubernetes secret holding OCIR credentials so pods can pull private images |
| **OKE** | Oracle Kubernetes Engine — Oracle's managed Kubernetes service |
| **OCI Load Balancer** | A cloud network resource with a public IP, auto-provisioned when a `type: LoadBalancer` Service is created in OKE |
| **kubeconfig** | A file (`~/.kube/config`) that tells `kubectl` which cluster to connect to and how |
| **Kubernetes Secret** | An encrypted object in the cluster used to store sensitive values like passwords |

---

## Appendix — Kubernetes and Helm

This appendix explains how the application works when deployed to Oracle Kubernetes Engine (OKE) using Helm. It focuses on how security mechanisms and request flows differ from the Docker Compose deployment.

---

### A1 — What Is Kubernetes?

Docker Compose is excellent for running containers on a single machine. Kubernetes takes the same idea further: it manages containers across a cluster of machines and handles concerns that become important at scale:

- If a container crashes, Kubernetes restarts it automatically
- If a machine fails, Kubernetes moves its containers to a healthy machine
- You can run multiple copies of a service and Kubernetes load-balances between them
- Kubernetes manages secrets, storage, and networking for all containers in the cluster

You interact with Kubernetes using a command-line tool called `kubectl`. Instead of writing a `docker-compose.yml`, you write YAML files describing the desired state of the system. Kubernetes continuously works to match reality to that desired state.

#### What is OKE?

Running Kubernetes yourself requires managing the cluster's own infrastructure — the "control plane" that makes decisions about scheduling and networking. **OKE (Oracle Kubernetes Engine)** is a managed service: Oracle runs the control plane for you. You only provision the worker nodes (the VMs that actually run your containers).

---

### A2 — What Is Helm?

A moderately complex application needs dozens of Kubernetes YAML files — one each for deployments, services, storage claims, secrets, and more. Managing these by hand is error-prone.

**Helm** is a package manager for Kubernetes. It bundles all those YAML files into a **chart** — a directory of templates with configurable values. Instead of editing five separate files to change an image tag, you set one value and Helm regenerates everything.

For this application, the Helm chart lives at `deploy/helm/fullstack-app/`. Deploying the whole application is a single command:

```bash
helm upgrade --install my-release ./deploy/helm/fullstack-app \
  --set audit.env.JWT_SECRET="..." \
  ...
```

Helm tracks what it deployed so you can upgrade, roll back, or uninstall cleanly.

---

### A3 — How Secrets Work in Kubernetes

This is the most important difference from the Docker Compose deployment.

#### In Docker Compose

Secrets live in a `.env` file on the VM. Docker Compose reads the file and passes the values as environment variables to each container. The file lives on one machine and must be protected manually.

#### In Kubernetes

There is no `.env` file. Secrets are stored as **Kubernetes Secret objects** — encrypted entries in the cluster's internal database (etcd). Kubernetes injects their values into pods as environment variables at startup.

You provide the secrets at deploy time via `helm install --set` flags:

```bash
helm upgrade --install my-release ./deploy/helm/fullstack-app \
  --set audit.env.JWT_SECRET="${JWT_SECRET}" \
  --set audit.env.INTERNAL_API_KEY="${INTERNAL_API_KEY}" \
  ...
```

Helm templates turn these values into Kubernetes Secret objects. The secrets are then referenced by pod definitions — Kubernetes fetches the values and injects them when starting each pod.

**Why this is more secure than `.env` on a VM:**
- Secrets are never written to a file on disk on any worker node
- Access to secrets can be restricted per-service using Kubernetes RBAC (role-based access control)
- You never SSH into a node and look at a file to see what secrets are configured

> **If using Terraform:** Terraform provisions the OKE cluster and node pool. It does not manage Kubernetes secrets — those are created by Helm during deployment.

#### JWT_SECRET and INTERNAL_API_KEY in OKE

These work identically to Docker Compose at the application level. The only difference is how they reach the containers:

| | Docker Compose | Kubernetes / Helm |
|--|---------------|-------------------|
| Where stored | `.env` file on VM | Kubernetes Secret object in cluster |
| How injected | Docker Compose `env_file` | Kubernetes `envFrom` in pod spec |
| Who can read it | Anyone with SSH access to VM | Only pods granted access; cluster admins |

The JWT is still signed with `JWT_SECRET` and verified the same way. The `INTERNAL_API_KEY` is still sent in the `X-Internal-Key` header. The application code does not change.

---

### A4 — OCIR and Image Pull Secrets

In the Docker Compose deployment, images are built on the VM itself — `docker compose up --build` builds them locally. In OKE, the cluster's worker nodes need to pull pre-built images from a registry.

**OCIR (OCI Container Registry)** is Oracle's private Docker image registry. You build images on your laptop, push them to OCIR, and OKE pulls them from there.

OCIR is private — you must authenticate to push or pull. The setup is a three-step process:

**Step 1 — Create an auth token in the OCI Console**

OCI Console → Profile → My Profile → Auth Tokens → Generate Token. Copy it immediately — it is only shown once. This token acts as a password for OCIR. It is not your OCI account password; if it is compromised you can revoke it and generate a new one without affecting anything else.

**Step 2 — Create the secret in the cluster (on your local machine)**

Run this `kubectl` command once, before deploying with Helm:

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server="<region>.ocir.io" \
  --docker-username="<namespace>/<username>" \
  --docker-password="<auth-token>"
```

This stores your OCIR credentials as a Kubernetes Secret named `ocir-secret` inside the cluster. The token value is encrypted in the cluster's database — you do not need to store it anywhere else after this.

**Step 3 — Helm chart references the secret automatically**

You do not need to add anything to the Helm YAML. The chart templates already contain this in every pod definition:

```yaml
imagePullSecrets:
  - name: ocir-secret
```

This is pre-built into the chart. When Kubernetes starts a pod, it sees the reference, looks up `ocir-secret`, authenticates to OCIR using those credentials, and pulls the image. Without the secret existing in the cluster, pod startup fails with an "image pull" error.

**Summary of the flow:**

```
OCI Console          Your local machine          Kubernetes cluster
───────────          ─────────────────          ──────────────────
Generate auth   →    kubectl create secret   →   ocir-secret stored
token (once)         docker-registry                in cluster

                                                Helm chart already
                                                has imagePullSecrets:
                                                  - name: ocir-secret

                                                Pods start → K8s reads
                                                ocir-secret → pulls
                                                image from OCIR
```

---

### A5 — How You Manage the Cluster (kubectl + OCI Credentials)

In the Docker Compose deployment, you manage the application by SSH-ing into the VM and running `docker compose` commands. In OKE, you never SSH into nodes. Instead, you use `kubectl` from your local machine.

The OCI API key (covered in **Section 4.4**) is what authenticates both Terraform and kubectl to OCI — it is not the same as the SSH key. For OKE you only need the OCI API key; the SSH key is not used at all since you never SSH into cluster nodes.

#### How kubectl authenticates to OKE

`kubectl` communicates with the OKE control plane over HTTPS. It does not use SSH at all. Authentication works like this:

1. The OCI CLI (which reads `~/.oci/config` and your **OCI API key**) generates a short-lived token proving your OCI identity
2. `kubectl` presents this token to the OKE control plane with each request
3. OKE verifies the token against OCI IAM and allows or denies the operation

The connection details — cluster address, how to get a token — are stored in a **kubeconfig** file at `~/.kube/config`. You generate it once with a command shown in the OCI Console under Access Cluster:

```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc1... \
  --file $HOME/.kube/config \
  --region us-phoenix-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

After this, every `kubectl` or `helm` command you run is authenticated as your OCI user via the OCI API key — no SSH involved.

**Why not SSH into nodes?**

- OKE worker nodes do not need to expose SSH to the internet
- All cluster management goes through the Kubernetes API, which is authenticated and audited
- You can manage the cluster from anywhere that has the kubeconfig and OCI CLI configured

---

### A6 — Storage: PersistentVolumeClaims vs Docker Volumes

In Docker Compose, each service writes its database to a volume — a folder on the VM's disk. If the VM is deleted, the data is gone.

In Kubernetes, storage is requested via **PersistentVolumeClaims (PVCs)**. When a pod needs storage, it creates a PVC describing its requirements (size, access mode). Kubernetes fulfils the claim by provisioning a storage resource — in OKE this is an **OCI Block Volume**, a dedicated network disk that:

- Is independent of the pod and the node
- Persists if the pod is restarted, rescheduled, or moved to a different node
- Can be backed up and snapshotted via the OCI Console

The Helm chart defines a PVC for each service's database. When you run `helm install`, Kubernetes automatically provisions five Block Volumes in OCI.

> **Important:** When you `helm uninstall`, the PVCs are not deleted automatically. You must explicitly run `kubectl delete pvc -l app.kubernetes.io/instance=my-release` to remove them and stop being billed for the Block Volumes.

---

### A7 — Architecture Differences

| Concept | Docker Compose (VM) | Kubernetes (OKE) |
|---------|--------------------|--------------------|
| Running unit | Container | Pod |
| "Keep it running" | Docker restart policy | Deployment controller |
| Network address | Container name (e.g. `audit-service`) | Kubernetes Service (same DNS name) |
| Entry point | Nginx port on the VM | OCI LoadBalancer (auto-provisioned) |
| Port exposed to internet | 4200 in OCI Security List | 80 via LoadBalancer |
| Persistent storage | Docker volume on VM disk | PVC → OCI Block Volume |
| Secrets | `.env` file on VM | Kubernetes Secret objects |
| Image source | Built locally on VM | Pulled from OCIR |
| How you manage it | SSH + `docker compose` | `kubectl` + `helm` |

Notice that the **Kubernetes Service names** deliberately match the Docker Compose container names (`audit-service`, `user-management-service`, etc.). This means the application code — which calls `http://audit-service:8084` to send audit events — works without any changes in either deployment mode.

---

### A8 — The OCI Load Balancer vs Kubernetes Ingress

These are three separate things that work together as layers — a common source of confusion.

#### Ingress (the routing rule)

An **Ingress** is a Kubernetes object that defines HTTP routing rules — which hostnames and URL paths should go to which internal services. In this app's Helm chart, the Ingress rule says: all traffic on path `/` goes to the frontend ClusterIP service.

The frontend Service is `type: ClusterIP`, meaning it has no public IP and is internal to the cluster. The Ingress is what connects the outside world to it.

#### Ingress Controller (the software that implements the rules)

An **Ingress Controller** is a pod running inside the cluster that watches for Ingress objects and implements their rules. A popular one is `nginx-ingress`. When you create an Ingress object, the controller reads it and configures itself to route traffic accordingly.

The Ingress Controller itself is exposed to the internet via its own Kubernetes Service of `type: LoadBalancer`.

#### OCI Load Balancer (the cloud entry point)

When Kubernetes creates a Service of `type: LoadBalancer`, OKE automatically provisions an **OCI Load Balancer** — a cloud network resource with a public IP address. It receives internet traffic and forwards it into the cluster to reach the Ingress Controller.

The OCI Load Balancer knows nothing about HTTP paths or Kubernetes — it just forwards TCP traffic on port 80 to the Ingress Controller pod. The Ingress Controller is what applies the routing rules.

#### How they fit together

```
Internet
    │
    ▼  port 80 (public IP)
[OCI Load Balancer]           ← OCI cloud resource, provisioned automatically
    │                            when the Ingress Controller Service is created
    ▼
[Ingress Controller pod]      ← software in the cluster (e.g. nginx-ingress)
    │                            reads Ingress objects and routes traffic
    ▼
[Ingress object]              ← Kubernetes routing rule:
    │                            "path / → frontend-service"
    ▼
[ClusterIP Service: frontend] ← internal-only, no public IP
    │
    ▼
[Nginx Pod]                   ← the Angular app + API proxy
```

| Layer | What it is | Created by |
|-------|-----------|-----------|
| **OCI Load Balancer** | Cloud network resource, public IP | OKE automatically, when a `type: LoadBalancer` Service is created |
| **Ingress Controller** | Pod in the cluster implementing routing rules | You install it separately (e.g. `helm install nginx-ingress`) |
| **Ingress** | Kubernetes config object defining routing rules | Helm chart (`frontend-ingress.yaml`) |
| **ClusterIP Service** | Internal cluster address for frontend pods | Helm chart (`frontend-service.yaml`) |

---

### A9 — Request Flow in OKE

Let's trace the same login-and-upload scenario from Part 5, now running in OKE.

#### Login

1. User opens `http://<EXTERNAL-IP>` (the OCI Load Balancer's public IP)
2. The **OCI Load Balancer** forwards the request on port 80 to the **Ingress Controller pod**
3. The **Ingress Controller** reads the Ingress rules and forwards to the **frontend ClusterIP Service**
4. The frontend Service routes to the **Nginx pod**
5. Nginx sees `/api/auth/login` and forwards to the **user-management Kubernetes Service**
6. The user-management Service routes to the **user-management pod**
7. The pod reads `JWT_SECRET` from its environment (injected by Kubernetes from the Secret object)
8. Credentials are verified, a signed JWT is created and returned
9. Browser stores the JWT — same as Docker Compose from here on

#### Document upload

1. Angular sends `POST /api/documents/upload` with `Authorization: Bearer <token>`
2. OCI LB → Ingress Controller → frontend Service → Nginx pod → doc-management Service → doc-management pod
3. Pod reads `JWT_SECRET` from its environment and verifies the token
4. File is written to the pod's PVC (backed by an OCI Block Volume)
5. Pod reads `INTERNAL_API_KEY` from its environment (from a Kubernetes Secret)
6. Pod calls `http://audit-service:8084/audit/events` — this resolves to the **audit Kubernetes Service**, which routes to the audit pod
7. Audit pod verifies the `X-Internal-Key` header and records the event
8. Success returned to browser

The internal call (step 6) travels over Kubernetes' internal cluster network. It never leaves the cluster and is never visible to the internet.

---

### A10 — The Complete OKE Picture

```
Internet
    │
    ▼  port 80 (public IP)
[OCI Load Balancer]              ← cloud resource, auto-provisioned by OKE
    │
    ▼
[Ingress Controller Pod]         ← reads Ingress routing rules
    │
    ▼
[Ingress: path / → frontend]     ← routing rule defined in Helm chart
    │
    ▼
[ClusterIP Service: frontend] ──► [Nginx Pod]
                                       │
               ┌───────────────────────┼───────────────────┐
               ▼                       ▼                   ▼
   [Svc: user-mgmt]          [Svc: app-mgmt]      [Svc: doc-mgmt]
               │                       │                   │
           [Pod]                   [Pod]               [Pod]
               │                       │                   │
               └───────────────────────┴───────────────────┘
                                       │ X-Internal-Key header
                                       ▼
                            [Svc: audit] ──► [Audit Pod]

Each pod reads JWT_SECRET and INTERNAL_API_KEY
from Kubernetes Secret objects (not from .env files).

Each pod writes data to a PVC backed by an OCI Block Volume.
Images are pulled from OCIR using the ocir-secret imagePullSecret.
```

---

### A11 — Security Layers in OKE

| Layer | What it does |
|-------|-------------|
| **OCI VCN Security List** | Blocks all inbound traffic except port 80 to the LoadBalancer |
| **OCI LoadBalancer** | Single public entry point; forwards to cluster internals |
| **Nginx pod** | Route-based forwarding; only known `/api/*` paths are proxied |
| **JWT verification** | Every API call must carry a valid token signed with `JWT_SECRET` |
| **Role checks** | Each endpoint enforces which roles are permitted |
| **Internal API key** | Audit events only accepted from pods presenting the correct `X-Internal-Key` |
| **Kubernetes Secrets** | `JWT_SECRET` and `INTERNAL_API_KEY` stored encrypted in etcd; injected at pod start |
| **imagePullSecrets** | Only pods with `ocir-secret` can pull images from OCIR |
| **OCI IAM + kubeconfig** | Only authorised OCI users can manage the cluster via `kubectl` or `helm` |
| **OKE control plane** | Kubernetes API is authenticated; all cluster changes are logged |

The key difference from the VM deployment is that secrets are never stored in a file on a machine. They live in the cluster's encrypted database and are injected into pods at runtime. Even if a worker node were compromised, an attacker would not find a `.env` file to read.
