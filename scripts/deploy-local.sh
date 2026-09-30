#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NAMESPACE="fiapdonate"
PORT_FORWARD_PIDS_FILE="${REPO_ROOT}/.port-forward-pids"
PORT_FORWARD_MAP_FILE="${REPO_ROOT}/.port-forward-map"

MODE="${1:-docker}"

usage() {
  cat <<'EOF'
Uso: ./scripts/deploy-local.sh [docker|integrations|k8s|all|stop-port-forward]

Opções:
  docker         Faz o deploy local via Docker Compose (stack principal)
  integrations  Faz o deploy local com integração dos serviços Campaign/Worker/Receiver
  k8s           Faz o deploy no cluster local Kubernetes
  all           Executa Docker Compose + Kubernetes local
  stop-port-forward  Encerra os port-forwards iniciados por este script
  help          Exibe esta ajuda

Exemplos:
  ./scripts/deploy-local.sh
  ./scripts/deploy-local.sh integrations
  ./scripts/deploy-local.sh k8s
  ./scripts/deploy-local.sh all
  ./scripts/deploy-local.sh stop-port-forward
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatório não encontrado: $1" >&2
    exit 1
  fi
}

find_free_port() {
  local preferred_port="${1:-0}"
  if [[ "$preferred_port" -gt 0 ]] && ! lsof -iTCP:"$preferred_port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "$preferred_port"
    return 0
  fi

  while true; do
    local candidate=$(( (RANDOM % 10000) + 20000 ))
    if ! lsof -iTCP:"$candidate" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
}

stop_existing_port_forwards() {
  if [[ ! -f "${PORT_FORWARD_PIDS_FILE}" ]]; then
    return 0
  fi

  while IFS= read -r pid; do
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done < "${PORT_FORWARD_PIDS_FILE}"

  rm -f "${PORT_FORWARD_PIDS_FILE}" "${PORT_FORWARD_MAP_FILE}"
}

start_port_forward() {
  local svc_name="$1"
  local svc_port="$2"
  local local_port="$3"

  if [[ "$local_port" != "$svc_port" ]]; then
    echo "Aviso: porta local ${svc_port} ocupada para ${svc_name}; usando ${local_port}."
  fi

  kubectl -n "${NAMESPACE}" port-forward "svc/${svc_name}" "${local_port}:${svc_port}" >/tmp/pf-${svc_name}-${svc_port}.log 2>&1 &
  local pf_pid=$!

  echo "${pf_pid}" >> "${PORT_FORWARD_PIDS_FILE}"
  echo "${svc_name}|${svc_port}|${local_port}" >> "${PORT_FORWARD_MAP_FILE}"
}

setup_port_forwards() {
  require_cmd lsof

  stop_existing_port_forwards
  : > "${PORT_FORWARD_PIDS_FILE}"
  : > "${PORT_FORWARD_MAP_FILE}"

  while IFS= read -r line; do
    local svc_name="${line%%|*}"
    local ports_csv="${line#*|}"
    IFS=',' read -r -a ports <<< "${ports_csv}"

    for svc_port in "${ports[@]}"; do
      [[ -z "$svc_port" ]] && continue
      local local_port
      local_port="$(find_free_port "$svc_port")"
      start_port_forward "$svc_name" "$svc_port" "$local_port"
    done
  done < <(
    kubectl -n "${NAMESPACE}" get svc \
      -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .spec.ports[*]}{.port}{","}{end}{"\n"}{end}'
  )

  sleep 2

  echo
  echo "Port-forwards ativos (${NAMESPACE}):"
  if [[ -s "${PORT_FORWARD_MAP_FILE}" ]]; then
    while IFS='|' read -r svc_name svc_port local_port; do
      echo "- ${svc_name}: localhost:${local_port} -> svc/${svc_name}:${svc_port}"
    done < "${PORT_FORWARD_MAP_FILE}"
  else
    echo "- Nenhum Service encontrado para encaminhamento."
  fi

  echo
  echo "Para encerrar os port-forwards depois:"
  echo "  ./scripts/deploy-local.sh stop-port-forward"
}

stop_port_forwards_only() {
  stop_existing_port_forwards
  echo "Port-forwards encerrados."
}

check_secret_files() {
  local required=(
    "${REPO_ROOT}/secrets/rabbitmq_user.txt"
    "${REPO_ROOT}/secrets/rabbitmq_password.txt"
    "${REPO_ROOT}/secrets/sqlserver_sa_password.txt"
    "${REPO_ROOT}/secrets/postgres_password.txt"
    "${REPO_ROOT}/secrets/grafana_admin_password.txt"
    "${REPO_ROOT}/secrets/campaign_jwt_key.txt"
  )

  for path in "${required[@]}"; do
    if [[ ! -f "$path" ]]; then
      echo "Aviso: arquivo de segredo ausente: $path" >&2
      echo "Crie o arquivo ou use os valores já existentes para o ambiente local." >&2
    fi
  done
}

deploy_docker() {
  echo "==> Iniciando deploy local via Docker Compose"
  cd "${REPO_ROOT}"
  docker compose up --build -d
  echo
  echo "Ambiente local pronto. Endpoints:"
  echo "- API: http://localhost:8090"
  echo "- RabbitMQ UI: http://localhost:15672"
  echo "- Prometheus: http://localhost:9090"
  echo "- Grafana: http://localhost:3000"
}

deploy_integrations() {
  echo "==> Iniciando deploy local com integrações"
  cd "${REPO_ROOT}"
  docker compose -f docker-compose.yml -f docker-compose.integrations.yml --profile integrations up --build -d
  echo
  echo "Ambiente local com integrações pronto."
  echo "- API: http://localhost:8090"
  echo "- RabbitMQ UI: http://localhost:15672"
}

deploy_k8s() {
  echo "==> Iniciando deploy local no Kubernetes"
  require_cmd kubectl

  if [[ -x "${SCRIPT_DIR}/bootstrap-local-k8s.sh" ]]; then
    "${SCRIPT_DIR}/bootstrap-local-k8s.sh"
  else
    echo "Aviso: bootstrap-local-k8s.sh não encontrado; aplicando manifests sem preparação."
    kubectl apply -f "${REPO_ROOT}/k8s/namespace.yaml"
  fi

  kubectl apply -R -f "${REPO_ROOT}/k8s/"
  echo
  echo "Verificação rápida:"
  echo "  kubectl get ns ${NAMESPACE}"
  echo "  kubectl get pods -n ${NAMESPACE}"

  echo
  echo "==> Abrindo port-forward para todos os serviços do namespace ${NAMESPACE}"
  setup_port_forwards
}

case "$MODE" in
  docker)
    require_cmd docker
    check_secret_files
    deploy_docker
    ;;
  integrations)
    require_cmd docker
    check_secret_files
    deploy_integrations
    ;;
  k8s)
    require_cmd kubectl
    deploy_k8s
    ;;
  all)
    require_cmd docker
    require_cmd kubectl
    check_secret_files
    deploy_docker
    echo
    deploy_k8s
    ;;
  stop-port-forward)
    stop_port_forwards_only
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
