# 🚀 supOS-CE Containerization ve Deployment Stratejisi

## 📋 Genel Bakış

Bu doküman, supOS-CE platformunun üç ana repository'sini (supOS-CE, supOS-backend, supOS-frontend) containerize edip deploy etme stratejisini detaylandırır.

## 🎯 Hedefler

1. **Backend ve Frontend'i ayrı ayrı derleyip Docker image'larına dönüştürme**
2. **Local Docker Registry kullanarak image yönetimi**
3. **supOS-CE docker-compose ile tüm stack'i orchestrate etme**
4. **Otomatik build ve deployment pipeline oluşturma**
5. **Development ve Production environment'ları ayırma**

---

## 🏗️ Mimari Yaklaşım

### Repository İlişkisi

```
┌─────────────────────────────────────────────────┐
│             supOS-CE (Orchestrator)             │
│                                                  │
│  - docker-compose.yml                           │
│  - Environment configuration (.env)             │
│  - Infrastructure services (PostgreSQL, EMQX)   │
│  - Volume mounts                                │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    ┌────▼─────┐     ┌─────▼────┐
    │ Backend  │     │ Frontend │
    │  Image   │     │  Image   │
    └──────────┘     └──────────┘
         │                 │
    Built from         Built from
         │                 │
    ┌────▼─────┐     ┌─────▼────┐
    │ supOS-   │     │ supOS-   │
    │ backend  │     │ frontend │
    └──────────┘     └──────────┘
```

### Deployment Modeli

**Seçenek 1: Monolithic Deployment (Önerilen - Başlangıç için)**
- Tüm servisler tek bir sunucuda
- docker-compose ile orchestration
- Kolay yönetim ve debug
- Development ve small production için uygun

**Seçenek 2: Distributed Deployment (Production - İleri düzey)**
- Frontend, Backend ve Infrastructure ayrı sunucularda
- Kubernetes veya Docker Swarm ile orchestration
- Yüksek erişilebilirlik ve ölçeklenebilirlik
- Enterprise production için uygun

---

## 📦 Build Stratejisi

### Phase 1: Backend Build

#### Gereksinimler
- Java JDK 17+
- Maven 3.8+
- Docker Engine 20.10+

#### Build Adımları

```bash
# 1. Repository'ye git
cd /home/user/supOS-backend

# 2. Clean install (tüm modüller)
mvn clean install -DskipTests

# 3. JAR doğrulama
ls -lh bootstrap/target/bootstrap.jar

# 4. Docker image build
docker build -t supos-backend:latest -f Dockerfile .

# 5. Image verification
docker images | grep supos-backend

# 6. Tag for local registry (opsiyonel)
docker tag supos-backend:latest localhost:5000/supos-backend:1.0.11
```

#### Build Time Optimization

```bash
# Maven dependency caching
mvn dependency:go-offline

# Parallel build
mvn clean install -T 1C -DskipTests

# Build specific module only
mvn clean install -pl bootstrap -am -DskipTests
```

#### Dockerfile Best Practices

```dockerfile
# Multi-stage build for smaller image
FROM maven:3.8-amazoncorretto-17 AS builder
WORKDIR /build

# Cache dependencies layer
COPY pom.xml .
COPY */pom.xml ./
RUN mvn dependency:go-offline

# Build application
COPY . .
RUN mvn clean install -DskipTests -T 1C

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy only JAR
COPY --from=builder /build/bootstrap/target/bootstrap.jar app.jar

# JVM optimization
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

EXPOSE 8080 8091 19099

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

---

### Phase 2: Frontend Build

#### Gereksinimler
- Node.js 18+ LTS
- pnpm 8+
- Docker Engine 20.10+

#### Build Adımları

```bash
# 1. Repository'ye git
cd /home/user/supOS-frontend

# 2. Install dependencies
pnpm install --frozen-lockfile

# 3. Build production bundle
pnpm build

# 4. Verify build output
ls -lh build/

# 5. Docker image build
docker build -t supos-frontend:latest -f Dockerfile .

# 6. Image verification
docker images | grep supos-frontend

# 7. Tag for local registry (opsiyonel)
docker tag supos-frontend:latest localhost:5000/supos-frontend:1.0.11
```

#### Build Optimization

```bash
# Use pnpm store for faster install
pnpm config set store-dir ~/.pnpm-store

