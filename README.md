# File Service — Full-Stack App

A Spring Boot + Angular file upload/download application backed by HSQLDB, deployable via Docker Compose or Kubernetes (Helm).

## Stack

| Layer      | Technology                                  |
|------------|---------------------------------------------|
| Backend    | Spring Boot 3.2, Java 17, Maven             |
| Frontend   | Angular 19, Standalone Components, Nginx    |
| Database   | HSQLDB (file-based)                         |
| Container  | Docker Compose                              |
| Kubernetes | Helm 3 chart (`deploy/helm/fullstack-app`)  |

---

## Project Structure

```
.
├── docker-compose.yml
├── deploy/
│   └── helm/
│       └── fullstack-app/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               ├── backend-pvc.yaml
│               ├── backend-deployment.yaml
│               ├── backend-service.yaml
│               ├── frontend-deployment.yaml
│               ├── frontend-service.yaml
│               └── frontend-ingress.yaml
├── backend/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/main/java/com/example/fileservice/
│       ├── FileServiceApplication.java
│       ├── controller/FileController.java
│       ├── model/FileEntity.java
│       ├── repository/FileRepository.java
│       └── service/FileService.java
└── frontend/
    ├── Dockerfile
    ├── nginx.conf
    ├── proxy.conf.json          ← used by ng serve (local dev only)
    └── src/app/
        ├── app.component.ts
        └── services/file.service.ts
```

---

## Option A — Run Locally (no Docker)

### Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Java JDK | 17 | `java -version` |
| Maven | 3.9+ | `mvn -version` |
| Node.js / npm | 20+ | `node -v` |
| Angular CLI | 19+ | `ng version` |

Install Angular CLI if needed:

```bash
npm install -g @angular/cli@19
```

---

### 1. Start the backend

```bash
cd backend
mvn spring-boot:run
```

> HSQLDB will create `filedb.*` files in the current directory.
> The server starts on **http://localhost:8080**.

**Verify:**

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP",...}
```

---

### 2. Start the frontend

Open a second terminal:

```bash
cd frontend
npm install
ng serve --proxy-config proxy.conf.json
```

> `proxy.conf.json` forwards `/api/*` calls to `http://localhost:8080` so the Angular dev server talks to your local backend.
> The UI is available at **http://localhost:4200**.

---

### 3. Test the API directly

**Upload a file:**

```bash
curl -X POST http://localhost:8080/files/upload \
  -F "file=@/path/to/yourfile.pdf"
# {"id":1,"filename":"yourfile.pdf","contentType":"application/pdf"}
```

**List files:**

```bash
curl http://localhost:8080/files
# [{"id":1,"filename":"yourfile.pdf","contentType":"application/pdf"}]
```

**Download a file:**

```bash
curl -OJ http://localhost:8080/files/download/1
```

---

## Option B — Run in Docker (Docker Compose)

### Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Docker | 24+ | `docker version` |
| Docker Compose | v2 | `docker compose version` |

---

### 1. Build and start all services

```bash
docker compose up --build -d
```

This builds both images and starts:
- `backend-service` on **http://localhost:8080**
- `frontend-client` on **http://localhost:4200**

The frontend container waits for the backend health check to pass before starting.

---

### 2. Verify the backend is healthy

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP",...}
```

---

### 3. Test the API

**Upload a file:**

```bash
curl -X POST http://localhost:8080/files/upload \
  -F "file=@/path/to/yourfile.pdf"
```

**List files:**

```bash
curl http://localhost:8080/files
```

**Download a file:**

```bash
curl -OJ http://localhost:8080/files/download/1
```

---

### 4. Open the UI

Navigate to **http://localhost:4200** in your browser.

---

### 5. View logs

```bash
# All services
docker compose logs -f

# Backend only
docker compose logs -f backend-service

# Frontend only
docker compose logs -f frontend-client
```

---

### 6. Stop

```bash
docker compose down
```

To also delete the persisted HSQLDB volume:

```bash
docker compose down -v
```

---

## Option C — Kubernetes with Helm

### Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Helm | 3+ | `helm version` |
| kubectl | any | `kubectl version --client` |
| A running cluster | Minikube / kind / Docker Desktop | `kubectl cluster-info` |

---

### 1. Lint the chart (no cluster needed)

```bash
helm lint ./deploy/helm/fullstack-app
# 1 chart(s) linted, 0 chart(s) failed
```

---

### 2. Preview rendered manifests (no cluster needed)

```bash
helm template my-release ./deploy/helm/fullstack-app
```

Override values:

```bash
helm template my-release ./deploy/helm/fullstack-app \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.tag=1.0.0 \
  --set backend.hsqldb.storage.size=2Gi \
  --set frontend.ingress.host=myapp.local
```

---

### 3. Build and load images into the cluster

**kind:**

```bash
docker build -t backend-service:latest ./backend
docker build -t frontend-client:latest ./frontend
kind load docker-image backend-service:latest frontend-client:latest
```

**Minikube:**

```bash
eval $(minikube docker-env)
docker build -t backend-service:latest ./backend
docker build -t frontend-client:latest ./frontend
```

---

### 4. Deploy

```bash
helm install my-release ./deploy/helm/fullstack-app
```

Watch pods come up:

```bash
kubectl get pods -w
```

---

### 5. Test the backend health inside the cluster

```bash
kubectl exec deploy/my-release-fullstack-app-backend -- \
  wget -qO- http://localhost:8080/actuator/health
```

Or port-forward directly:

```bash
kubectl port-forward svc/my-release-fullstack-app-backend 8080:8080
curl http://localhost:8080/actuator/health
```

---

### 6. Access the frontend via Ingress

Install ingress-nginx if not already present (kind example):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Redeploy with the ingress class set:

```bash
helm upgrade my-release ./deploy/helm/fullstack-app \
  --set frontend.ingress.className=nginx
```

Open **http://localhost** in your browser.

---

### 7. Upgrade / uninstall

```bash
# Upgrade (e.g. new image tag)
helm upgrade my-release ./deploy/helm/fullstack-app \
  --set backend.image.tag=1.1.0

# Uninstall (keeps PVC by default)
helm uninstall my-release

# Delete PVC manually if needed
kubectl delete pvc my-release-fullstack-app-hsqldb
```

---

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/files/upload` | Upload a file (multipart/form-data, field: `file`) |
| `GET` | `/files` | List all uploaded files (metadata only) |
| `GET` | `/files/download/{id}` | Download file by ID |
| `GET` | `/actuator/health` | Health check |

Max upload size: **10 MB**

---

## Configuration

Key settings in `backend/src/main/resources/application.properties`:

| Property | Value |
|----------|-------|
| `spring.servlet.multipart.max-file-size` | `10MB` |
| `spring.datasource.url` | `jdbc:hsqldb:file:/data/filedb` |
| `server.port` | `8080` |

CORS is enabled for `http://localhost:4200` via `@CrossOrigin` on `FileController`.
