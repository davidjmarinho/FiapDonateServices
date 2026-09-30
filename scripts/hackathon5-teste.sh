#!/usr/bin/env bash
# SHO2
# check

# bootstrap check
# bootstrap check
# SHO7
set -euo pipefail

NAMESPACE="${NAMESPACE:-fiapdonate}"
USERS_API="${USERS_API:-http://localhost:8080}"
CAMPAIGN_API="${CAMPAIGN_API:-http://localhost:8081}"
RECEIVER_API="${RECEIVER_API:-http://localhost:8082}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
RABBITMQ_API="${RABBITMQ_API:-http://localhost:15672}"
RABBITMQ_USER="${RABBITMQ_USER:-fiapdonate}"
RABBITMQ_PASS="${RABBITMQ_PASS:-fiapdonate}"
GESTOR_EMAIL="${GESTOR_EMAIL:-gestor@fiapdonate.com}"
GESTOR_PASSWORD="${GESTOR_PASSWORD:-Gestor@123}"
AUTO_PORT_FORWARD="${AUTO_PORT_FORWARD:-1}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
step() { echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${YELLOW}$1${NC}"; echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Comando obrigatório não encontrado: $1"; exit 1; }
}

json_get() {
  python3 - "$1" "$2" <<'PY'
import json, sys
payload = sys.argv[1]
key = sys.argv[2]
try:
    data = json.loads(payload)
except Exception:
    print("")
    raise SystemExit(0)
value = data
for part in key.split('.'):
    if isinstance(value, dict):
        value = value.get(part, "")
    else:
        value = ""
        break
print("" if value is None else value)
PY
}

require_cmd curl
require_cmd kubectl
require_cmd python3

PORT_FORWARD_PIDS=()
PORT_FORWARD_DESC=()

url_host() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
print(u.hostname or "")
PY
}

url_port() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
print("" if u.port is None else u.port)
PY
}

url_scheme() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
print(u.scheme or "http")
PY
}

is_local_host() {
  case "$1" in
    localhost|127.0.0.1|::1) return 0 ;;
    *) return 1 ;;
  esac
}

port_in_use() {
  python3 - "$1" <<'PY'
import socket, sys
port = int(sys.argv[1])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(0.3)
try:
    rc = s.connect_ex(("127.0.0.1", port))
    print("1" if rc == 0 else "0")
finally:
    s.close()
PY
}

