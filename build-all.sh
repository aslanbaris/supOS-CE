#!/bin/bash

# supOS-CE Platform Build Script
# Builds Backend, Frontend and deploys with docker-compose

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/home/user"
BACKEND_DIR="$BASE_DIR/supOS-backend"
FRONTEND_DIR="$BASE_DIR/supOS-frontend"
CE_DIR="$BASE_DIR/supOS-CE"

BACKEND_IMAGE="supos-backend:latest"
FRONTEND_IMAGE="supos-frontend:latest"

# Parse command line arguments
SKIP_BACKEND=false
SKIP_FRONTEND=false
SKIP_DEPLOY=false
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backend)
            SKIP_BACKEND=true
            shift
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-backend    Skip backend build"
            echo "  --skip-frontend   Skip frontend build"
            echo "  --skip-deploy     Skip deployment"
            echo "  --clean           Clean build (remove all caches)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Functions
print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}supOS-CE Platform Build & Deploy Script${NC}      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}Version 1.0.0${NC}                                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶${NC} ${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_prerequisites() {
    log_step "Checking Prerequisites"

    local missing_prereqs=false

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        missing_prereqs=true
    else
        local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "Docker version: $docker_version"
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose."
        missing_prereqs=true
    else
        local compose_version=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "Docker Compose version: $compose_version"
    fi

    # Check Maven
    if ! command -v mvn &> /dev/null; then
        log_error "Maven not found. Please install Maven."
        missing_prereqs=true
    else
        local maven_version=$(mvn --version | grep "Apache Maven" | grep -oP '\d+\.\d+\.\d+')
        log_info "Maven version: $maven_version"
    fi

    # Check Java
    if ! command -v java &> /dev/null; then
        log_error "Java not found. Please install Java JDK 17+."
        missing_prereqs=true
    else
        local java_version=$(java -version 2>&1 | grep -oP 'version "\K[^"]+' | head -1)
        log_info "Java version: $java_version"
    fi

    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js 18+."
        missing_prereqs=true
    else
        local node_version=$(node --version)
        log_info "Node.js version: $node_version"
    fi

    # Check pnpm
    if ! command -v pnpm &> /dev/null; then
        log_warn "pnpm not found. Installing pnpm..."
        npm install -g pnpm
    else
        local pnpm_version=$(pnpm --version)
        log_info "pnpm version: $pnpm_version"
    fi

    if [ "$missing_prereqs" = true ]; then
        log_error "Missing prerequisites. Please install required tools."
        exit 1
    fi

    log_info "✓ All prerequisites satisfied."
}

check_disk_space() {
    log_info "Checking disk space..."

    local available_space=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

    if [ "$available_space" -lt 20 ]; then
        log_error "Insufficient disk space. At least 20GB required, available: ${available_space}GB"
        exit 1
    fi

    log_info "✓ Available disk space: ${available_space}GB"
}

clean_build_cache() {
    if [ "$CLEAN_BUILD" = true ]; then
        log_step "Cleaning Build Cache"

        log_info "Cleaning Maven cache..."
        rm -rf ~/.m2/repository

        log_info "Cleaning pnpm cache..."
        pnpm store prune

        log_info "Cleaning Docker build cache..."
        docker builder prune -af

        log_info "✓ Build cache cleaned."
    fi
}

build_backend() {
    if [ "$SKIP_BACKEND" = true ]; then
        log_warn "Skipping backend build (--skip-backend)"
        return 0
    fi

    log_step "Building Backend"

    cd "$BACKEND_DIR"

    # Check if directory exists
    if [ ! -d "$BACKEND_DIR" ]; then
        log_error "Backend directory not found: $BACKEND_DIR"
        exit 1
    fi

    # Maven clean install
    log_info "Running Maven clean install..."
    log_info "This may take several minutes..."

    if mvn clean install -DskipTests -T 1C; then
        log_info "✓ Maven build successful."
    else
        log_error "✗ Maven build failed!"
        exit 1
    fi

    # Verify JAR
    if [ ! -f "bootstrap/target/bootstrap.jar" ]; then
        log_error "✗ bootstrap.jar not found!"
        exit 1
    fi

    local jar_size=$(du -h bootstrap/target/bootstrap.jar | cut -f1)
    log_info "✓ bootstrap.jar size: $jar_size"

    # Docker build
    log_info "Building Docker image: $BACKEND_IMAGE"

    if docker build -t "$BACKEND_IMAGE" -f Dockerfile .; then
        log_info "✓ Backend Docker image built successfully."
    else
        log_error "✗ Docker build failed!"
        exit 1
    fi

    # Show image size
    local image_size=$(docker images "$BACKEND_IMAGE" --format "{{.Size}}")
    log_info "✓ Image size: $image_size"
}

build_frontend() {
    if [ "$SKIP_FRONTEND" = true ]; then
        log_warn "Skipping frontend build (--skip-frontend)"
        return 0
    fi

    log_step "Building Frontend"

    cd "$FRONTEND_DIR"

    # Check if directory exists
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "Frontend directory not found: $FRONTEND_DIR"
        exit 1
    fi

    # Install dependencies
    log_info "Installing dependencies with pnpm..."
    log_info "This may take several minutes..."

    if pnpm install --frozen-lockfile; then
        log_info "✓ Dependencies installed successfully."
    else
        log_error "✗ pnpm install failed!"
        exit 1
    fi

    # Build production bundle
    log_info "Building production bundle..."

    if pnpm build; then
        log_info "✓ Frontend build successful."
    else
        log_error "✗ Frontend build failed!"
        exit 1
    fi

    # Verify build output
    if [ ! -d "build" ]; then
        log_error "✗ Build directory not found!"
        exit 1
    fi

    local build_size=$(du -sh build | cut -f1)
    log_info "✓ Build directory size: $build_size"

    # Docker build
    log_info "Building Docker image: $FRONTEND_IMAGE"

    if docker build -t "$FRONTEND_IMAGE" -f Dockerfile .; then
        log_info "✓ Frontend Docker image built successfully."
    else
        log_error "✗ Docker build failed!"
        exit 1
    fi

    # Show image size
    local image_size=$(docker images "$FRONTEND_IMAGE" --format "{{.Size}}")
    log_info "✓ Image size: $image_size"
}

update_docker_compose() {
    log_info "Updating docker-compose configuration..."

    cd "$CE_DIR"

    # Backup original docker-compose file
    if [ ! -f "docker-compose-4c8g.yml.backup" ]; then
        cp docker-compose-4c8g.yml docker-compose-4c8g.yml.backup
        log_info "✓ Backup created: docker-compose-4c8g.yml.backup"
    fi

    log_info "✓ Docker compose configuration ready."
}

deploy_stack() {
    if [ "$SKIP_DEPLOY" = true ]; then
        log_warn "Skipping deployment (--skip-deploy)"
        return 0
    fi

    log_step "Deploying supOS-CE Stack"

    cd "$CE_DIR"

    # Check if .env exists
    if [ ! -f ".env" ]; then
        log_error "✗ .env file not found! Please configure .env first."
        log_info "You can copy from .env.example if available."
        exit 1
    fi

    # Stop existing containers
    log_info "Stopping existing containers..."
    docker-compose down || true

    # Start stack
    log_info "Starting Docker Compose stack..."
    log_info "This will start all services defined in docker-compose-4c8g.yml"

    if docker-compose -f docker-compose-4c8g.yml up -d; then
        log_info "✓ supOS-CE stack deployed successfully."
    else
        log_error "✗ Docker Compose up failed!"
        exit 1
    fi

    # Wait for services to initialize
    log_info "Waiting for services to initialize (30 seconds)..."
    sleep 30
}

verify_deployment() {
    log_step "Verifying Deployment"

    cd "$CE_DIR"

    # Check container status
    log_info "Container status:"
    docker-compose ps

    echo ""
    log_info "Performing health checks..."

    local health_check_failed=false

    # Check backend
    log_info "Checking backend health..."
    if curl -sf http://localhost:8091/actuator/health > /dev/null 2>&1; then
        log_info "✓ Backend is healthy"
    else
        log_warn "✗ Backend health check failed (may still be starting up)"
        health_check_failed=true
    fi

    # Check frontend
    log_info "Checking frontend accessibility..."
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        log_info "✓ Frontend is accessible"
    else
        log_warn "✗ Frontend accessibility check failed (may still be starting up)"
        health_check_failed=true
    fi

    # Check Kong gateway
    log_info "Checking Kong Gateway..."
    if curl -sf http://localhost:8088 > /dev/null 2>&1; then
        log_info "✓ Kong Gateway is accessible"
    else
        log_warn "✗ Kong Gateway check failed (may still be starting up)"
        health_check_failed=true
    fi

    # Check PostgreSQL
    log_info "Checking PostgreSQL..."
    if docker exec postgresql pg_isready -U postgres > /dev/null 2>&1; then
        log_info "✓ PostgreSQL is ready"
    else
        log_warn "✗ PostgreSQL check failed"
        health_check_failed=true
    fi

    if [ "$health_check_failed" = true ]; then
        echo ""
        log_warn "Some health checks failed. Services may still be starting up."
        log_info "Wait a few minutes and check logs: docker-compose logs -f"
    fi
}

show_summary() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}supOS-CE Platform Build & Deploy Complete!${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "🌐 Access URLs:"
    echo ""
    echo "  🏠 Frontend (Web UI):     http://localhost:8088/home"
    echo "  ⚙️  Backend API:          http://localhost:8091"
    echo "  🚪 Kong Gateway:          http://localhost:8088"
    echo "  🔐 Keycloak (Auth):       http://localhost:8081"
    echo "  📊 Grafana:               http://localhost:3000"
    echo "  🔄 Node-RED (Source):     http://localhost:1880"
    echo "  ⚡ Event Flow:            http://localhost:1889"
    echo "  📮 EMQX Dashboard:        http://localhost:18083"
    echo "  🐳 Portainer:             https://localhost:9443"
    echo ""

    log_info "🔑 Default Credentials:"
    echo "  Username: supos"
    echo "  Password: supos"
    echo ""

    log_info "📋 Useful Commands:"
    echo "  View all logs:        docker-compose logs -f"
    echo "  View backend logs:    docker-compose logs -f backend"
    echo "  View frontend logs:   docker-compose logs -f frontend"
    echo "  Check status:         docker-compose ps"
    echo "  Stop stack:           docker-compose down"
    echo "  Restart service:      docker-compose restart <service_name>"
    echo ""

    log_info "📚 Documentation:"
    echo "  Architecture:         file://$(pwd)/supos-architecture-documentation.html"
    echo "  Strategy:             file://$(pwd)/containerization-strategy.md"
    echo ""

    if [ "$SKIP_DEPLOY" = false ]; then
        log_info "✅ Deployment is complete. You can now access the platform!"
    else
        log_warn "⚠️  Deployment was skipped. Run without --skip-deploy to deploy."
    fi
}

show_build_time() {
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    log_info "⏱️  Total build time: ${minutes}m ${seconds}s"
}

# Main execution
main() {
    local start_time=$(date +%s)

    print_banner

    log_info "Build configuration:"
    echo "  Skip Backend:  $SKIP_BACKEND"
    echo "  Skip Frontend: $SKIP_FRONTEND"
    echo "  Skip Deploy:   $SKIP_DEPLOY"
    echo "  Clean Build:   $CLEAN_BUILD"
    echo ""

    check_prerequisites
    check_disk_space
    clean_build_cache

    # Build backend
    if [ "$SKIP_BACKEND" = false ]; then
        build_backend
    fi

    # Build frontend
    if [ "$SKIP_FRONTEND" = false ]; then
        build_frontend
    fi

    # Update compose config
    update_docker_compose

    # Deploy stack
    if [ "$SKIP_DEPLOY" = false ]; then
        deploy_stack
        verify_deployment
    fi

    # Show summary
    show_summary
    show_build_time

    log_info "🎉 All done!"
}

# Trap errors
trap 'log_error "Build script failed at line $LINENO. Check the logs above."; exit 1' ERR

# Run main function
main "$@"
