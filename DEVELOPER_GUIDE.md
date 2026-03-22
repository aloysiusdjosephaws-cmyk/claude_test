# File Service — Developer Guide

A comprehensive guide for Java developers new to the full-stack technologies used in this project.

---

## Table of Contents

1. [Technology Overview](#1-technology-overview)
2. [How Everything Works Together](#2-how-everything-works-together)
3. [Codebase Walkthrough](#3-codebase-walkthrough)
   - [Backend (Spring Boot)](#31-backend-spring-boot)
   - [Frontend (Angular)](#32-frontend-angular)
   - [Database (HSQLDB)](#33-database-hsqldb)
   - [Nginx (Reverse Proxy)](#34-nginx-reverse-proxy)
   - [Docker & Docker Compose](#35-docker--docker-compose)
   - [Kubernetes & Helm](#36-kubernetes--helm)
4. [Configuration End-to-End](#4-configuration-end-to-end)
5. [Deploying to Oracle Cloud Infrastructure (OCI)](#5-deploying-to-oracle-cloud-infrastructure-oci)

---

## 1. Technology Overview

### Spring Boot 3.2 (Java 17)

Spring Boot is a framework that wraps the Spring ecosystem and removes boilerplate configuration. For a Java developer, think of it as a pre-configured Java EE application server — but instead of deploying a WAR to Tomcat, Spring Boot embeds Tomcat inside the JAR and you just run `java -jar`.

Key concepts used in this project:

| Concept | Annotation | What it does |
|---------|-----------|--------------|
| REST Controller | `@RestController` | Marks a class as an HTTP request handler; every method return value is serialised to JSON |
| Request mapping | `@PostMapping`, `@GetMapping` | Maps HTTP verbs + paths to Java methods |
| Dependency injection | `@Autowired` / constructor injection | Spring creates and wires objects for you |
| JPA entity | `@Entity`, `@Table` | Maps a Java class to a database table |
| Spring Data repo | `JpaRepository<T, ID>` | Generates SQL queries from method names |
| Service layer | `@Service` | Business logic component |
| Cross-Origin | `@CrossOrigin` | Allows browsers from a different origin (port/domain) to call the API |
| Actuator | `spring-boot-starter-actuator` | Exposes operational endpoints like `/actuator/health` |

### Angular 19

Angular is a TypeScript-based single-page application (SPA) framework maintained by Google. The browser downloads the Angular app once, then all navigation and interactions happen in JavaScript without full page reloads. Think of it as the "frontend JAR" — the server just delivers static files, and the application logic runs in the user's browser.

Key concepts used in this project:

| Concept | What it does |
|---------|-------------|
| Component | A TypeScript class + HTML template + CSS that renders a part of the UI |
| Standalone component | Angular 19 style — no `NgModule` required; imports are declared directly on the component |
| Injectable service | A class marked `@Injectable` that Angular creates once and shares across components (like a Spring `@Service`) |
| `HttpClient` | Angular's HTTP library for calling REST APIs (equivalent to `RestTemplate` or `WebClient` in Spring) |
| `Observable` | Asynchronous stream from RxJS; similar to Java's `CompletableFuture` or `Mono` in Reactor |
| Environment files | `environment.ts` and `environment.prod.ts` — like Spring profiles, different values per environment |
| `ng build` | Compiles TypeScript + HTML + CSS into static `index.html`, `main.js`, `styles.css` |

### HSQLDB

HSQLDB (HyperSQL Database) is a pure-Java relational database. In `file` mode it persists data to disk files. For a Java developer familiar with H2, HSQLDB is very similar — both are embedded Java databases commonly used in development and testing. Spring Boot auto-configures JPA/Hibernate on top of it using the JDBC URL in `application.properties`.

The database creates three files on disk:
- `filedb.script` — DDL and DML statements (schema + data)
- `filedb.properties` — database state metadata
- `filedb.lobs` — binary large objects (the actual file bytes)

### Maven

The standard Java build tool in this project. Used only inside Docker (the build stage) — you do not need Maven installed locally unless running without Docker.

Key command used: `mvn package -DskipTests` — packages the Spring Boot app as an executable fat JAR.

### Nginx

Nginx is a high-performance web server used here as both a **static file server** (serves the Angular HTML/JS/CSS) and a **reverse proxy** (forwards `/api/*` requests to the Spring Boot backend). Think of it as an API Gateway for the local/Docker setup.

### Docker & Docker Compose

**Docker** packages applications into containers — isolated, reproducible environments that bundle the JRE, application code, and all dependencies. A `Dockerfile` describes how to build a container image.

**Docker Compose** is a tool that starts multiple containers together from a single `docker-compose.yml` file. It handles networking between containers (containers can reach each other by service name) and volume management (persistent storage that survives container restarts).

### Kubernetes & Helm

**Kubernetes (K8s)** is a container orchestration platform. Instead of running containers directly with Docker, you declare the desired state (how many replicas, what image, what resources) and Kubernetes continuously enforces it. Concepts used:

| K8s Concept | Description |
|-------------|-------------|
| Pod | The smallest deployable unit — one or more containers running together |
| Deployment | Manages a set of identical Pods; handles rolling updates and restarts |
| Service | A stable network endpoint that load-balances traffic to Pods |
| Ingress | An HTTP router that routes external traffic to Services by hostname/path |
| PersistentVolumeClaim (PVC) | A request for storage that survives Pod restarts |

**Helm** is the package manager for Kubernetes — like Maven for K8s. A **chart** is a collection of YAML templates. Helm renders the templates with the values you provide and applies them to the cluster. This lets you have one set of templates and multiple `values.yaml` files for different environments (local, OCI).

### OCI (Oracle Cloud Infrastructure)

OCI is Oracle's cloud platform. Key services used:

| OCI Service | Role in this project |
|-------------|---------------------|
| OCI Container Registry (OCIR) | Stores Docker images (like Docker Hub, but private) |
| Oracle Kubernetes Engine (OKE) | Managed Kubernetes cluster that runs the backend |
| OCI Object Storage | Hosts static files (the Angular build output) — like AWS S3 |
| OCI API Gateway | Exposes the backend API over HTTPS with CORS support |
| OCI Block Volume (oci-bv) | Persistent disk storage for the HSQLDB files in OKE |

---

## 2. How Everything Works Together

### Request flow (Docker Compose)

```
Browser (http://localhost:4200)
  │
  ▼
Nginx container (port 4200 → 80)
  │
  ├─ GET /  → serves Angular index.html, main.js, styles.css
  │
  └─ GET/POST /api/files/*
       │
       ▼  (proxy_pass strips /api prefix)
     Spring Boot container (backend-service:8080)
       │
       ▼
     HSQLDB files on Docker volume (hsqldb-data)
```

1. The user's browser loads the Angular app (HTML/JS) from Nginx.
2. Angular runs in the browser. When the user uploads or downloads a file, Angular's `HttpClient` sends an HTTP request to `/api/files/...`.
3. Nginx receives the request, strips the `/api` prefix, and forwards it to the Spring Boot container using the internal Docker network hostname `backend-service`.
4. Spring Boot processes the request, reads/writes data to HSQLDB files on the Docker volume, and returns a JSON or binary response.
5. Nginx relays the response back to the browser.

### Request flow (OCI production)

```
Browser (https://YOUR_BUCKET.objectstorage.oci.customer-oci.com)
  │
  ▼
OCI Object Storage (serves Angular static files)
  │
  └─ Angular makes API calls to OCI API Gateway
       │
       ▼
     OCI API Gateway (HTTPS, CORS, routing)
       │
       ▼
     OKE LoadBalancer Service (backend-service)
       │
       ▼
     Spring Boot Pod in OKE
       │
       ▼
     HSQLDB files on OCI Block Volume (PVC)
```

In production, the Angular static files are served from Object Storage (no Nginx needed for the frontend). The API calls go to the OCI API Gateway which routes them to the backend LoadBalancer, which routes to the Spring Boot Pod running in OKE.

### Why two nginx.conf / proxy configurations?

| Environment | Frontend served by | API calls go to |
|-------------|-------------------|-----------------|
| Local dev (`ng serve`) | Angular CLI dev server | `proxy.conf.json` proxies `/api` → `localhost:8080` |
| Docker Compose | Nginx container | `nginx.conf` proxies `/api` → `backend-service:8080` |
| OCI production | Object Storage | `environment.prod.ts` points directly to API Gateway URL |

---

## 3. Codebase Walkthrough

### 3.1 Backend (Spring Boot)

```
backend/
├── Dockerfile
├── pom.xml
└── src/main/
    ├── java/com/example/fileservice/
    │   ├── FileServiceApplication.java     ← entry point
    │   ├── model/FileEntity.java           ← database table
    │   ├── repository/FileRepository.java  ← SQL queries
    │   ├── service/FileService.java        ← business logic
    │   └── controller/FileController.java  ← HTTP endpoints
    └── resources/
        └── application.properties          ← configuration
```

#### `FileServiceApplication.java` — Entry point

```java
@SpringBootApplication
public class FileServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(FileServiceApplication.class, args);
    }
}
```

`@SpringBootApplication` is a shorthand for three annotations:
- `@Configuration` — this class defines Spring beans
- `@EnableAutoConfiguration` — Spring Boot scans dependencies and auto-configures (e.g., sees HSQLDB on classpath → configures a DataSource)
- `@ComponentScan` — scans the package and sub-packages for `@Component`, `@Service`, `@Controller`, etc.

#### `FileEntity.java` — Database table

```java
@Entity
@Table(name = "files")
public class FileEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String filename;

    @Column(nullable = false)
    private String contentType;

    @Lob
    @Column(nullable = false)
    private byte[] data;
}
```

- `@Entity` tells Hibernate this class maps to a database table.
- `@Id` + `@GeneratedValue` maps to an auto-increment primary key.
- `@Lob` tells Hibernate to store the field as a Large OBject (binary in HSQLDB; stored in `filedb.lobs`).
- `spring.jpa.hibernate.ddl-auto=update` means Hibernate automatically creates/alters the `files` table on startup if it doesn't match the entity.

#### `FileRepository.java` — Data access

```java
public interface FileRepository extends JpaRepository<FileEntity, Long> {

    @Query("SELECT new com.example.fileservice.model.FileEntity(f.id, f.filename, f.contentType)" +
           " FROM FileEntity f")
    List<FileEntity> findAllMetadata();
}
```

`JpaRepository` provides `save()`, `findById()`, `findAll()`, `deleteById()`, etc. for free — no SQL needed.

The custom `@Query` uses JPQL (JPA Query Language, which looks like SQL but operates on Java class names). It constructs `FileEntity` objects with only the metadata fields — avoiding loading the potentially large `byte[] data` when listing files.

#### `FileService.java` — Business logic

```java
@Service
public class FileService {
    private final FileRepository repo;

    public FileService(FileRepository repo) {  // constructor injection
        this.repo = repo;
    }

    public FileEntity store(MultipartFile file) throws IOException {
        FileEntity entity = new FileEntity();
        entity.setFilename(file.getOriginalFilename());
        entity.setContentType(file.getContentType());
        entity.setData(file.getBytes());
        return repo.save(entity);
    }

    public FileEntity load(Long id) {
        return repo.findById(id)
            .orElseThrow(() -> new RuntimeException("File not found: " + id));
    }

    public List<FileEntity> listMetadata() {
        return repo.findAllMetadata();
    }
}
```

`MultipartFile` is Spring's abstraction for an uploaded file. `file.getBytes()` reads the entire file content into memory as a byte array.

#### `FileController.java` — HTTP endpoints

```java
@RestController
@RequestMapping("/files")
@CrossOrigin(origins = "http://localhost:4200")
public class FileController {
    private final FileService service;

    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> upload(
            @RequestParam("file") MultipartFile file) throws IOException {
        FileEntity saved = service.store(file);
        return ResponseEntity.ok(Map.of(
            "id", saved.getId(),
            "filename", saved.getFilename(),
            "contentType", saved.getContentType()
        ));
    }

    @GetMapping("/download/{id}")
    public ResponseEntity<byte[]> download(@PathVariable Long id) {
        FileEntity file = service.load(id);
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION,
                    "attachment; filename=\"" + file.getFilename() + "\"")
            .contentType(MediaType.parseMediaType(file.getContentType()))
            .body(file.getData());
    }

    @GetMapping
    public ResponseEntity<List<FileEntity>> list() {
        return ResponseEntity.ok(service.listMetadata());
    }
}
```

- `@CrossOrigin` allows the browser to call this API from `http://localhost:4200`. Without this, the browser blocks the request as a CORS violation.
- `Content-Disposition: attachment` tells the browser to download the file rather than display it.
- `ResponseEntity` gives you full control over the HTTP response status, headers, and body.

#### `application.properties` — Backend configuration

```properties
# Application name (used in logs and Spring Boot admin)
spring.application.name=file-service

# HSQLDB file-based persistence. The DB files will be at ./filedb.*
# In Docker, the working directory is / so files land at /filedb.* on the container.
# The Helm chart mounts /data and overrides this via environment variable.
spring.datasource.url=jdbc:hsqldb:file:./filedb;shutdown=true
spring.datasource.driver-class-name=org.hsqldb.jdbc.JDBCDriver
spring.datasource.username=sa
# No password set — HSQLDB default (not suitable for production)

# Tell Hibernate which SQL dialect to use for HSQLDB
spring.jpa.database-platform=org.hibernate.dialect.HSQLDialect

# update = create table if not exists, alter if columns changed, never drop data
spring.jpa.hibernate.ddl-auto=update

# Max upload file size
spring.servlet.multipart.max-file-size=10MB
spring.servlet.multipart.max-request-size=10MB

# Expose only the health actuator endpoint
management.endpoints.web.exposure.include=health
management.endpoint.health.show-details=always

server.port=8080
```

#### `backend/Dockerfile` — Multi-stage build

```dockerfile
# Stage 1: Build the Spring Boot JAR using Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline  # download deps first for Docker layer caching
COPY src ./src
RUN mvn package -DskipTests    # compile and package

# Stage 2: Minimal runtime image (no Maven, no source code)
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN mkdir /data                # directory for HSQLDB files (used by Helm mount)
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Multi-stage builds are important for keeping the final image small. The Maven build stage (~700MB) is discarded; only the ~180MB JRE image plus the JAR is shipped.

---

### 3.2 Frontend (Angular)

```
frontend/
├── Dockerfile
├── nginx.conf
├── proxy.conf.json             ← local dev proxy
├── angular.json                ← CLI config
├── package.json                ← npm dependencies
└── src/
    ├── index.html              ← shell HTML (Angular injects into <app-root>)
    ├── main.ts                 ← bootstrap entry point
    ├── styles.css              ← global CSS
    ├── environments/
    │   ├── environment.ts      ← dev: apiUrl = '/api'
    │   └── environment.prod.ts ← prod: apiUrl = 'https://YOUR_GATEWAY...'
    └── app/
        ├── app.component.ts    ← root component (logic)
        ├── app.component.html  ← root component (template)
        ├── app.component.css   ← root component (styles)
        └── services/
            └── file.service.ts ← HTTP client service
```

#### `main.ts` — Angular bootstrap

```typescript
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './app/app.component';

bootstrapApplication(AppComponent, {
  providers: [provideHttpClient()]  // makes HttpClient available everywhere
}).catch(err => console.error(err));
```

This is the Angular equivalent of Spring Boot's `main()`. `provideHttpClient()` registers Angular's HTTP client — without this, injecting `HttpClient` anywhere would fail.

#### `file.service.ts` — HTTP client

```typescript
export interface FileMeta {
  id: number;
  filename: string;
  contentType: string;
}

@Injectable({ providedIn: 'root' })  // singleton, like @Service in Spring
export class FileService {
  private api = `${environment.apiUrl}/files`;  // /api/files (dev) or https://... (prod)

  constructor(private http: HttpClient) {}

  upload(file: File): Observable<FileMeta> {
    const formData = new FormData();
    formData.append('file', file);  // 'file' matches @RequestParam("file") in Spring
    return this.http.post<FileMeta>(`${this.api}/upload`, formData);
  }

  list(): Observable<FileMeta[]> {
    return this.http.get<FileMeta[]>(this.api);
  }

  downloadUrl(id: number): string {
    return `${this.api}/download/${id}`;
  }
}
```

`Observable` is asynchronous. To get the value, you must either `.subscribe()` or use `async` pipe in templates. This is like calling `.thenAccept()` on a Java `CompletableFuture`.

#### `app.component.ts` — Root component

```typescript
@Component({
  selector: 'app-root',          // HTML tag name: <app-root>
  standalone: true,              // no NgModule needed
  imports: [CommonModule],       // provides *ngIf, *ngFor in the template
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
  files: FileMeta[] = [];
  uploading = false;
  message = '';
  error = '';

  constructor(private fileService: FileService) {}  // injected automatically

  ngOnInit(): void {           // called after the component is created (like @PostConstruct)
    this.loadFiles();
  }

  loadFiles(): void {
    this.fileService.list().subscribe({
      next: (files) => this.files = files,
      error: (err) => this.error = 'Failed to load files'
    });
  }

  onFileSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;
    this.uploading = true;
    this.fileService.upload(file).subscribe({
      next: (meta) => {
        this.message = `Uploaded: ${meta.filename}`;
        this.loadFiles();      // refresh list after upload
        this.uploading = false;
      },
      error: () => {
        this.error = 'Upload failed';
        this.uploading = false;
      }
    });
  }
}
```

#### `environment.ts` vs `environment.prod.ts`

| File | Used when | `apiUrl` value |
|------|-----------|---------------|
| `environment.ts` | `ng serve` (local dev) | `/api` |
| `environment.prod.ts` | `ng build --configuration production` | OCI API Gateway URL |

Angular CLI replaces imports of `environment.ts` with `environment.prod.ts` during a production build. This is configured in `angular.json` under `configurations.production.fileReplacements`.

**Before deploying to OCI you must update `environment.prod.ts`** with the real API Gateway URL.

#### `frontend/Dockerfile`

```dockerfile
# Stage 1: Build Angular app
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci                      # installs exact versions from package-lock.json
COPY . .
RUN npm run build:prod           # runs: ng build --configuration production

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/frontend-client/browser /usr/share/nginx/html
EXPOSE 80
```

#### `nginx.conf` — Reverse proxy

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Forward /api/* to Spring Boot (strips /api prefix via proxy_pass trailing slash trick)
    location /api/ {
        proxy_pass http://backend-service:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Serve Angular — try the file, then directory, then fall back to index.html
    # The index.html fallback is required for Angular's client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

`backend-service` resolves via Docker's internal DNS — it matches the service name in `docker-compose.yml`.

---

### 3.3 Database (HSQLDB)

HSQLDB in file mode creates three files (here named `filedb.*`):

| File | Content |
|------|---------|
| `filedb.script` | DDL (`CREATE TABLE`) and committed DML (`INSERT`, `UPDATE`) statements |
| `filedb.properties` | Internal state: version, version counter, encoding |
| `filedb.lobs` | Binary large object data (the uploaded file bytes) |

The connection URL `jdbc:hsqldb:file:./filedb;shutdown=true` means:
- `file:` — file-based mode (as opposed to `mem:` for in-memory)
- `./filedb` — file prefix relative to the working directory
- `shutdown=true` — flush and close cleanly when the last connection closes

In Docker, the working directory is the root of the container (`/`), so files land at `/filedb.*`. The Helm chart mounts a PersistentVolume at `/data` and passes an environment variable to override the JDBC URL to `jdbc:hsqldb:file:/data/filedb`.

---

### 3.4 Nginx (Reverse Proxy)

Nginx serves two roles:

1. **Static file server**: Returns `index.html`, `main.js`, `styles.css` for any URL not matching `/api/*`. The `try_files` directive is critical for Angular's client-side routing — if you navigate directly to a route like `/files/123`, the server must return `index.html` (Angular then handles the routing in the browser).

2. **Reverse proxy**: Forwards `/api/*` to the Spring Boot backend. The trailing slash on `proxy_pass http://backend-service:8080/;` causes Nginx to strip `/api` from the upstream request. So `/api/files/upload` becomes `/files/upload` when it reaches Spring Boot.

---

### 3.5 Docker & Docker Compose

#### `docker-compose.yml`

```yaml
version: '3.9'
services:
  backend-service:
    build: ./backend          # build image from backend/Dockerfile
    ports:
      - "8080:8080"          # host:container port mapping
    volumes:
      - hsqldb-data:/data    # named volume persists DB files across restarts
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 5

  frontend-client:
    build: ./frontend
    ports:
      - "4200:80"            # host port 4200 maps to container port 80 (Nginx)
    depends_on:
      backend-service:
        condition: service_healthy   # waits until backend passes health check

volumes:
  hsqldb-data:               # Docker-managed named volume
```

Key concepts:
- **Named volumes** (`hsqldb-data`) persist across `docker-compose down` and `docker-compose up` cycles. Only `docker-compose down -v` removes them.
- **Health check** prevents the frontend from starting before the backend is ready. Without this, Nginx might start proxying before Spring Boot has finished initialising.
- **Container networking**: Docker Compose creates an internal bridge network. Containers reach each other using the service name (e.g., `backend-service`) as the hostname. This is why `nginx.conf` uses `proxy_pass http://backend-service:8080/`.

---

### 3.6 Kubernetes & Helm

#### Helm chart structure

```
deploy/helm/fullstack-app/
├── Chart.yaml          ← chart metadata (name, version)
├── values.yaml         ← default values for all environments
├── values-oci.yaml     ← OCI overrides (images from OCIR, larger resources)
└── templates/
    ├── _helpers.tpl            ← reusable template functions
    ├── backend-pvc.yaml        ← PersistentVolumeClaim for HSQLDB
    ├── backend-deployment.yaml ← Spring Boot Deployment
    ├── backend-service.yaml    ← ClusterIP Service for backend
    ├── frontend-deployment.yaml← Nginx+Angular Deployment
    ├── frontend-service.yaml   ← ClusterIP Service for frontend
    └── frontend-ingress.yaml   ← Ingress (HTTP router to frontend)
```

#### `values.yaml` — Default configuration

```yaml
backend:
  image:
    repository: backend-service
    tag: latest
  replicaCount: 1
  resources:
    requests:
      cpu: 250m      # 0.25 CPU cores
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  hsqldb:
    storage:
      size: 1Gi
      mountPath: /data

frontend:
  image:
    repository: frontend-client
    tag: latest
  replicaCount: 1
  ingress:
    enabled: true
    host: localhost
```

#### `values-oci.yaml` — OCI overrides

```yaml
backend:
  image:
    repository: YOUR_REGION.ocir.io/YOUR_TENANCY_NAMESPACE/file-service
    tag: latest
  replicaCount: 2          # more replicas for production
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  hsqldb:
    storage:
      size: 5Gi
      storageClassName: oci-bv   # OCI Block Volume storage class

frontend:
  replicaCount: 0          # frontend is served from Object Storage, not K8s
  ingress:
    enabled: false         # no ingress needed for frontend in OCI

imagePullSecrets:
  - name: ocir-secret      # K8s secret that holds OCIR credentials
```

#### How Helm templates work

Helm templates are YAML files with Go template syntax. Example from `backend-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fullstack-app.fullname" . }}-backend  # calls helper function
  labels:
    {{- include "fullstack-app.labels" . | nindent 4 }}   # inserts common labels
spec:
  replicas: {{ .Values.backend.replicaCount }}             # substitutes value
  ...
  containers:
    - image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
      resources:
        {{- toYaml .Values.backend.resources | nindent 12 }}  # converts map to YAML
```

`{{ .Values.X }}` reads from `values.yaml` (or your overrides file). `include` calls functions defined in `_helpers.tpl`.

#### Backend Deployment health probes

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30   # wait 30s before first check (Spring Boot startup time)
  periodSeconds: 15

readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 20
  periodSeconds: 10
```

- **Liveness probe**: If this fails, Kubernetes restarts the container.
- **Readiness probe**: If this fails, Kubernetes stops sending traffic to the Pod (but doesn't restart it). A Pod is only added to the Service's load balancer when readiness passes.

---

## 4. Configuration End-to-End

This section traces every configurable value from its source to how it affects the running application.

### HSQLDB path

| Layer | Setting | Value |
|-------|---------|-------|
| `application.properties` | `spring.datasource.url` | `jdbc:hsqldb:file:./filedb` |
| Docker (local) | Volume mount | `hsqldb-data:/data` (but app still uses `./filedb` in container root) |
| Helm `values.yaml` | `backend.hsqldb.storage.mountPath` | `/data` |
| Helm template | `SPRING_DATASOURCE_URL` env var | `jdbc:hsqldb:file:/data/filedb` |
| OCI Helm | `backend.hsqldb.storage.storageClassName` | `oci-bv` (OCI Block Volume) |

In Kubernetes the JDBC URL override is passed as an environment variable, which Spring Boot automatically picks up (environment variables override `application.properties`).

### Upload size limit

| Layer | Setting |
|-------|---------|
| `application.properties` | `spring.servlet.multipart.max-file-size=10MB` |
| Helm | Not overridden — set once in properties |
| OCI API Gateway | Must configure request body size if proxying large files |

### API base URL (frontend)

| Environment | File | `apiUrl` value |
|-------------|------|---------------|
| Local (`ng serve`) | `environment.ts` + `proxy.conf.json` | `/api` → proxied to `localhost:8080` |
| Docker Compose | `environment.ts` built into image | `/api` → Nginx proxies to `backend-service:8080` |
| OCI production | `environment.prod.ts` | `https://YOUR_GATEWAY_ID.apigateway.REGION.oci.customer-oci.com/v1` |

### CORS

CORS (Cross-Origin Resource Sharing) is a browser security mechanism. When JavaScript on `origin-A.com` calls an API on `origin-B.com`, the browser first sends an `OPTIONS` preflight request. The server must respond with the correct `Access-Control-Allow-Origin` header or the browser blocks the request.

| Layer | Config | Allows |
|-------|--------|--------|
| `FileController.java` | `@CrossOrigin(origins = "http://localhost:4200")` | Local dev Angular |
| OCI API Gateway | `api-gateway-spec.json` → `requestPolicies.cors.allowedOrigins` | Object Storage URLs |

**Important**: When deploying to OCI, you must update `api-gateway-spec.json` with the actual Object Storage bucket URL.

### Nginx proxy path rewriting

| Incoming request | Nginx rule | Forwarded to backend as |
|------------------|-----------|------------------------|
| `GET /api/files` | `location /api/ { proxy_pass http://backend-service:8080/; }` | `GET /files` |
| `POST /api/files/upload` | same | `POST /files/upload` |
| `GET /api/files/download/3` | same | `GET /files/download/3` |

The trailing `/` in `proxy_pass` is the key: `proxy_pass http://backend-service:8080/` strips the matched location prefix (`/api/`) and replaces it with `/`.

### Port mapping summary

| Environment | URL you access | How it gets there |
|-------------|---------------|-------------------|
| Local dev | `http://localhost:4200` | Angular CLI dev server, proxies `/api` to `:8080` |
| Local dev | `http://localhost:8080` | Spring Boot directly |
| Docker | `http://localhost:4200` | Host port → Nginx container port 80 |
| Docker | `http://localhost:8080` | Host port → Spring Boot container port 8080 |
| OKE | `http://localhost` | Ingress → frontend Service → Pod port 80 |
| OCI prod | `https://YOUR_BUCKET.objectstorage...` | Object Storage static hosting |
| OCI prod API | `https://YOUR_GATEWAY.apigateway...` | API Gateway → OKE LoadBalancer → Pod 8080 |

---

## 5. Deploying to Oracle Cloud Infrastructure (OCI)

OCI deployment uses:
- **OCI Container Registry (OCIR)** to store the backend Docker image
- **Oracle Kubernetes Engine (OKE)** to run the backend
- **OCI Object Storage** to host the Angular frontend
- **OCI API Gateway** to expose the backend API over HTTPS

### Prerequisites

Install and configure the following tools:

```bash
# OCI CLI
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
oci setup config  # follow prompts: tenancy OCID, user OCID, region, API key

# Docker (24+)
# Helm 3
helm version

# kubectl (for OKE)
# Node 20+ and Angular CLI (for frontend build)
npm install -g @angular/cli
```

You will need the following information from your OCI Console:

| Value | Where to find it |
|-------|-----------------|
| `OCI_REGION` | e.g., `ap-singapore-1` — top right of Console |
| `OCI_TENANCY_NAMESPACE` | Console → Object Storage → Namespace |
| `OCI_USERNAME` | Console → Identity → Users → your user → `oracleidentitycloudservice/email@example.com` |
| `OCI_AUTH_TOKEN` | Console → Identity → Users → your user → Auth Tokens → Generate Token |
| Compartment OCID | Console → Identity → Compartments |

### Step 1 — Build and push Docker images to OCIR

```bash
export OCI_REGION=ap-singapore-1
export OCI_TENANCY_NAMESPACE=your-namespace
export OCI_USERNAME="oracleidentitycloudservice/your@email.com"
export OCI_AUTH_TOKEN="your-auth-token"

./scripts/push-images-oci.sh latest
```

The script does:
1. `docker login YOUR_REGION.ocir.io` using your auth token
2. `docker build` the backend image
3. `docker tag` it as `YOUR_REGION.ocir.io/YOUR_NAMESPACE/file-service:latest`
4. `docker push` to OCIR

Verify in the OCI Console under **Developer Services → Container Registry**.

### Step 2 — Set up OKE cluster access

In the OCI Console:
1. Go to **Developer Services → Kubernetes Clusters (OKE)**
2. Create a cluster or use an existing one
3. Click **Access Cluster** and follow the instructions to update `~/.kube/config`

```bash
# Verify cluster access
kubectl get nodes
```

### Step 3 — Create OCIR image pull secret

Kubernetes needs credentials to pull images from your private OCIR:

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server=YOUR_REGION.ocir.io \
  --docker-username="YOUR_TENANCY_NAMESPACE/YOUR_USERNAME" \
  --docker-password="YOUR_AUTH_TOKEN" \
  --docker-email="your@email.com"
```

This creates a Kubernetes Secret named `ocir-secret`. The `values-oci.yaml` references it under `imagePullSecrets`.

### Step 4 — Update `values-oci.yaml` with your values

Open `deploy/helm/fullstack-app/values-oci.yaml` and replace the placeholders:

```yaml
backend:
  image:
    repository: ap-singapore-1.ocir.io/your-namespace/file-service
    tag: latest
```

### Step 5 — Deploy backend to OKE with Helm

```bash
# Lint the chart first
helm lint ./deploy/helm/fullstack-app

# Preview what will be applied
helm template my-release ./deploy/helm/fullstack-app -f deploy/helm/fullstack-app/values-oci.yaml

# Install
helm install my-release ./deploy/helm/fullstack-app \
  -f deploy/helm/fullstack-app/values-oci.yaml

# Verify pods are running
kubectl get pods
kubectl get services
```

The backend Service will be a **LoadBalancer** type in OCI, which provisions an OCI Load Balancer automatically. Get its public IP:

```bash
kubectl get service my-release-fullstack-app-backend
# Note the EXTERNAL-IP — this is FILE_SERVICE_LB_IP
```

Wait a few minutes for the Load Balancer to be provisioned.

### Step 6 — Create OCI API Gateway

1. In the OCI Console, go to **Developer Services → API Management → Gateways**
2. Create a Gateway in a public subnet
3. Create a **Deployment** on the gateway with path prefix `/v1`
4. Open `deploy/oci/api-gateway-spec.json` and replace `FILE_SERVICE_LB_IP` with the OKE LoadBalancer IP from Step 5
5. Import the spec into your API Gateway deployment

After creation, note the **Endpoint URL** — it looks like:
```
https://XXXXXXXXXXXXXXXX.apigateway.ap-singapore-1.oci.customer-oci.com/v1
```

### Step 7 — Update Angular environment and update CORS

**Update `frontend/src/environments/environment.prod.ts`**:

```typescript
export const environment = {
  production: true,
  apiUrl: 'https://XXXXXXXXXXXXXXXX.apigateway.ap-singapore-1.oci.customer-oci.com/v1'
};
```

**Update `deploy/oci/api-gateway-spec.json` CORS origins** with your Object Storage bucket URL (you'll get this after Step 8 — you may need to do Steps 7 and 8 iteratively).

### Step 8 — Deploy Angular frontend to Object Storage

Create a public bucket in OCI Object Storage:
1. Console → **Storage → Object Storage → Buckets**
2. Create Bucket, set visibility to **Public**
3. Enable **Static Website Hosting** on the bucket

Then deploy:

```bash
export OCI_NAMESPACE=your-namespace
export OCI_BUCKET=your-bucket-name
export OCI_REGION=ap-singapore-1

./scripts/deploy-frontend-oci.sh
```

The script:
1. Runs `ng build --configuration production` (uses `environment.prod.ts`)
2. Uploads all files to Object Storage with correct `Content-Type` headers (html, js, css, json, ico, png, svg, woff2)
3. Outputs the Object Storage URL

The bucket URL format is:
```
https://objectstorage.REGION.oraclecloud.com/n/NAMESPACE/b/BUCKET/o/index.html
```

### Step 9 — Update CORS and re-deploy API Gateway

Update `deploy/oci/api-gateway-spec.json` with the actual Object Storage URL:

```json
"cors": {
  "allowedOrigins": [
    "https://objectstorage.ap-singapore-1.oraclecloud.com",
    "https://your-bucket.objectstorage.ap-singapore-1.oci.customer-oci.com"
  ]
}
```

Re-import the spec into your API Gateway deployment.

### Step 10 — Verify end-to-end

```bash
# Check backend health via API Gateway
curl https://YOUR_GATEWAY.apigateway.REGION.oci.customer-oci.com/v1/actuator/health

# Open the frontend
open https://objectstorage.REGION.oraclecloud.com/n/NAMESPACE/b/BUCKET/o/index.html
```

### Upgrading the application

When you push code changes:

```bash
# Rebuild and push new image (with a version tag, not latest)
./scripts/push-images-oci.sh 1.1.0

# Upgrade the Helm release
helm upgrade my-release ./deploy/helm/fullstack-app \
  -f deploy/helm/fullstack-app/values-oci.yaml \
  --set backend.image.tag=1.1.0
```

Helm performs a rolling update — it starts new Pods with the new image before terminating old ones, ensuring zero downtime.

For frontend-only changes:

```bash
# Rebuild and re-upload to Object Storage
./scripts/deploy-frontend-oci.sh
```

### Uninstalling from OKE

```bash
helm uninstall my-release

# This does NOT delete the PVC (to protect data)
# To also delete HSQLDB data:
kubectl delete pvc -l app.kubernetes.io/instance=my-release
```

---

## Quick Reference

### Local development commands

```bash
# Backend only
cd backend && mvn spring-boot:run

# Frontend only (proxies /api to localhost:8080)
cd frontend && ng serve --proxy-config proxy.conf.json

# Both via Docker
docker compose up --build -d
docker compose logs -f
docker compose down
docker compose down -v  # also remove DB volume
```

### Kubernetes commands

```bash
helm lint ./deploy/helm/fullstack-app
helm install my-release ./deploy/helm/fullstack-app
helm upgrade my-release ./deploy/helm/fullstack-app --set backend.image.tag=1.1.0
helm uninstall my-release

kubectl get pods
kubectl get services
kubectl logs -l app=backend -f
kubectl describe pod POD_NAME
```

### API quick test

```bash
# Health
curl http://localhost:8080/actuator/health

# Upload
curl -X POST http://localhost:8080/files/upload -F "file=@./README.md"

# List
curl http://localhost:8080/files

# Download (replace 1 with actual id)
curl -O -J http://localhost:8080/files/download/1
```