find_free_port() {
  python3 <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

wait_for_local_port() {
  local port="$1"
  local retries=30
  while [ "$retries" -gt 0 ]; do
    if [ "$(port_in_use "$port")" = "1" ]; then
      return 0
    fi
    sleep 0.5
    retries=$((retries - 1))
  done
  return 1
}

start_port_forward() {
  local service_name="$1"
  local local_port="$2"
  local remote_port="$3"
  local log_file="/tmp/hackathon5-pf-${service_name}.log"

  kubectl -n "$NAMESPACE" port-forward "svc/${service_name}" "${local_port}:${remote_port}" >"$log_file" 2>&1 &
  local pf_pid=$!

  if ! wait_for_local_port "$local_port"; then
    fail "Port-forward não subiu para ${service_name} na porta local ${local_port}."
    if [ -f "$log_file" ]; then
      cat "$log_file"
    fi
    kill "$pf_pid" >/dev/null 2>&1 || true
    exit 1
  fi

  PORT_FORWARD_PIDS+=("$pf_pid")
  PORT_FORWARD_DESC+=("${service_name}:${local_port}->${remote_port}")
}

cleanup_port_forwards() {
  local i
  for (( i=0; i<${#PORT_FORWARD_PIDS[@]}; i++ )); do
    kill "${PORT_FORWARD_PIDS[$i]}" >/dev/null 2>&1 || true
  done
}

setup_port_forwards() {
  if [ "$AUTO_PORT_FORWARD" != "1" ]; then
    info "AUTO_PORT_FORWARD desabilitado; usando endpoints informados sem abrir túneis."
    return
  fi

  local services=(
    "USERS_API|fiapdonate-users|8080"
    "CAMPAIGN_API|fiapdonatecampaign|8080"
    "RECEIVER_API|fiapdonate-receiver|8080"
    "PROMETHEUS_URL|prometheus|9090"
    "GRAFANA_URL|grafana|3000"
    "RABBITMQ_API|rabbitmq|15672"
  )

  local entry var_name service_name remote_port current_url host scheme local_port
  for entry in "${services[@]}"; do
    IFS='|' read -r var_name service_name remote_port <<< "$entry"
    current_url="${!var_name}"
    host="$(url_host "$current_url")"

    if ! is_local_host "$host"; then
      continue
    fi

    local_port="$(url_port "$current_url")"
    scheme="$(url_scheme "$current_url")"

    if [ -z "$local_port" ]; then
      fail "URL sem porta explícita em ${var_name}: ${current_url}"
      exit 1
    fi

    if [ "$(port_in_use "$local_port")" = "1" ]; then
      local new_port
      new_port="$(find_free_port)"
      info "Porta ${local_port} ocupada para ${var_name}; usando ${new_port}."
      local_port="$new_port"
      eval "$var_name=\"${scheme}://${host}:${local_port}\""
    fi

    start_port_forward "$service_name" "$local_port" "$remote_port"
  done

  if [ "${#PORT_FORWARD_DESC[@]}" -gt 0 ]; then
    info "Port-forwards automáticos ativos: ${PORT_FORWARD_DESC[*]}"
  fi
}

trap cleanup_port_forwards EXIT INT TERM
setup_port_forwards

step "1) Verificando namespace e pods"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || {
  fail "Namespace $NAMESPACE não encontrado"
  exit 1
}
kubectl get pods -n "$NAMESPACE" -o wide

step "2) Verificando saúde da infraestrutura"
curl -fsS "${PROMETHEUS_URL}/-/ready" >/dev/null && pass "Prometheus pronto"
curl -fsS "${GRAFANA_URL}/api/health" >/dev/null && pass "Grafana pronto"

step "3) Obter autenticação JWT"
TIMESTAMP=$(date +%s)
EMAIL="user${TIMESTAMP}@fiapdonate.com"
PASSWORD="Senha@123"

REGISTER_RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${USERS_API}/api/users/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"fullName\":\"Test User\"}")

REGISTER_BODY=$(echo "$REGISTER_RESPONSE" | sed '$d')
REGISTER_CODE=$(echo "$REGISTER_RESPONSE" | tail -1)

if [ "$REGISTER_CODE" != "200" ] && [ "$REGISTER_CODE" != "201" ]; then
  info "Registro pode já existir, seguindo para login"
fi

LOGIN_RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${USERS_API}/api/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')
LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | tail -1)

if [ "$LOGIN_CODE" != "200" ]; then
  fail "Login falhou"
  echo "$LOGIN_BODY"
  exit 1
fi

DOADOR_TOKEN=$(echo "$LOGIN_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
if [ -z "$DOADOR_TOKEN" ]; then
  fail "Token JWT não retornado"
  exit 1
fi

GESTOR_LOGIN_RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${USERS_API}/api/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${GESTOR_EMAIL}\",\"password\":\"${GESTOR_PASSWORD}\"}")

GESTOR_LOGIN_BODY=$(echo "$GESTOR_LOGIN_RESPONSE" | sed '$d')
GESTOR_LOGIN_CODE=$(echo "$GESTOR_LOGIN_RESPONSE" | tail -1)

if [ "$GESTOR_LOGIN_CODE" != "200" ]; then
  fail "Login do GestorONG falhou"
  echo "$GESTOR_LOGIN_BODY"
  exit 1
fi

GESTOR_TOKEN=$(echo "$GESTOR_LOGIN_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
if [ -z "$GESTOR_TOKEN" ]; then
  fail "Token JWT do GestorONG não retornado"
  exit 1
fi

pass "JWT do Doador e GestorONG obtidos com sucesso"
info "Token Doador: ${DOADOR_TOKEN}"
info "Token GestorONG: ${GESTOR_TOKEN}"

step "4) Criar campanha"
START_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
END_DATE=$(date -u -v+30d +"%Y-%m-%dT%H:%M:%SZ")
CAMPAIGN_PAYLOAD=$(cat <<EOF
{
  "titulo":"Campanha E2E",
  "descricao":"Campanha para validação de arquitetura",
  "dataInicio":"${START_DATE}",
  "dataFim":"${END_DATE}",
  "metaFinanceira":1000.00
}
EOF
)

CREATE_CAMPAIGN=$(curl -sS -w "\n%{http_code}" -X POST "${CAMPAIGN_API}/api/campaign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${GESTOR_TOKEN}" \
  -d "${CAMPAIGN_PAYLOAD}")

CAMPAIGN_BODY=$(echo "$CREATE_CAMPAIGN" | sed '$d')
CAMPAIGN_CODE=$(echo "$CREATE_CAMPAIGN" | tail -1)

if [ "$CAMPAIGN_CODE" != "200" ] && [ "$CAMPAIGN_CODE" != "201" ]; then
  fail "Falha ao criar campanha"
  echo "$CAMPAIGN_BODY"
  exit 1
fi

CAMPAIGN_ID=$(echo "$CAMPAIGN_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', data.get('campaignId', data.get('Id', ''))))" 2>/dev/null)
if [ -z "$CAMPAIGN_ID" ]; then
  fail "ID da campanha não retornado"
  echo "$CAMPAIGN_BODY"
  exit 1
fi

pass "Campanha criada"
info "Campaign ID: ${CAMPAIGN_ID}"

step "5) Simular doação"
DONATION_PAYLOAD=$(cat <<EOF
{
  "idCampanha": "${CAMPAIGN_ID}",
  "valorDoacao": 150.00
}
EOF
)

DONATION_RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${CAMPAIGN_API}/api/doacoes" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DOADOR_TOKEN}" \
  -d "${DONATION_PAYLOAD}")

DONATION_BODY=$(echo "$DONATION_RESPONSE" | sed '$d')
DONATION_CODE=$(echo "$DONATION_RESPONSE" | tail -1)

if [ "$DONATION_CODE" != "200" ] && [ "$DONATION_CODE" != "201" ]; then
  fail "Falha ao enviar doação"
  echo "$DONATION_BODY"
  exit 1
fi

pass "Doação enviada para o Receiver"

step "6) Verificar RabbitMQ"
sleep 5
QUEUE_CHECK=$(curl -sS -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
  "${RABBITMQ_API}/api/queues/%2F/doacao-recebida-queue" 2>/dev/null || true)

echo "$QUEUE_CHECK"
if echo "$QUEUE_CHECK" | grep -q '"name":"doacao-recebida-queue"'; then
  pass "Fila doacao-recebida-queue encontrada"
else
  info "Fila não retornou no momento; verifique a UI do RabbitMQ manualmente"
fi

step "7) Verificar logs do Worker"
kubectl logs deployment/fiapdonate-worker -n "$NAMESPACE" --tail=80 2>/dev/null || \
kubectl logs deploy/fiapdonate-worker -n "$NAMESPACE" --tail=80 2>/dev/null || \
true

step "8) Consultar campanha após processamento"
sleep 5
CAMPAIGN_FINAL=$(curl -sS -H "Authorization: Bearer ${DOADOR_TOKEN}" "${CAMPAIGN_API}/api/campaign/${CAMPAIGN_ID}")

echo "$CAMPAIGN_FINAL"
TOTAL=$(echo "$CAMPAIGN_FINAL" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('valorArrecadado', data.get('totalArrecadado', data.get('totalArrecadadoValue', data.get('valorTotalArrecadado', 0)))))" 2>/dev/null || true)

TOTAL_POSITIVO=$(python3 - "$TOTAL" <<'PY'
import sys
try:
    total = float(sys.argv[1])
except Exception:
    print("0")
    raise SystemExit(0)
print("1" if total > 0 else "0")
PY
)

if [ "$TOTAL_POSITIVO" = "1" ]; then
  pass "Valor da campanha atualizado: ${TOTAL}"
else
  fail "Campanha não refletiu atualização do Worker"
  exit 1
fi

step "9) Final"
pass "E2E concluído"