# Application Manager

A Spring Boot microservices + Angular 19 application for managing documents across applications, with role-based access control.

## Stack

| Layer | Technology |
|-------|-----------|
| Backend | Spring Boot 3.2, Java 17, Maven (4 microservices) |
| Frontend | Angular 19, Standalone Components |
| Database | HSQLDB (file-based, one volume per service) |
| Auth | JWT (HS256, shared secret) |
| Proxy | Nginx (serves Angular + proxies /api/* to backends) |
| Container | Docker Compose |
| Kubernetes | Helm 3 chart (`deploy/helm/fullstack-app`) |

## Services

| Service | Port | Responsibility |
|---------|------|----------------|
| user-management-service | 8081 | JWT login, user CRUD |
| application-management-service | 8082 | Application + assignment CRUD |
| document-management-service | 8083 | File upload/download/search, groups, help docs |
| audit-service | 8084 | Audit event store |
| frontend-client (nginx) | 4200 / 80 | Angular SPA + API proxy |

## User Roles

| Role | Capabilities |
|------|-------------|
| SUPER_USER | Manage Application Managers, assign apps to managers |
| PROJECT_OFFICER | Manage Applications, Application Users, and their assignments |
| APP_MANAGER | Upload/update/delete/download documents; manage file groups and descriptions |
| APP_USER | Search and download documents (read-only) |

## Running the Application

See **[RUNNING.md](RUNNING.md)** for full instructions covering:
- Local development (5 terminals, no Docker)
- Docker Compose
- Kubernetes with Helm (local cluster)
- OCI deployment (OKE + OCIR)

## Project Structure

```
.
├── .env.example                         # JWT_SECRET, INTERNAL_API_KEY template
├── docker-compose.yml
├── deploy/
│   └── helm/
│       └── fullstack-app/
│           ├── Chart.yaml
│           ├── values.yaml              # default values
│           ├── values-oci.yaml          # OCI/OKE overrides
│           └── templates/
│               ├── audit-*.yaml
│               ├── user-mgmt-*.yaml
│               ├── app-mgmt-*.yaml
│               ├── doc-mgmt-*.yaml
│               ├── frontend-deployment.yaml
│               ├── frontend-service.yaml
│               └── frontend-ingress.yaml
├── services/
│   ├── audit-service/
│   ├── user-management-service/
│   ├── application-management-service/
│   └── document-management-service/
└── frontend/
    ├── Dockerfile
    ├── nginx.conf
    ├── proxy.conf.json                  # local dev proxy (ng serve)
    └── src/app/
        ├── core/                        # auth, JWT interceptor, guards
        ├── shared/                      # header component
        └── features/
            ├── login/
            ├── super-user/
            ├── project-officer/
            ├── app-manager/
            └── app-user/
```

## API Routing

All frontend calls go to `/api/*`. Nginx (Docker/OCI) and the Angular dev proxy (local) forward them:

| Path prefix | Service |
|-------------|---------|
| `/api/auth/`, `/api/users/` | user-management-service:8081 |
| `/api/applications/` | application-management-service:8082 |
| `/api/documents/`, `/api/groups/`, `/api/help/` | document-management-service:8083 |
| `/api/audit/` | audit-service:8084 |

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `JWT_SECRET` | All 4 services | Shared HS256 signing secret (min 32 chars) |
| `INTERNAL_API_KEY` | audit-service + callers | Service-to-service auth header |
| `AUDIT_SERVICE_URL` | user-mgmt, app-mgmt, doc-mgmt | URL of audit-service |
| `USER_SERVICE_URL` | app-mgmt | URL of user-management-service |
| `APP_SERVICE_URL` | doc-mgmt | URL of application-management-service |
