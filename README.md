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

Acesse:

- API: http://localhost:8090
- Health: http://localhost:8090/health
- Métricas: http://localhost:8090/metrics
- RabbitMQ UI: http://localhost:15672
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

## Observação importante

Os nomes de serviços e contratos de fila/exchange foram mantidos como convenções consistentes para a infraestrutura. Quando os projetos dos demais integrantes estiverem disponíveis, os valores devem ser alinhados aos contratos reais e não duplicados.
