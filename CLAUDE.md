# File Service — Full-Stack Project

A Spring Boot + Angular file upload/download application backed by HSQLDB, served via Docker Compose.

## Stack

| Layer      | Technology                           |
|------------|--------------------------------------|
| Backend    | Spring Boot 3.2, Java 17, Maven      |
| Frontend   | Angular 19, Standalone Components    |
| Database   | HSQLDB (file-based, persisted volume)|
| Proxy      | Nginx (serves Angular + proxies API) |
| Container  | Docker Compose                       |
| Kubernetes | Helm 3 chart (`deploy/helm/fullstack-app`) |

## Project Structure

```
.
├── docker-compose.yml
├── deploy/
│   └── helm/
│       └── fullstack-app/
│           ├── Chart.yaml
│           ├── values.yaml             # image tags, storage, ingress host
│           └── templates/
│               ├── _helpers.tpl
│               ├── backend-pvc.yaml
│               ├── backend-deployment.yaml
│               ├── backend-service.yaml    # ClusterIP
│               ├── frontend-deployment.yaml
│               ├── frontend-service.yaml   # ClusterIP
│               └── frontend-ingress.yaml   # host: localhost
├── backend/
│   ├── Dockerfile              # Multi-stage: Maven build → JRE runtime
│   ├── pom.xml
│   └── src/main/java/com/example/fileservice/
│       ├── FileServiceApplication.java
│       ├── controller/FileController.java   # POST /files/upload, GET /files/download/{id}
│       ├── model/FileEntity.java            # @Lob byte[] storage
│       ├── repository/FileRepository.java
│       └── service/FileService.java
└── frontend/
    ├── Dockerfile              # Multi-stage: Node build → Nginx serve
    ├── nginx.conf              # Proxies /api/* → backend-service:8080
    └── src/app/
        ├── app.component.ts    # Standalone root component
        └── services/file.service.ts
```

## Build & Run

### Prerequisites
- Docker 24+ and Docker Compose v2

### Start everything

```bash
docker-compose up --build -d
```

This will:
1. Build the Spring Boot JAR (Maven inside Docker)
2. Build the Angular app (npm inside Docker) and bundle into Nginx
3. Start both containers; frontend waits for backend health check

### Verify backend health

```bash
curl http://localhost:8080/actuator/health
# Expected: {"status":"UP",...}
```

### Access the UI

Open [http://localhost:4200](http://localhost:4200) in your browser.

### Stop

```bash
docker-compose down
```

To also remove the persisted database volume:

```bash
docker-compose down -v
```

## API Endpoints

| Method | Path                      | Description              |
|--------|---------------------------|--------------------------|
| POST   | `/files/upload`           | Upload a file (multipart)|
| GET    | `/files/download/{id}`    | Download file by ID      |
| GET    | `/files`                  | List all file metadata   |
| GET    | `/actuator/health`        | Health check             |

### Upload example

```bash
curl -X POST http://localhost:8080/files/upload \
  -F "file=@/path/to/yourfile.pdf"
```

### Download example

```bash
curl -O -J http://localhost:8080/files/download/1
```

## Configuration

Key settings in `backend/src/main/resources/application.properties`:

| Property                                  | Value              |
|-------------------------------------------|--------------------|
| `spring.servlet.multipart.max-file-size`  | 10MB               |
| `spring.datasource.url`                   | `jdbc:hsqldb:file:/data/filedb` |
| `server.port`                             | 8080               |

CORS is enabled for `http://localhost:4200` via `@CrossOrigin` on `FileController`.

The Nginx proxy rewrites `/api/*` → `http://backend-service:8080/*`, so the Angular app calls `/api/files/...` and never needs to know the backend host directly.

---

## Kubernetes / Helm

### Prerequisites
- Helm 3 installed (`helm version`)
- A running Kubernetes cluster (Minikube, kind, Docker Desktop K8s, etc.)
- Images built and available in the cluster (see below)

### Lint the chart

```bash
helm lint ./deploy/helm/fullstack-app
# Expected: 1 chart(s) linted, 0 chart(s) failed
```

### Preview rendered manifests

```bash
helm template my-release ./deploy/helm/fullstack-app
```

Override values inline:

```bash
helm template my-release ./deploy/helm/fullstack-app \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.tag=1.0.0 \
  --set backend.hsqldb.storage.size=2Gi \
  --set frontend.ingress.host=myapp.local
```

### Deploy to a cluster

```bash
# Build and load images into your cluster (example: kind)
docker build -t backend-service:latest ./backend
docker build -t frontend-client:latest ./frontend
kind load docker-image backend-service:latest frontend-client:latest

# Install the release
helm install my-release ./deploy/helm/fullstack-app

# Upgrade an existing release
helm upgrade my-release ./deploy/helm/fullstack-app --set backend.image.tag=1.1.0

# Uninstall
helm uninstall my-release
```

### Values reference

| Key | Default | Description |
|-----|---------|-------------|
| `backend.image.repository` | `backend-service` | Backend image name |
| `backend.image.tag` | `latest` | Backend image tag |
| `backend.hsqldb.storage.size` | `1Gi` | PVC size for HSQLDB |
| `backend.hsqldb.storage.storageClassName` | `""` | StorageClass (empty = cluster default) |
| `backend.hsqldb.storage.mountPath` | `/data` | Mount path inside container |
| `frontend.image.repository` | `frontend-client` | Frontend image name |
| `frontend.image.tag` | `latest` | Frontend image tag |
| `frontend.ingress.enabled` | `true` | Enable Ingress resource |
| `frontend.ingress.host` | `localhost` | Ingress hostname |
| `frontend.ingress.className` | `""` | IngressClass (set to `nginx` for ingress-nginx) |

### Ingress for local testing

The Ingress is pre-configured with `host: localhost`. With ingress-nginx:

```bash
# Install ingress-nginx (kind example)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

helm install my-release ./deploy/helm/fullstack-app \
  --set frontend.ingress.className=nginx

# Then open http://localhost in your browser
```
