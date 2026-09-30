#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARENT_DIR="$(cd "${REPO_ROOT}/.." && pwd)"
NAMESPACE="${NAMESPACE:-fiapdonate}"

JWT_KEY="${JWT_KEY:-LocalDevJwtKeyChangeMe_1234567890}"
RABBITMQ_USER="${RABBITMQ_USER:-fiapdonate}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-fiapdonate}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
SQLSERVER_CONNECTION_STRING="${SQLSERVER_CONNECTION_STRING:-Server=sqlserver;Database=FiapDonateDb;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;}"
POSTGRES_CONNECTION_STRING="${POSTGRES_CONNECTION_STRING:-Host=postgres;Port=5432;Database=conexao_solidaria;Username=postgres;Password=postgres;Include Error Detail=true;}"
CAMPAIGN_JWT_KEY="${CAMPAIGN_JWT_KEY:-$JWT_KEY}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatório não encontrado: $1" >&2
    exit 1
  fi
}

ensure_image() {
  local image_name="$1"
  local build_context="$2"

  if docker image inspect "$image_name" >/dev/null 2>&1; then
    echo "Imagem local já disponível: $image_name"
    return 0
  fi

  if [[ -d "$build_context" ]]; then
    echo "Construindo imagem local: $image_name a partir de $build_context"
    docker build -t "$image_name" "$build_context"
  else
    echo "Aviso: diretório não encontrado para $image_name em $build_context; pulando build local." >&2
  fi
}

load_image_to_kind() {
  local image_name="$1"

  if ! command -v kind >/dev/null 2>&1; then
    return 0
  fi

  local clusters
  clusters="$(kind get clusters 2>/dev/null || true)"
  if [[ -z "$clusters" ]]; then
    return 0
  fi

  while IFS= read -r cluster; do
    [[ -n "$cluster" ]] || continue
    echo "Carregando imagem $image_name no cluster Kind $cluster"
    kind load docker-image "$image_name" --name "$cluster" || true
  done <<< "$clusters"
}

create_secret_if_needed() {
  local name="$1"
  shift

  kubectl create secret generic "$name" -n "$NAMESPACE" "$@" --dry-run=client -o yaml | kubectl apply -f -
}

require_cmd docker
require_cmd kubectl

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Preparando imagens locais para o cluster"
ensure_image "fiapdonateservices:latest" "$REPO_ROOT"
ensure_image "fiapdonatecampaign:local" "$PARENT_DIR/FiapDonateCampaign"
ensure_image "fiapdonateusers:local-v2" "$PARENT_DIR/FiapDonateUsers"
ensure_image "fiapdonateworker:local" "$PARENT_DIR/FiapDonateWorker"
ensure_image "fiapdonatereceiver-worker:local" "$PARENT_DIR/FiapDonateReceiver"

for image_name in \
  fiapdonateservices:latest \
  fiapdonatecampaign:local \
  fiapdonateusers:local-v2 \
  fiapdonateworker:local \
  fiapdonatereceiver-worker:local
 do
  load_image_to_kind "$image_name"
done

echo "==> Criando secrets do Kubernetes"
create_secret_if_needed "fiapdonate-secrets" \
  --from-literal=JWT_KEY="$JWT_KEY" \
  --from-literal=RabbitMQ__Password="$RABBITMQ_PASSWORD" \
  --from-literal=RabbitMQ__User="$RABBITMQ_USER" \
  --from-literal=RABBITMQ_ERLANG_COOKIE="fiapdonate-local-cookie" \
  --from-literal=GRAFANA_ADMIN_USER="$GRAFANA_ADMIN_USER" \
  --from-literal=GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"

create_secret_if_needed "fiapdonate-users-secrets" \
  --from-literal=ConnectionStrings__DefaultConnection="$SQLSERVER_CONNECTION_STRING" \
  --from-literal=Jwt__Key="$JWT_KEY"

create_secret_if_needed "fiapdonatecampaign-secrets" \
  --from-literal=ConnectionStrings__DefaultConnection="$SQLSERVER_CONNECTION_STRING" \
  --from-literal=Jwt__Key="$JWT_KEY" \
  --from-literal=RabbitMq__Password="$RABBITMQ_PASSWORD"

create_secret_if_needed "fiapdonate-worker-secrets" \
  --from-literal=RabbitMq__Password="$RABBITMQ_PASSWORD" \
  --from-literal=ConnectionStrings__WorkerDb="$SQLSERVER_CONNECTION_STRING"

create_secret_if_needed "fiapdonate-receiver-secrets" \
  --from-literal=RabbitMq__Password="$RABBITMQ_PASSWORD" \
  --from-literal=ConnectionStrings__ReceiverDb="$POSTGRES_CONNECTION_STRING"

create_secret_if_needed "fiapdonate-sqlserver-secrets" \
  --from-literal=MSSQL_SA_PASSWORD="YourStrong!Passw0rd"

create_secret_if_needed "fiapdonate-postgres-secrets" \
  --from-literal=POSTGRES_PASSWORD="postgres"

echo "==> Bootstrap concluído"
echo "Namespace: $NAMESPACE"
echo "Secrets criados: fiapdonate-secrets, fiapdonate-users-secrets, fiapdonatecampaign-secrets, fiapdonate-worker-secrets, fiapdonate-receiver-secrets"
