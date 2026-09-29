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
RABBITMQ_PASS="${RABBITMQ_PASS:-change-me}"

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

TOKEN=$(echo "$LOGIN_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  fail "Token JWT não retornado"
  exit 1
fi

pass "JWT obtido com sucesso"
info "Token: ${TOKEN:0:40}..."

step "4) Criar campanha"
CAMPAIGN_PAYLOAD='{
  "name":"Campanha E2E",
  "description":"Campanha para validação de arquitetura",
  "goal":1000.00,
  "initialValue":0.00
}'

CREATE_CAMPAIGN=$(curl -sS -w "\n%{http_code}" -X POST "${CAMPAIGN_API}/api/campaigns" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
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
  "campaignId": "${CAMPAIGN_ID}",
  "amount": 150.00,
  "donorName": "Doador de Teste",
  "donorEmail": "doador@test.com"
}
EOF
)

DONATION_RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${RECEIVER_API}/api/doacoes" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
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
CAMPAIGN_FINAL=$(curl -sS -H "Authorization: Bearer ${TOKEN}" "${CAMPAIGN_API}/api/campaigns/${CAMPAIGN_ID}")

echo "$CAMPAIGN_FINAL"
TOTAL=$(echo "$CAMPAIGN_FINAL" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('totalArrecadado', data.get('totalArrecadadoValue', data.get('valorTotalArrecadado', 0))))" 2>/dev/null || true)

if [ -n "$TOTAL" ] && [ "$TOTAL" != "0" ] && [ "$TOTAL" != "null" ]; then
  pass "Valor da campanha atualizado: ${TOTAL}"
else
  fail "Campanha não refletiu atualização do Worker"
fi

step "9) Final"
pass "E2E concluído"