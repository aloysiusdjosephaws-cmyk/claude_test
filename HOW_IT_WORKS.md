# How UDS Works — A Beginner's Guide

This document explains how the Upload Download Service (UDS) works end-to-end, in plain language. No prior knowledge of containers, cloud, or security is assumed.

---

## Part 1 — The Big Picture

UDS is a web application that lets organisations manage file uploads and downloads across different applications, with strict role-based access control. Instead of being one giant program, it is split into smaller programs called **services**, each responsible for one job:

| Service | Job |
|---------|-----|
| **User Management** | Handles login and manages user accounts |
| **Application Management** | Manages applications and who can access them |
| **Document Management** | Handles file upload, download, and search |
| **Audit** | Records a log of every important action |
| **Frontend** | The web page you see in your browser |

Splitting things up this way means that if the document upload feature breaks, the login system keeps working. Each service can also be updated independently.

---

## Part 2 — What Is a Container?

### The problem containers solve

Imagine you write a Java program on your laptop. It works perfectly. You copy it to a server — it crashes because the server has a different version of Java. This is the classic "works on my machine" problem.

### What a container is

A **container** is a self-contained package that includes your program *and* everything it needs to run — the right version of Java, the right libraries, the right configuration — all bundled together.

Think of it like a shipping container. It doesn't matter whether it goes on a ship, a truck, or a train — the box fits the same way everywhere. A software container works the same way: it runs identically on your laptop or in a data centre in the cloud.

### Docker

**Docker** is the tool that creates and runs containers. Each service has a `Dockerfile` that describes how to build its container image. The Angular frontend also has a Dockerfile that bundles the compiled web app into an Nginx web server.

---

## Part 3 — What Is Kubernetes?

### The problem Kubernetes solves

Running one container by hand is easy. Running five containers reliably — restarting them if they crash, connecting them to each other, managing storage — becomes complex quickly. **Kubernetes** (K8s) automates this.

### Key Kubernetes concepts

| Concept | What it is |
|---------|-----------|
| **Pod** | The smallest unit — one running container (or a few tightly-coupled ones) |
| **Deployment** | Tells Kubernetes to keep N replicas of a pod running; restarts crashed pods |
| **Service** | A stable network address for a set of pods (pods come and go, the Service address stays fixed) |
| **PersistentVolumeClaim (PVC)** | A request for a piece of disk storage that survives pod restarts — used for the HSQLDB database files |
| **Ingress** | A rule that maps external HTTP requests to internal Services |

### Helm

**Helm** is a package manager for Kubernetes. Instead of writing raw YAML for every Deployment, Service, and PVC, Helm uses a **chart** — a folder of templates with configurable values. The UDS chart lives in `deploy/helm/uds/`.

To deploy UDS locally:
```bash
helm upgrade --install uds ./deploy/helm/uds -f values-local.yaml ...
```

To deploy to OCI:
```bash
helm upgrade --install uds ./deploy/helm/uds -f values-oci.yaml ...
```

The chart is identical; only the values file changes (image registry, storage class).

---

## Part 4 — How the Services Connect

```
Browser
   │
   ▼
┌─────────────────────────────────────────────────────────────────┐
│   Traefik Ingress (local) / nginx + OCI Load Balancer (OCI)    │
│   Routes all traffic to the frontend Service                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│   frontend pod — Angular app + Nginx                 │
│                                                      │
│   Serves static Angular files for the browser        │
│   Proxies /api/* requests to backend services:       │
│     /api/auth/*         → user-management:8081       │
│     /api/users/*        → user-management:8081       │
│     /api/applications/* → application-mgmt:8082      │
│     /api/documents/*    → document-mgmt:8083         │
│     /api/groups/*       → document-mgmt:8083         │
│     /api/help/*         → document-mgmt:8083         │
│     /api/audit/*        → audit-service:8084         │
└──────┬──────────┬──────────┬────────────────────────┘
       │          │          │
       ▼          ▼          ▼
   :8081       :8082       :8083       :8084
   User        App         Document    Audit
   Mgmt        Mgmt        Mgmt        Service
     │           │           │
     └───────────┴───────────┴──► Audit Service
          (all three send audit events to :8084)
```

The browser never calls the backend services directly. All API calls go to `/api/...` on the same host, and Nginx in the frontend pod routes them to the correct service using Kubernetes DNS (e.g. `user-management-service:8081`).

---

## Part 5 — Local vs OCI

### Local (Rancher Desktop)

```
Browser → http://localhost
            │
            ▼
    Traefik ingress (built into k3s)
            │
            ▼
    frontend pod (nginx)
            │
      /api/* proxied to backend pods
```

Rancher Desktop runs a single-node Kubernetes cluster (k3s) on your machine, exposing ingress on `http://localhost` directly — no tunnel needed. Images are built with `nerdctl -n k8s.io build` directly into containerd's k8s.io namespace, so k3s can use them immediately with `imagePullPolicy: Never` — no registry required.

### OCI (OKE)

```
Browser → https://<lb-ip>
                    │ (HTTPS)
                    ▼
         OCI Load Balancer (Layer 7)
                    │ (TCP, port 443)
                    ▼
         nginx ingress pod (terminates TLS)
                    │
                    ▼
         frontend pod (nginx)
                    │
               /api/* proxied to backend pods
```