# Production build with optimization
pnpm build --mode production

# Analyze bundle size
pnpm build --analyze
```

#### Dockerfile Best Practices

```dockerfile
# Multi-stage build
FROM node:18-alpine AS builder
WORKDIR /build

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Cache dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Build app
COPY . .
RUN pnpm build

# Runtime stage with nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Copy built files
COPY --from=builder /build/build ./

# Custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

---

### Phase 3: Integration with supOS-CE

#### Docker Compose Configuration

```yaml
# docker-compose-local.yml
version: '3.8'

services:
  # Backend service
  backend:
    image: supos-backend:latest
    container_name: supos-backend
    ports:
      - "8091:8091"
      - "8080:8080"
      - "19099:19099"
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - POSTGRES_HOST=postgresql
      - POSTGRES_PORT=5432
      - KEYCLOAK_HOST=keycloak
      - EMQX_HOST=emqx
    volumes:
      - ./mount/backend/apps:/apps
      - ./mount/backend/log:/logs
      - ./mount/backend/uns:/uns
    depends_on:
      - postgresql
      - keycloak
      - emqx
    networks:
      - supos_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Frontend service
  frontend:
    image: supos-frontend:latest
    container_name: supos-frontend
    ports:
      - "3000:80"
    environment:
      - REACT_APP_API_URL=http://kong:8088
      - REACT_APP_KEYCLOAK_URL=http://keycloak:8081
    volumes:
      - ./mount/frontend/plugins:/app/plugins
    depends_on:
      - backend
      - kong
    networks:
      - supos_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ... (diğer infrastructure services)

networks:
  supos_network:
    driver: bridge

volumes:
  postgres_data:
  tsdb_data:
  emqx_data:
```

---

## 🔧 Otomatik Build Script

### build-all.sh

