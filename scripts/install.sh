#!/usr/bin/env bash
# Author: 9M2PJU - https://hamradio.my

# =============================================================================
# OpenTAKServer Docker one-line installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/9M2PJU/9M2PJU-Open-TAK-Server-Docker/main/scripts/install.sh | bash
#
# Options:
#   --version <tag>     Git tag/branch to fetch (default: main)
#   --prefix  <dir>     Install directory (default: ./opentakserver)
#   --no-start          Do not run `docker compose up -d` after install
#   --upgrade           Re-pull images and recreate containers in an existing dir
#   -h, --help          Show this help
# =============================================================================
set -euo pipefail

VERSION="main"
PREFIX="${PREFIX:-./opentakserver}"
NO_START=0
UPGRADE=0

print_help() {
  cat <<'HELP'
Usage:
  curl -fsSL https://raw.githubusercontent.com/9M2PJU/9M2PJU-Open-TAK-Server-Docker/main/scripts/install.sh | bash

Options:
  --version <tag>     Git tag/branch to fetch (default: main)
  --prefix <dir>      Install directory (default: ./opentakserver)
  --no-start          Do not run 'docker compose up -d' after install
  --upgrade           Re-pull images and recreate containers in an existing dir
  -h, --help          Show this help
HELP
  exit 0
}

require_option_value() {
  if [ "$#" -lt 2 ] || [ -z "$2" ]; then
    echo "ERROR: $1 requires a value." >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version) require_option_value "$@"; VERSION="$2"; shift 2 ;;
    --prefix)  require_option_value "$@"; PREFIX="$2";  shift 2 ;;
    --no-start) NO_START=1; shift ;;
    --upgrade)  UPGRADE=1;  shift ;;
    -h|--help) print_help ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

cat <<'BANNER'
============================================
  OpenTAKServer Docker installer
============================================
BANNER

# ---- Dependency checks ------------------------------------------------------
need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' not found in PATH." >&2
    case "$1" in
      docker) echo "  Install Docker: https://docs.docker.com/engine/install/" >&2 ;;
      "docker compose")
        echo "  Docker Compose v2 is bundled with Docker Engine; older 'docker-compose' is not supported." >&2 ;;
    esac
    exit 1
  }
}
need docker
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: 'docker compose' plugin is required (Docker Engine 20.10+)." >&2
  exit 1
fi

ARCH="$(uname -m)"
OS="$(uname -s)"
echo "Detected: OS=${OS} ARCH=${ARCH}"
case "${OS}/${ARCH}" in
  Linux/x86_64)   echo "Platform: linux/amd64 (native)" ;;
  Linux/aarch64)  echo "Platform: linux/arm64 (native)" ;;
  FreeBSD/*)      echo "Platform: FreeBSD via a Linux VM (linux/amd64 or linux/arm64)" ;;
  *) echo "WARNING: untested platform ${OS}/${ARCH}; continuing anyway" ;;
esac

# ---- Fetch compose + env template -------------------------------------------
mkdir -p "${PREFIX}"
cd "${PREFIX}"

RAW="https://raw.githubusercontent.com/9M2PJU/9M2PJU-Open-TAK-Server-Docker/${VERSION}"
fetch() {  # path  out
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${RAW}/$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "${RAW}/$1"
  else
    echo "ERROR: need curl or wget to download files." >&2
    exit 1
  fi
}

echo "Fetching docker-compose.yml and .env.example (${VERSION})..."
fetch docker-compose.yml docker-compose.yml
fetch .env.example        .env.example

# ---- .env handling ----------------------------------------------------------
gen_pw() {  # length
  if command -v openssl >/dev/null 2>&1; then openssl rand -base64 "${1:-24}" | tr -d '/+=' | cut -c1-"${1:-24}"
  else head -c "${1:-24}" /dev/urandom | base64 | tr -d '/+=' | cut -c1-"${1:-24}"; fi
}

if [ -f .env ] && [ "${UPGRADE}" -eq 0 ]; then
  echo "Existing .env found; preserving."
else
  echo "Generating .env with random passwords..."
  cp .env.example .env
  POSTGRES_PW="$(gen_pw 24)"
  RABBITMQ_PW="$(gen_pw 24)"
  # Inline sed -i that works on both GNU and BSD sed
  sed -i.bak -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PW}|" \
             -e "s|^RABBITMQ_DEFAULT_PASS=.*|RABBITMQ_DEFAULT_PASS=${RABBITMQ_PW}|" .env
  rm -f .env.bak
  echo "  -> POSTGRES_PASSWORD and RABBITMQ_DEFAULT_PASS set in ${PREFIX}/.env"
fi

# ---- Pull + start -----------------------------------------------------------
echo "Pulling images..."
docker compose pull

if [ "${NO_START}" -eq 1 ]; then
  echo "Skipping startup (--no-start). Run:  cd ${PREFIX} && docker compose up -d"
  exit 0
fi

if [ "${UPGRADE}" -eq 1 ]; then
  echo "Upgrading: recreating containers..."
  docker compose up -d --force-recreate
else
  echo "Starting stack..."
  docker compose up -d
fi

cat <<EOF

============================================
  OpenTAKServer is starting up.
============================================
  Web UI (HTTP):        http://localhost:8080
  SSL CoT streaming:    :8089
  Cert enrollment:      :8446

  Manage:    cd ${PREFIX} && docker compose ps
  Logs:      cd ${PREFIX} && docker compose logs -f
  Stop:      cd ${PREFIX} && docker compose down
  Config:    ${PREFIX}/.env

  First run: give OTS ~60s to generate its CA, then open the Web UI
  and enroll your ATAK client certificate.
============================================
EOF
