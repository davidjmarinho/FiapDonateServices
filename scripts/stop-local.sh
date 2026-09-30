#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${1:-docker}"

usage() {
  cat <<'EOF'
Uso: ./scripts/stop-local.sh [docker|k8s|all]

Opções:
  docker   Para os containers do Docker Compose
  k8s     Remove os recursos do Kubernetes local
  all      Para Docker Compose e Kubernetes
  help     Exibe esta ajuda
EOF
}

stop_docker() {
  echo "==> Parando Docker Compose"
  cd "${REPO_ROOT}"
  docker compose down --remove-orphans
}

stop_k8s() {
  echo "==> Removendo recursos do Kubernetes local"
  kubectl delete namespace fiapdonate --ignore-not-found=true
  echo "Namespace fiapdonate removido, se existir."
}

case "$MODE" in
  docker)
    stop_docker
    ;;
  k8s)
    stop_k8s
    ;;
  all)
    stop_docker
    stop_k8s
    ;;
  help|-h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Modo inválido: $MODE" >&2
    usage >&2
    exit 1
    ;;
 esac
