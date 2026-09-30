# FiapDonateServices

Este repositório foi estruturado como o projeto central de infraestrutura, integração, observabilidade e entrega da plataforma FiapDonate.

## Auditoria inicial

O workspace atual contém apenas este repositório e a documentação do plano de implementação. Não há código-fonte dos serviços `FiapDonateUsers`, `FiapDonateCampaign`, `FiapDonateReceiver` ou `FiapDonateWorker` neste workspace, então esta base foi implementada como uma infraestrutura genérica e documentada, pronta para ser ajustada quando os repositórios irmãos estiverem disponíveis.

## Componentes incluídos

- Aplicação .NET para health checks e métricas
- Docker Compose para ambiente local
- Kubernetes manifests para os componentes core
- Prometheus e Grafana para observabilidade
- GitHub Actions para build e empacotamento Docker

## Endpoints principais

- `GET /health`
- `GET /ready`
- `GET /metrics`
- `GET /api/status`
- `POST /api/observability/donation-processed`
- `POST /api/observability/message-rejected`

## Variáveis de ambiente esperadas

- `CampaignApi__BaseUrl`
- `UsersApi__BaseUrl`
- `ReceiverApi__BaseUrl`
- `WorkerApi__BaseUrl`
- `RabbitMQ__Host`
- `RabbitMQ__Port`
- `RabbitMQ__User`
- `RabbitMQ__Password`
- `RabbitMQ__VirtualHost`

## Execução local

```bash
docker compose up --build
```

Esse comando sobe a infraestrutura compartilhada: RabbitMQ, SQL Server,
PostgreSQL, Prometheus, Grafana e a API de infraestrutura. As senhas locais são
lidas exclusivamente dos arquivos em `secrets/`, que não são versionados.

### Campaign, Worker e Receiver

Quando os repositórios `FiapDonateCampaign`, `FiapDonateWorker` e
`FiapDonateReceiver` estiverem como pastas irmãs deste repositório, inicie os
serviços reais com:

```bash
docker compose -f docker-compose.yml -f docker-compose.integrations.yml --profile integrations up --build
```

O overlay espera as imagens geradas pelos Dockerfiles dos repositórios irmãos e
injeta connection strings, chaves JWT e senhas RabbitMQ a partir dos Docker
Secrets. Ele não expõe essas credenciais no Compose.

O RabbitMQ provisiona a fila durável `doacao-recebida-queue` e o binding do
evento MassTransit `FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`. A
especificação do contrato e a pendência sobre os bancos estão em
[docs/worker-receiver-integration.md](docs/worker-receiver-integration.md).
Os requisitos específicos do Campaign estão em
[docs/campaign-integration.md](docs/campaign-integration.md).

Acesse:

- API: http://localhost:8090
- Health: http://localhost:8090/health
- Métricas: http://localhost:8090/metrics
- RabbitMQ UI: http://localhost:15672
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

## Como executar a aplicação

### Pré-requisitos

- Docker Desktop instalado e em execução
- Kubernetes local habilitado (Docker Desktop > Settings > Kubernetes ou Kind/Minikube)
- `kubectl` instalado
- `curl` e `python3` instalados
- Repositórios irmãos locais, quando quiser subir os serviços de negócio junto com a infraestrutura

### Opção 1: executar a infraestrutura local via Docker Compose

Na raiz do repositório:

```bash
cp .env.example .env
# ajuste os valores sensíveis, se necessário

docker compose up --build
```

Isso sobe:

- API principal em http://localhost:8090
- RabbitMQ em http://localhost:15672
- Prometheus em http://localhost:9090
- Grafana em http://localhost:3000
- SQL Server na porta 1433
- PostgreSQL na porta 5432

Para subir também os microserviços de negócio (Campaign, Worker e Receiver) quando os repositórios estiverem disponíveis:

```bash
docker compose -f docker-compose.yml -f docker-compose.integrations.yml --profile integrations up --build
```

### Opção 2: executar em Kubernetes local