```bash
#!/bin/bash

# supOS-CE Platform Build Script
# Builds Backend, Frontend and deploys with docker-compose

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/home/user"
BACKEND_DIR="$BASE_DIR/supOS-backend"
FRONTEND_DIR="$BASE_DIR/supOS-frontend"
CE_DIR="$BASE_DIR/supOS-CE"

BACKEND_IMAGE="supos-backend:latest"
FRONTEND_IMAGE="supos-frontend:latest"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi

    # Check Maven
    if ! command -v mvn &> /dev/null; then
        log_error "Maven not found. Please install Maven."
        exit 1
    fi

    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js."
        exit 1
    fi

    # Check pnpm
    if ! command -v pnpm &> /dev/null; then
        log_error "pnpm not found. Installing pnpm..."
        npm install -g pnpm
    fi

    log_info "All prerequisites satisfied."
}

build_backend() {
    log_info "Building Backend..."

    cd "$BACKEND_DIR"

    # Maven clean install
    log_info "Running Maven clean install..."
    mvn clean install -DskipTests -T 1C

    if [ $? -ne 0 ]; then
        log_error "Maven build failed!"
        exit 1
    fi

    # Verify JAR
    if [ ! -f "bootstrap/target/bootstrap.jar" ]; then
        log_error "bootstrap.jar not found!"
        exit 1
    fi

    log_info "Maven build successful."

    # Docker build
    log_info "Building Docker image..."
    docker build -t "$BACKEND_IMAGE" -f Dockerfile .

    if [ $? -ne 0 ]; then
        log_error "Docker build failed!"
        exit 1
    fi

    log_info "Backend Docker image built successfully: $BACKEND_IMAGE"
}

build_frontend() {
    log_info "Building Frontend..."

    cd "$FRONTEND_DIR"

    # Install dependencies
    log_info "Installing dependencies with pnpm..."
    pnpm install --frozen-lockfile

    if [ $? -ne 0 ]; then
        log_error "pnpm install failed!"
        exit 1
    fi

    # Build production bundle
    log_info "Building production bundle..."
    pnpm build

    if [ $? -ne 0 ]; then
        log_error "Frontend build failed!"
        exit 1
    fi

    # Verify build output
    if [ ! -d "build" ]; then
        log_error "Build directory not found!"
        exit 1
    fi

    log_info "Frontend build successful."

    # Docker build
    log_info "Building Docker image..."
    docker build -t "$FRONTEND_IMAGE" -f Dockerfile .

    if [ $? -ne 0 ]; then
        log_error "Docker build failed!"
        exit 1
    fi

    log_info "Frontend Docker image built successfully: $FRONTEND_IMAGE"
}

deploy_stack() {
    log_info "Deploying supOS-CE stack..."

    cd "$CE_DIR"

    # Check if .env exists
    if [ ! -f ".env" ]; then
        log_error ".env file not found! Please configure .env first."
        exit 1
    fi

    # Stop existing containers
    log_info "Stopping existing containers..."
    docker-compose down

    # Start stack
    log_info "Starting Docker Compose stack..."
    docker-compose -f docker-compose-4c8g.yml up -d

    if [ $? -ne 0 ]; then
        log_error "Docker Compose up failed!"
        exit 1
    fi

    log_info "supOS-CE stack deployed successfully."
}

verify_deployment() {
    log_info "Verifying deployment..."

    # Wait for services to start
    sleep 10

    # Check container status
    log_info "Container status:"
    docker-compose ps

    # Health checks
    log_info "Performing health checks..."

    # Check backend
    if curl -f http://localhost:8091/actuator/health &> /dev/null; then
        log_info "✓ Backend is healthy"
    else
        log_warn "✗ Backend health check failed"
    fi

    # Check frontend
    if curl -f http://localhost:3000 &> /dev/null; then
        log_info "✓ Frontend is accessible"
    else
        log_warn "✗ Frontend accessibility check failed"
    fi

    # Check Kong gateway
    if curl -f http://localhost:8088 &> /dev/null; then
        log_info "✓ Kong Gateway is accessible"
    else
        log_warn "✗ Kong Gateway check failed"
    fi
}

show_summary() {
    log_info "==========================================="
    log_info "supOS-CE Platform Build & Deploy Complete"
    log_info "==========================================="
    echo ""
    log_info "Access URLs:"
    echo "  - Frontend:  http://localhost:8088/home"
    echo "  - Backend:   http://localhost:8091"
    echo "  - Kong:      http://localhost:8088"
    echo "  - Keycloak:  http://localhost:8081"
    echo "  - Grafana:   http://localhost:3000"
    echo "  - Node-RED:  http://localhost:1880"
    echo ""
    log_info "Default credentials: supos / supos"
    echo ""
    log_info "View logs: docker-compose logs -f"
    log_info "Stop stack: docker-compose down"
}

# Main execution
main() {
    log_info "Starting supOS-CE Build & Deploy Process..."
    echo ""

    check_prerequisites
    echo ""

    # Build backend
    build_backend
    echo ""

    # Build frontend
    build_frontend
    echo ""

    # Deploy stack
    deploy_stack
    echo ""

    # Verify deployment
    verify_deployment
    echo ""

    # Show summary
    show_summary
}

# Run main function
main
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy supOS-CE

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build-backend:
    name: Build Backend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean install -DskipTests -T 1C

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: ./backend
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/supos-backend:latest
            ${{ secrets.DOCKER_USERNAME }}/supos-backend:${{ github.sha }}
          cache-from: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/supos-backend:buildcache
          cache-to: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/supos-backend:buildcache,mode=max

  build-frontend:
    name: Build Frontend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 8

      - name: Get pnpm store directory
        id: pnpm-cache
        shell: bash
        run: |
          echo "STORE_PATH=$(pnpm store path)" >> $GITHUB_OUTPUT

      - name: Setup pnpm cache
        uses: actions/cache@v3
        with:
          path: ${{ steps.pnpm-cache.outputs.STORE_PATH }}
          key: ${{ runner.os }}-pnpm-store-${{ hashFiles('**/pnpm-lock.yaml') }}
          restore-keys: |
            ${{ runner.os }}-pnpm-store-

      - name: Install dependencies
        working-directory: ./frontend
        run: pnpm install --frozen-lockfile

      - name: Build frontend
        working-directory: ./frontend
        run: pnpm build

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: ./frontend
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/supos-frontend:latest
            ${{ secrets.DOCKER_USERNAME }}/supos-frontend:${{ github.sha }}
          cache-from: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/supos-frontend:buildcache
          cache-to: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/supos-frontend:buildcache,mode=max

  deploy:
    name: Deploy Stack
    needs: [build-backend, build-frontend]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to production
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USERNAME }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/supos-ce
            docker-compose pull
            docker-compose up -d
            docker-compose ps
```

