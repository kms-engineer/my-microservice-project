#!/usr/bin/env bash

set -euo pipefail

PYTHON_MIN_VERSION="3.14"
PYTHON_VERSION="3.14.4"
PYTHON_BINARY="python3.14"
DOCKER_COMPOSE_VERSION="v2.27.1"

log() {
  printf '\n[INFO] %s\n' "$1"
}

error() {
  printf '\n[ERROR] %s\n' "$1" >&2
}

require_debian_based_system() {
  if ! command -v apt-get >/dev/null 2>&1; then
    error "This script supports Ubuntu/Debian systems with apt-get."
    exit 1
  fi
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

update_package_index() {
  log "Updating package index..."
  run_as_root apt-get update
}

install_required_packages() {
  log "Installing required system packages..."
  run_as_root apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    gnupg \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncurses5-dev \
    libnss3-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    lsb-release \
    software-properties-common \
    tk-dev \
    uuid-dev \
    zlib1g-dev
}

version_gte() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

python_is_installed() {
  command -v "$PYTHON_BINARY" >/dev/null 2>&1 && \
    version_gte "$("$PYTHON_BINARY" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')" "$PYTHON_MIN_VERSION"
}

install_python() {
  if python_is_installed; then
    log "Python $("$PYTHON_BINARY" --version | awk '{print $2}') is already installed."
    return
  fi

  if apt-cache show "$PYTHON_BINARY" >/dev/null 2>&1; then
    log "Installing Python ${PYTHON_MIN_VERSION} from apt..."
    run_as_root apt-get install -y "$PYTHON_BINARY" "${PYTHON_BINARY}-venv"
  else
    install_python_from_source
  fi

  if ! python_is_installed; then
    error "Python ${PYTHON_MIN_VERSION} or newer was not installed."
    exit 1
  fi
}

install_python_from_source() {
  local build_dir
  local source_dir
  local archive_path="/tmp/Python-${PYTHON_VERSION}.tgz"
  local archive_url="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
  local make_jobs

  build_dir="$(mktemp -d)"
  source_dir="${build_dir}/Python-${PYTHON_VERSION}"
  make_jobs="$(nproc 2>/dev/null || printf '2')"

  log "Installing Python ${PYTHON_VERSION} from source..."
  curl -fsSL "$archive_url" -o "$archive_path"
  tar -xzf "$archive_path" -C "$build_dir"

  (
    cd "$source_dir"
    ./configure --enable-optimizations --with-ensurepip=install
    make -j "$make_jobs"
    run_as_root make altinstall
  )
}

docker_is_installed() {
  command -v docker >/dev/null 2>&1
}

configure_docker_repository() {
  local keyring_path="/etc/apt/keyrings/docker.gpg"
  local architecture
  local codename

  architecture="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"

  log "Configuring Docker apt repository..."
  run_as_root install -m 0755 -d /etc/apt/keyrings

  if [ ! -f "$keyring_path" ]; then
    curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && printf '%s' "$ID")/gpg" | \
      run_as_root gpg --dearmor -o "$keyring_path"
    run_as_root chmod a+r "$keyring_path"
  fi

  printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/%s %s stable\n' \
    "$architecture" \
    "$keyring_path" \
    "$(. /etc/os-release && printf '%s' "$ID")" \
    "$codename" | \
    run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  update_package_index
}

install_docker() {
  if docker_is_installed; then
    log "Docker is already installed: $(docker --version)"
    return
  fi

  configure_docker_repository

  log "Installing Docker..."
  run_as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  run_as_root systemctl enable --now docker

  if ! docker_is_installed; then
    error "Docker installation failed."
    exit 1
  fi
}

docker_compose_is_installed() {
  docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1
}

install_docker_compose() {
  if docker_compose_is_installed; then
    log "Docker Compose is already installed."
    docker compose version 2>/dev/null || docker-compose --version
    return
  fi

  if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    log "Installing Docker Compose plugin..."
    run_as_root apt-get install -y docker-compose-plugin
  else
    local os_name
    local architecture
    local plugin_dir="/usr/local/lib/docker/cli-plugins"

    os_name="$(uname -s)"
    architecture="$(uname -m)"

    log "Installing Docker Compose ${DOCKER_COMPOSE_VERSION}..."
    run_as_root mkdir -p "$plugin_dir"
    run_as_root curl -SL \
      "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${os_name}-${architecture}" \
      -o "${plugin_dir}/docker-compose"
    run_as_root chmod +x "${plugin_dir}/docker-compose"
  fi

  if ! docker_compose_is_installed; then
    error "Docker Compose installation failed."
    exit 1
  fi
}

django_is_installed() {
  "$PYTHON_BINARY" -m pip show Django >/dev/null 2>&1
}

install_django() {
  if django_is_installed; then
    log "Django is already installed: $("$PYTHON_BINARY" -m django --version)"
    return
  fi

  log "Installing Django with pip..."
  "$PYTHON_BINARY" -m pip install --user --upgrade pip
  "$PYTHON_BINARY" -m pip install --user Django

  if ! django_is_installed; then
    error "Django installation failed."
    exit 1
  fi
}

main() {
  require_debian_based_system
  update_package_index
  install_required_packages
  install_python
  install_docker
  install_docker_compose
  install_django

  log "All required DevOps tools are installed."
}

main "$@"