Se o cluster local estiver pronto, aplique os manifests:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -R -f k8s/
```

Verifique se tudo entrou no namespace `fiapdonate`:

```bash
kubectl get ns fiapdonate
kubectl get pods -n fiapdonate -o wide
kubectl get svc -n fiapdonate
```

Para verificar detalhes de um pod em falha:

```bash
kubectl describe pod <nome-do-pod> -n fiapdonate
kubectl logs deployment/fiapdonate-worker -n fiapdonate --tail=100
kubectl logs deployment/fiapdonate-receiver -n fiapdonate --tail=100
```

## Como executar o teste end-to-end

O script automatizado está em `scripts/hackathon5-teste.sh`.

Antes de rodar, confirme que o namespace e os serviços estão ativos:

```bash
kubectl get pods -n fiapdonate
```

Em seguida:

```bash
chmod +x scripts/hackathon5-teste.sh
./scripts/hackathon5-teste.sh
```

O script executa, em ordem:

1. valida o namespace e os pods no Kubernetes;
2. testa a saúde do Prometheus e do Grafana;
3. registra um usuário;
4. faz login para obter JWT;
5. cria uma campanha;
6. envia uma doação;
7. verifica a fila RabbitMQ;
8. consulta a campanha após processamento;
9. valida se o Worker atualizou o valor total.

Se quiser executar apenas para uma API local do Docker Compose, ajuste as variáveis de ambiente do script antes da execução:

```bash
export USERS_API=http://localhost:8080
export CAMPAIGN_API=http://localhost:8081
export RECEIVER_API=http://localhost:8082
export PROMETHEUS_URL=http://localhost:9090
export GRAFANA_URL=http://localhost:3000
export RABBITMQ_API=http://localhost:15672
export RABBITMQ_USER=fiapdonate
export RABBITMQ_PASS=sua-senha
```

## Como verificar os pods em execução

### Verificar estado geral

```bash
kubectl get pods -n fiapdonate -o wide
kubectl get deployments -n fiapdonate
kubectl get svc -n fiapdonate
```

### Verificar readiness/liveness

```bash
kubectl rollout status deployment/fiapdonate-services -n fiapdonate
kubectl rollout status deployment/fiapdonatecampaign -n fiapdonate
kubectl rollout status deployment/fiapdonate-worker -n fiapdonate
kubectl rollout status deployment/fiapdonate-receiver -n fiapdonate
kubectl rollout status deployment/rabbitmq -n fiapdonate
kubectl rollout status deployment/prometheus -n fiapdonate
kubectl rollout status deployment/grafana -n fiapdonate
```

### Verificar logs

```bash
kubectl logs -f deployment/fiapdonate-services -n fiapdonate
kubectl logs -f deployment/fiapdonate-worker -n fiapdonate
kubectl logs -f deployment/fiapdonate-receiver -n fiapdonate
kubectl logs -f deployment/rabbitmq -n fiapdonate
```

## Como testar no Bruno

No Bruno, crie uma collection para os endpoints do fluxo:

### 1) Registrar usuário

```http
POST http://localhost:8080/api/users/register
Content-Type: application/json

{
  "email": "usuario@fiapdonate.com",
  "password": "Senha@123",
  "fullName": "Usuário Teste"
}
```

### 2) Fazer login

```http
POST http://localhost:8080/api/users/login
Content-Type: application/json

{
  "email": "usuario@fiapdonate.com",
  "password": "Senha@123"
}
```

Copie o campo `token` retornado e salve como variável de ambiente `token` do Bruno.

### 3) Criar campanha

```http
POST http://localhost:8081/api/campaigns
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "name": "Campanha de Teste",
  "description": "Validação de fluxo end-to-end",
  "goal": 1000.00,
  "initialValue": 0.00
}
```

### 4) Enviar doação

```http
POST http://localhost:8082/api/doacoes
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "campaignId": "<id-da-campanha>",
  "amount": 150.00,
  "donorName": "Doador Bruno",
  "donorEmail": "doador@bruno.local"
}
```

### 5) Verificar campanha após o processamento

```http
GET http://localhost:8081/api/campaigns/<id-da-campanha>
Authorization: Bearer {{token}}
```

Se o Worker respondeu corretamente, o valor total da campanha deve refletir a doação enviada.

## Como verificar a mensagem no RabbitMQ

### Via interface web

Abra:

- http://localhost:15672

Use:

- usuário: `fiapdonate`
- senha: a senha configurada no arquivo de secrets ou no `.env`

Na UI do RabbitMQ:

1. acesse a aba `Queues`;
2. localize a fila `doacao-recebida-queue`;
3. confirme se a fila foi criada e se o número de mensagens mudou após o envio da doação.

### Via API do RabbitMQ

```bash
curl -u fiapdonate:sua-senha http://localhost:15672/api/queues/%2F/doacao-recebida-queue
```

Para listar as filas:

```bash
curl -u fiapdonate:sua-senha http://localhost:15672/api/queues
```

Para verificar diretamente via container local:

```bash
docker exec -it fiapdonate-rabbitmq rabbitmqctl list_queues name messages consumers
```

Se a fila `doacao-recebida-queue` estiver recebendo mensagens, o fluxo de processamento assíncrono está funcionando.

## Observação importante

Os nomes de serviços e contratos de fila/exchange foram mantidos como convenções consistentes para a infraestrutura. Quando os projetos dos demais integrantes estiverem disponíveis, os valores devem ser alinhados aos contratos reais e não duplicados.
