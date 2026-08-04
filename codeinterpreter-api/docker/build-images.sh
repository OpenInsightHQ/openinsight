#!/bin/bash
# Build script for Code Interpreter execution environment images
# Supports BuildKit caching and parallel builds

set -e

# Enable BuildKit for better caching (override with env vars if needed)
: "${DOCKER_BUILDKIT:=1}"
: "${BUILDKIT_PROGRESS:=plain}"
export DOCKER_BUILDKIT
export BUILDKIT_PROGRESS

# Configuration
REGISTRY=${REGISTRY:-"code-interpreter"}
VERSION=${VERSION:-"latest"}
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
SINGLE_LANGUAGE=""
PARALLEL_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_timing() {
    echo -e "${CYAN}[TIMING]${NC} $1"
}

# Build function with timing
build_image() {
    local language=$1
    local dockerfile=$2
    local image_name="${REGISTRY}/${language}:${VERSION}"
    local start_time=$(date +%s)

    log_info "Building ${language} execution environment..."

    if docker build \
        --file "${dockerfile}" \
        --tag "${image_name}" \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg VERSION="${VERSION}" \
        --build-arg VCS_REF="${VCS_REF}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --label "org.opencontainers.image.title=Code Interpreter ${language^} Environment" \
        --label "org.opencontainers.image.description=Secure execution environment for ${language} code" \
        --label "org.opencontainers.image.version=${VERSION}" \
        --label "org.opencontainers.image.created=${BUILD_DATE}" \
        --label "org.opencontainers.image.revision=${VCS_REF}" \
        .; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Built ${image_name} in ${duration}s"
        return 0
    else
        log_error "Failed to build ${image_name}"
        return 1
    fi
}

# Parallel build function
build_all_parallel() {
    local pids=()
    local languages=("python" "nodejs" "go" "java" "c-cpp" "php" "rust" "fortran" "r" "d")
    local dockerfiles=("python.Dockerfile" "nodejs.Dockerfile" "go.Dockerfile" "java.Dockerfile" "c-cpp.Dockerfile" "php.Dockerfile" "rust.Dockerfile" "fortran.Dockerfile" "r.Dockerfile" "d.Dockerfile")
    local log_dir="/tmp/code-interpreter-build-$$"

    mkdir -p "${log_dir}"

    log_info "Starting parallel builds for ${#languages[@]} images..."
    log_info "Build logs in: ${log_dir}"
    echo

    local start_time=$(date +%s)

    for i in "${!languages[@]}"; do
        local lang="${languages[$i]}"
        local dockerfile="${dockerfiles[$i]}"
        (
            build_image "${lang}" "${dockerfile}" > "${log_dir}/${lang}.log" 2>&1
            echo $? > "${log_dir}/${lang}.exit"
        ) &
        pids+=($!)
        log_info "Started build for ${lang} (PID: $!)"
    done

    echo
    log_info "Waiting for all builds to complete..."

    # Wait for all builds
    local failed=()
    for i in "${!pids[@]}"; do
        local lang="${languages[$i]}"
        wait "${pids[$i]}" 2>/dev/null || true
        local exit_code=$(cat "${log_dir}/${lang}.exit" 2>/dev/null || echo "1")
        if [ "${exit_code}" != "0" ]; then
            failed+=("${lang}")
            log_error "${lang} build failed"
        else
            log_success "${lang} build completed"
        fi
    done

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo
    log_timing "Total parallel build time: ${total_duration}s"

    # Show logs for failed builds
    if [ ${#failed[@]} -gt 0 ]; then
        echo
        log_error "Failed builds: ${failed[*]}"
        for lang in "${failed[@]}"; do
            echo
            log_error "=== ${lang} build log ==="
            cat "${log_dir}/${lang}.log"
        done
        rm -rf "${log_dir}"
        return 1
    fi

    rm -rf "${log_dir}"
    log_success "All parallel builds completed in ${total_duration}s"
    return 0
}

# Sequential build function
build_all_sequential() {
    local failed_builds=()
    local start_time=$(date +%s)

    # Python
    if ! build_image "python" "python.Dockerfile"; then
        failed_builds+=("python")
    fi

    # Node.js
    if ! build_image "nodejs" "nodejs.Dockerfile"; then
        failed_builds+=("nodejs")
    fi

    # Go
    if ! build_image "go" "go.Dockerfile"; then
        failed_builds+=("go")
    fi

    # Java
    if ! build_image "java" "java.Dockerfile"; then
        failed_builds+=("java")
    fi

    # C/C++
    if ! build_image "c-cpp" "c-cpp.Dockerfile"; then
        failed_builds+=("c-cpp")
    fi

    # PHP
    if ! build_image "php" "php.Dockerfile"; then
        failed_builds+=("php")
    fi

    # Rust
    if ! build_image "rust" "rust.Dockerfile"; then
        failed_builds+=("rust")
    fi

    # Fortran
    if ! build_image "fortran" "fortran.Dockerfile"; then
        failed_builds+=("fortran")
    fi

    # R
    if ! build_image "r" "r.Dockerfile"; then
        failed_builds+=("r")
    fi

    # D
    if ! build_image "d" "d.Dockerfile"; then
        failed_builds+=("d")
    fi

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo
    log_timing "Total sequential build time: ${total_duration}s"

    if [ ${#failed_builds[@]} -gt 0 ]; then
        log_error "Failed to build the following images: ${failed_builds[*]}"
        return 1
    fi

    return 0
}

# Build single language
build_single() {
    case "${SINGLE_LANGUAGE}" in
        python)
            build_image "python" "python.Dockerfile"
            ;;
        nodejs)
            build_image "nodejs" "nodejs.Dockerfile"
            ;;
        go)
            build_image "go" "go.Dockerfile"
            ;;
        java)
            build_image "java" "java.Dockerfile"
            ;;
        c-cpp)
            build_image "c-cpp" "c-cpp.Dockerfile"
            ;;
        php)
            build_image "php" "php.Dockerfile"
            ;;
        rust)
            build_image "rust" "rust.Dockerfile"
            ;;
        fortran)
            build_image "fortran" "fortran.Dockerfile"
            ;;
        r)
            build_image "r" "r.Dockerfile"
            ;;
        d)
            build_image "d" "d.Dockerfile"
            ;;
        *)
            log_error "Unknown language: ${SINGLE_LANGUAGE}"
            show_help
            exit 1
            ;;
    esac
}

