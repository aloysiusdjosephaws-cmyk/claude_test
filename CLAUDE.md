# Application Manager — Full-Stack Project

A Spring Boot microservices + Angular 19 application for managing files/documents across applications, with role-based access control, served via Docker Compose.

## Stack

| Layer      | Technology                                        |
|------------|---------------------------------------------------|
| Backend    | Spring Boot 3.2, Java 17, Maven (4 microservices) |
| Frontend   | Angular 19, Standalone Components                 |
| Database   | HSQLDB (file-based, separate volume per service)  |
| Auth       | JWT (HS256, shared secret across services)        |
| Proxy      | Nginx (serves Angular + proxies API to 4 backends)|
| Container  | Docker Compose                                    |
| Kubernetes | Helm 3 chart (`deploy/helm/fullstack-app`)        |

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
├── .env.example                    # JWT_SECRET, INTERNAL_API_KEY template
├── docker-compose.yml              # 5 services: 4 backends + frontend
├── deploy/
│   └── helm/
│       └── fullstack-app/
│           ├── Chart.yaml
│           ├── values.yaml         # 4 service configs + frontend
│           └── templates/
│               ├── _helpers.tpl
│               ├── audit-*.yaml            (deployment, service, pvc)
│               ├── user-mgmt-*.yaml        (deployment, service, pvc)
│               ├── app-mgmt-*.yaml         (deployment, service, pvc)
│               ├── doc-mgmt-*.yaml         (deployment, service, pvc)
│               ├── frontend-deployment.yaml
│               ├── frontend-service.yaml
│               └── frontend-ingress.yaml
├── services/
│   ├── audit-service/              # Port 8084 — stores audit events
│   ├── user-management-service/    # Port 8081 — JWT issuance + user CRUD
│   ├── application-management-service/  # Port 8082 — app CRUD + assignments
│   └── document-management-service/     # Port 8083 — file upload/download/filter
└── frontend/
    ├── Dockerfile
    ├── nginx.conf                  # Proxies /api/* to 4 backends
    └── src/app/
        ├── core/
        │   ├── auth.service.ts
        │   ├── role.guard.ts
        │   └── jwt.interceptor.ts
        └── features/
            ├── login/
            ├── super-user/         # SUPER_USER screen
            ├── project-officer/    # PROJECT_OFFICER screen
            ├── app-manager/        # APPLICATION_MANAGER screen (matches UI spec)
            └── app-user/           # APPLICATION_USER screen
```

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
- `POST|DELETE /applications/{appId}/managers` — assign/remove managers (SuperUser/ProjectOfficer)
- `POST|DELETE /applications/{appId}/users` — assign/remove users (ProjectOfficer)
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
- **File Filter Logic**: if `fileFilter=Y`, only the uploading AppManager can view/download that document
- HSQLDB: `/data/docdb`

## Nginx Routing (`frontend/nginx.conf`)

| Path prefix | Proxied to |
|-------------|-----------|
| `/api/auth/` | user-management-service:8081 |
| `/api/users/` | user-management-service:8081 |
| `/api/applications/` | application-management-service:8082 |
| `/api/documents/` | document-management-service:8083 |
| `/api/groups/` | document-management-service:8083 |
| `/api/help/` | document-management-service:8083 |
| `/api/audit/` | audit-service:8084 |

## Build & Run

### Prerequisites
- Docker 24+ and Docker Compose v2

### Setup
```bash
cp .env.example .env
# Edit .env: set JWT_SECRET and INTERNAL_API_KEY
```

### Start everything
```bash
docker-compose up --build -d
```

Startup order: audit-service → user-management-service → application-management-service → document-management-service → frontend-client

### Access the UI
Open [http://localhost:4200](http://localhost:4200) — redirects to `/login`.

### Stop
```bash
docker-compose down
# To also remove all database volumes:
docker-compose down -v
```

## Angular Screens

| Route | Role | Key Features |
|-------|------|-------------|
| `/login` | Public | Username/password → JWT → role-based redirect |
| `/super-user` | SUPER_USER | Manage Application Managers + App Assignments |
| `/project-officer` | PROJECT_OFFICER | Manage Applications + Users + Assignments |
| `/app-manager` | APP_MANAGER | Two-panel: left (upload/edit/groups/app list) + right (document table with filter+pagination) |
| `/app-user` | APP_USER | Select app → search documents → download |

## Helm Deployment

```bash
helm lint ./deploy/helm/fullstack-app
helm template my-release ./deploy/helm/fullstack-app
helm install my-release ./deploy/helm/fullstack-app \
  --set audit.env.JWT_SECRET=your-secret \
  --set userManagement.env.JWT_SECRET=your-secret \
  --set applicationManagement.env.JWT_SECRET=your-secret \
  --set documentManagement.env.JWT_SECRET=your-secret
```

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `JWT_SECRET` | All 4 services | Shared HS256 signing secret |
| `INTERNAL_API_KEY` | audit-service + callers | Service-to-service auth for audit endpoint |
| `AUDIT_SERVICE_URL` | user-mgmt, app-mgmt, doc-mgmt | URL of audit-service |
| `USER_SERVICE_URL` | app-mgmt | URL of user-management-service |
| `APP_SERVICE_URL` | doc-mgmt | URL of application-management-service |
