# Secrets do Kubernetes

Não versione manifestos com credenciais. Crie os secrets diretamente no cluster ou pelo pipeline de CI/CD.

Os deployments esperam estes secrets:

- `fiapdonate-secrets`: `JWT_KEY`, `RabbitMQ__Password`, `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`.
- `fiapdonate-worker-secrets`: `RabbitMq__Password`, `ConnectionStrings__WorkerDb`.
- `fiapdonate-receiver-secrets`: `RabbitMq__Password`, `ConnectionStrings__ReceiverDb`.
- `fiapdonate-users-secrets`: `ConnectionStrings__DefaultConnection`, `Jwt__Key`.
- `fiapdonatecampaign-secrets`: `ConnectionStrings__DefaultConnection`, `Jwt__Key`, `RabbitMq__Password`.

`ConnectionStrings__WorkerDb` e `ConnectionStrings__DefaultConnection` apontam para SQL Server. `ConnectionStrings__ReceiverDb` aponta para PostgreSQL, conforme os contratos recebidos dos respectivos serviços.