---

## 📊 Monitoring ve Logging

### Prometheus Metrics

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8080']
    metrics_path: '/actuator/prometheus'

  - job_name: 'kong'
    static_configs:
      - targets: ['kong:8001']

  - job_name: 'emqx'
    static_configs:
      - targets: ['emqx:18083']
```

### Logging Stack

```yaml
# docker-compose-logging.yml
version: '3.8'

services:
  # Loki for log aggregation
  loki:
    image: grafana/loki:2.9.0
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - supos_network

  # Promtail for log collection
  promtail:
    image: grafana/promtail:2.9.0
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - supos_network

  # Grafana for visualization
  grafana:
    image: grafana/grafana:11.4.0
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - supos_network

networks:
  supos_network:
    external: true

volumes:
  grafana_data:
```

---

## 🔒 Security Considerations

### Docker Security Best Practices

1. **Non-root User**
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

2. **Read-only Filesystem**
```yaml
services:
  backend:
    read_only: true
    tmpfs:
      - /tmp
```

3. **Resource Limits**
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 3G
        reservations:
          cpus: '1'
          memory: 512M
```

4. **Network Isolation**
```yaml
networks:
  frontend_network:
    internal: false
  backend_network:
    internal: true
```

5. **Secrets Management**
```yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt

services:
  backend:
    secrets:
      - postgres_password
```

---

## 📝 Troubleshooting Guide

### Common Issues

#### 1. Backend Build Fails

```bash
# Clean Maven cache
rm -rf ~/.m2/repository

# Retry with verbose logging
mvn clean install -X

# Check Java version
java -version  # Should be 17+
```

#### 2. Frontend Build Out of Memory

```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=4096"

# Retry build
pnpm build
```

#### 3. Container Won't Start

```bash
# Check logs
docker logs <container_name>

# Check network connectivity
docker network inspect supos_network

# Check port conflicts
netstat -tuln | grep <port>
```

#### 4. Database Connection Issues

```bash
# Test PostgreSQL connection
docker exec -it postgresql psql -U postgres -d postgres

# Check backend logs for connection errors
docker logs supos-backend | grep -i "connection"
```

#### 5. Permission Issues

```bash
# Fix volume permissions
sudo chown -R 1000:1000 ./mount

# Check SELinux contexts (if applicable)
ls -Z ./mount
```

---

## ✅ Pre-deployment Checklist

- [ ] Docker Engine 20.10+ installed
- [ ] Docker Compose 2.0+ installed
- [ ] Java JDK 17+ installed
- [ ] Maven 3.8+ installed
- [ ] Node.js 18+ LTS installed
- [ ] pnpm 8+ installed
- [ ] Sufficient disk space (100GB+)
- [ ] Sufficient memory (8GB+)
- [ ] Required ports available (8088, 5432, 1883, etc.)
- [ ] .env file configured correctly
- [ ] Volume directories created
- [ ] Firewall rules configured
- [ ] SSL certificates ready (if using HTTPS)
- [ ] Database backup strategy in place

---

## 🎯 Next Steps

1. **Execute Build Script**
   ```bash
   chmod +x build-all.sh
   ./build-all.sh
   ```

2. **Verify Deployment**
   - Access frontend: http://localhost:8088/home
   - Login with: supos / supos
   - Check all services are running

3. **Configure Production Settings**
   - Update .env with production values
   - Configure SSL/TLS
   - Setup monitoring and alerts
   - Configure backup jobs

4. **Performance Tuning**
   - Adjust JVM memory settings
   - Configure database connection pool
   - Optimize nginx cache settings
   - Setup CDN for static assets

5. **Documentation**
   - Document custom configurations
   - Create runbooks for operations team
   - Setup incident response procedures

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker)
- [React Deployment Guide](https://create-react-app.dev/docs/deployment/)
- [Kong Gateway Documentation](https://docs.konghq.com/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

---

**Last Updated:** 2025-11-06
**Version:** 1.0
**Author:** supOS-CE Platform Team