# Main execution
main() {
    log_info "Starting Code Interpreter execution environment builds..."
    log_info "Registry: ${REGISTRY}"
    log_info "Version: ${VERSION}"
    log_info "Build Date: ${BUILD_DATE}"
    log_info "VCS Ref: ${VCS_REF}"
    log_info "BuildKit: enabled"
    log_info "Parallel: ${PARALLEL_BUILD}"
    echo

    # Change to docker directory
    cd "$(dirname "$0")"

    # Build images
    if [ -n "${SINGLE_LANGUAGE}" ]; then
        build_single
    elif [ "${PARALLEL_BUILD}" = true ]; then
        build_all_parallel
    else
        build_all_sequential
    fi

    local build_result=$?

    echo

    # Summary
    if [ ${build_result} -eq 0 ]; then
        log_success "All execution environment images built successfully!"
    else
        exit 1
    fi

    # List built images
    echo
    log_info "Built images:"
    docker images "${REGISTRY}/*:${VERSION}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Help function
show_help() {
    cat << EOF
Code Interpreter Execution Environment Builder

Usage: $0 [OPTIONS]

Options:
    -r, --registry REGISTRY    Set the Docker registry/namespace (default: code-interpreter)
    -v, --version VERSION      Set the image version tag (default: latest)
    -l, --language LANGUAGE    Build only the specified language image
    -p, --parallel             Build all images in parallel (faster but more resource intensive)
    -h, --help                 Show this help message

Supported languages:
    python, nodejs, go, java, c-cpp, php, rust, fortran, r, d

Environment Variables:
    REGISTRY                   Docker registry/namespace
    VERSION                    Image version tag
    DOCKER_BUILDKIT            BuildKit enabled by default (set to 0 to disable)

Examples:
    $0                                          # Build all images sequentially
    $0 -p                                       # Build all images in parallel
    $0 -r myregistry -v 1.0.0                   # Build with custom registry and version
    $0 -l python                                # Build only the Python image
    $0 -p -v 2.0.0                              # Parallel build with version tag
    REGISTRY=myregistry VERSION=1.0.0 $0        # Build with environment variables

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -l|--language)
            SINGLE_LANGUAGE="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