OKE (Oracle Container Engine for Kubernetes) is Oracle's managed Kubernetes service. An nginx ingress controller is installed and OCI automatically provisions a standard OCI Load Balancer (Layer 7) for it. The Load Balancer forwards traffic to nginx ingress, which terminates TLS using a certificate stored as a Kubernetes secret, then serves the Angular SPA and proxies API calls — same as local from that point on.

Backend services are `ClusterIP` type — they have no public IP and are only reachable from within the cluster. The OCI Load Balancer is the sole public entry point.

The Terraform in `deploy/terraform/oke/` provisions the OKE cluster and its networking.

Note:
● 1. Angular → Backend (Browser calls)

  Angular (in browser) calls /api/documents
           │
           ▼
  https://129.146.71.63/api/documents
           │
           ▼
  OCI Load Balancer → nginx ingress → frontend pod nginx
           │
           strips /api, proxies to document-management-service:8083
           │
           ▼
  JSON response back to browser

  Caching: API responses are not cached by the browser. Each Angular action (load documents, search, etc.) makes a fresh
   HTTP call. Only the static files (Angular JS/CSS) are cached long-term. JSON data is always fetched live.

  ---
  2. Backend → Backend (Service-to-service calls)

  These never go through the browser, LB, or nginx. They talk directly via Kubernetes DNS inside the cluster:

  document-management-service
           │
           │  POST http://audit-service:8084/audit/events
           ▼
  audit-service (ClusterIP)

  application-management-service
           │
           │  GET http://user-management-service:8081/users/{id}
           ▼
  user-management-service (ClusterIP)

  Kubernetes resolves audit-service to the pod IP automatically. Traffic stays entirely inside the cluster — plain HTTP,
   no TLS, no LB, no internet. This is why the backend services are ClusterIP type — they have no external IP by design.

  ---
  Summary

  ┌───────────────────┬─────────────────────────────────────────────────────────┬─────┬────────┐
  │     Call type     │                          Path                           │ TLS │ Cached │
  ├───────────────────┼─────────────────────────────────────────────────────────┼─────┼────────┤
  │ Browser → backend │ Browser → LB → nginx ingress → frontend nginx → backend │ Yes │ No     │
  ├───────────────────┼─────────────────────────────────────────────────────────┼─────┼────────┤
  │ Backend → backend │ Direct via K8s DNS                                      │ No  │ N/A    │
  └───────────────────┴─────────────────────────────────────────────────────────┴─────┴────────┘

The frontend pod is involved because that's where the /api/* proxy logic lives — in frontend/nginx.conf.
  The nginx inside the frontend pod does two jobs:

  1. Serves static Angular files
  2. Proxies /api/* to backend services

  So the path for an API call is:

  OCI LB → nginx ingress → frontend pod nginx → backend pod

  nginx ingress routes ALL traffic to the frontend pod (it only knows about one service). The frontend nginx then
  decides:
  - Is this /api/*? → proxy to the right backend
  - Is this anything else? → serve the Angular static file
  
---

## Part 6 — Authentication & Security

### JWT (JSON Web Tokens)

When you log in, the User Management Service validates your username and password, then issues a **JWT** — a cryptographically signed token that proves who you are and what role you have.

Every subsequent API request includes this token in the `Authorization: Bearer <token>` header. Each service validates the token using the shared `JWT_SECRET`. No service needs to call the User Management Service to verify a token — the signature is self-contained.

### Roles

| Role | What they can do |
|------|-----------------|
| SUPER_USER | Manage Application Managers and their app assignments |
| PROJECT_OFFICER | Manage Applications, Application Users, and their assignments |
| APPLICATION_MANAGER | Upload, update, delete, and download documents for their assigned apps |
| APPLICATION_USER | Search and download documents (read-only) |

### Service-to-Service Auth

When any service sends an audit event to the Audit Service, it includes an `X-Internal-Key` header. The Audit Service checks this key against `INTERNAL_API_KEY`. This prevents external callers from injecting fake audit records.

---

## Part 7 — Data Storage

Each service has its own HSQLDB database — a lightweight, file-based Java database. The files are stored on a PersistentVolume (a block of disk storage provided by Kubernetes) so they survive pod restarts and redeployments.

| Service | Database file | What it stores |
|---------|--------------|----------------|
| User Management | `/data/userdb` | User accounts, roles |
| Application Management | `/data/appdb` | Applications, manager/user assignments |
| Document Management | `/data/docdb` | Document metadata, file BLOBs, groups |
| Audit | `/data/auditdb` | Audit event log |

On OCI, these are backed by OCI Block Volumes (`storageClassName: oci-bv`). Locally, they use Rancher Desktop's built-in storage (`storageClassName: local-path`).

---

## Part 8 — The File Filter Feature

When an Application Manager uploads a document, they can set `fileFilter=Y`. This means only that specific manager can see and download the document — other managers assigned to the same application cannot. Application Users cannot see filtered documents at all.

This is enforced in the Document Management Service by comparing the uploading manager's user ID (extracted from the JWT) against the stored `uploadedBy` field on each document.
