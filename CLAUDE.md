# UDS — Upload Download Service

A Spring Boot microservices + Angular 19 application for managing file uploads and downloads across applications, with role-based access control.

## Stack

| Layer      | Technology                                          |
|------------|-----------------------------------------------------|
| Backend    | Spring Boot 3.2, Java 17, Maven (4 microservices)  |
| Frontend   | Angular 19, Standalone Components                   |
| Database   | HSQLDB (file-based, separate PVC per service)       |
| Auth       | JWT (HS256, shared secret across all services)      |
| Proxy      | Nginx (serves Angular + proxies `/api/*` to backends) |
| Local      | Rancher Desktop (containerd) + Helm (`deploy/helm/uds/values-local.yaml`) |
| OCI        | OKE + OCI Load Balancer (nginx ingress, self-signed TLS) + Helm (`deploy/helm/uds/values-oci.yaml`) |

## User Roles

| Role | Responsibilities |
|------|-----------------|
| **SUPER_USER** | Add/delete/update Application Managers; assign/delete Applications to/from Application Managers. All mutations logged to audit table. |
| **PROJECT_OFFICER** | Add/delete/update Application Users; create/list/delete Applications; assign/delete applications to/from Application Users. All mutations logged to audit table. |
| **APPLICATION_MANAGER** | List/select Application; list/upload/update/delete/download documents; manage file groups and descriptions. File filter (Y/N): if Y, only the uploading manager can view that document. All mutations logged. |
| **APPLICATION_USER** | Select Application; search and download documents (by AppId, KeyId, Document Name, Group). Read-only. |

**Help tab** present on all screens — displays a role-specific help document stored as a file in the Document Management Service.

## Project Structure

```
.
├── deploy/
│   ├── helm/
│   │   └── uds/
│   │       ├── Chart.yaml
│   │       ├── values.yaml           # base config for all 5 services
│   │       ├── values-local.yaml     # Rancher Desktop overrides (local registry, local-path storage)
│   │       ├── values-oci.yaml       # OKE overrides (OCIR images, oci-bv storage)
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── audit-*.yaml              (deployment, service, pvc)
│   │           ├── user-mgmt-*.yaml          (deployment, service, pvc)
│   │           ├── app-mgmt-*.yaml           (deployment, service, pvc)
│   │           ├── doc-mgmt-*.yaml           (deployment, service, pvc)
│   │           ├── frontend-deployment.yaml
│   │           ├── frontend-service.yaml
│   │           └── frontend-ingress.yaml
│   └── terraform/
│       └── oke/                      # Provisions OKE cluster + API Gateway on OCI
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars.example
├── services/
│   ├── audit-service/                # Port 8084 — stores audit events
│   ├── user-management-service/      # Port 8081 — JWT issuance + user CRUD
│   ├── application-management-service/  # Port 8082 — app CRUD + assignments
│   └── document-management-service/     # Port 8083 — file upload/download/filter
└── frontend/
    ├── Dockerfile                    # ARG NG_CONFIG=development|production
    ├── nginx.conf                    # Proxies /api/* to 4 backends via K8s DNS
    └── src/app/
        ├── core/
        │   ├── auth.service.ts
        │   ├── role.guard.ts
        │   └── jwt.interceptor.ts
        └── features/
            ├── login/
            ├── super-user/
            ├── project-officer/
            ├── app-manager/
            └── app-user/
```

## Deployment Targets

### Local — Rancher Desktop
- Traefik ingress (built into k3s) exposes the app on `http://localhost`
- Images built with `nerdctl -n k8s.io build` directly into the k8s.io containerd namespace; `imagePullPolicy: Never`
- Angular built with `NG_CONFIG=development` — calls `/api/*` (relative), nginx proxies to backends

### OCI — OKE + OCI Load Balancer
- Terraform (`deploy/terraform/oke/`) provisions OKE cluster and VCN
- nginx ingress installed with OCI Load Balancer (Layer 7) — nginx terminates TLS
- Self-signed TLS cert stored as K8s secret `uds-tls` — nginx terminates TLS
- Helm deploys all services with OCIR images and `oci-bv` storage
- Angular built with `NG_CONFIG=production` — same `/api/*` nginx proxy approach as local
- Backend services are ClusterIP — not internet-accessible, only reachable via nginx

Both environments run identically from the application's perspective.

## Microservices

### Audit Service (Port 8084)
- Receives audit events from all other services via `POST /audit/events` (secured by `X-Internal-Key` header)
- `GET /audit/events` — query events (SuperUser/ProjectOfficer via JWT)
- HSQLDB: `/data/auditdb`

### User Management Service (Port 8081)
- `POST /auth/login` — issues JWT
- `GET|POST|PUT|DELETE /users` — user CRUD
- Roles: SUPER_USER, PROJECT_OFFICER, APP_MANAGER, APP_USER
- HSQLDB: `/data/userdb`

### Application Management Service (Port 8082)
- `GET|POST|PUT|DELETE /applications` — application CRUD
- `POST|DELETE /applications/{appId}/managers` — assign/remove managers
- `POST|DELETE /applications/{appId}/users` — assign/remove users
- Access filtering: AppManagers/AppUsers only see their assigned apps
- HSQLDB: `/data/appdb`

### Document Management Service (Port 8083)
- `POST /documents/upload` — multipart upload (AppManager)
- `GET /documents?appId=` — list documents (honours file_filter)
- `GET /documents/{id}/download` — download file bytes
- `PUT /documents/{id}` — update description/group
- `DELETE /documents/{id}` — soft delete
- `GET /documents/search` — AppUser search by appId/keyId/docName/group
- `GET|POST /groups` — group management
- `GET|PUT /help/{screenName}` — help documents per role screen
- **File Filter**: if `fileFilter=Y`, only the uploading AppManager can view/download that document
- HSQLDB: `/data/docdb`

## Nginx Routing (`frontend/nginx.conf`)

The Angular app calls `/api/*`. Nginx in the frontend pod strips `/api` and proxies by path:

| Path prefix | Proxied to |
|-------------|-----------|
| `/api/auth/` | user-management-service:8081 |
| `/api/users/` | user-management-service:8081 |
| `/api/applications/` | application-management-service:8082 |
| `/api/documents/` | document-management-service:8083 |
| `/api/groups/` | document-management-service:8083 |
| `/api/help/` | document-management-service:8083 |
| `/api/audit/` | audit-service:8084 |

## Angular Screens

| Route | Role | Key Features |
|-------|------|-------------|
| `/login` | Public | Username/password → JWT → role-based redirect |
| `/super-user` | SUPER_USER | Manage Application Managers + App Assignments |
| `/project-officer` | PROJECT_OFFICER | Manage Applications + Users + Assignments |
| `/app-manager` | APP_MANAGER | Two-panel: left (upload/edit/groups/app list) + right (document table with filter+pagination) |
| `/app-user` | APP_USER | Select app → search documents → download |

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `JWT_SECRET` | All 4 services | Shared HS256 signing secret — must be identical across all services |
| `INTERNAL_API_KEY` | audit-service + callers | Service-to-service auth header for audit endpoint |
| `AUDIT_SERVICE_URL` | user-mgmt, app-mgmt, doc-mgmt | URL of audit-service |
| `USER_SERVICE_URL` | app-mgmt | URL of user-management-service |
| `APP_SERVICE_URL` | doc-mgmt | URL of application-management-service |
