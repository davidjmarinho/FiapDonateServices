# Status de containerização

## Implementado

- `Dockerfile` multi-stage para a API `FiapDonateCampaign.API` em .NET 8, exposta na porta `8080`.
- `docker-compose.yml` para a API e o SQL Server 2022, usando a rede interna do Compose.
- `k8s/configmap.yaml`, `k8s/deployment.yaml` e `k8s/service.yaml` para o deploy da API.
- `k8s/secret.example.yaml` como modelo seguro para a connection string e a chave JWT.
- `.env.example` e `.dockerignore` para evitar o envio de segredos e artefatos de build à imagem.

## Uso local

1. Copie `.env.example` para `.env` e substitua os dois placeholders por valores seguros.
2. Suba a API e o SQL Server com `docker compose up --build`.
3. A API ficará disponível em `http://localhost:8080`.

## Uso no Kubernetes

1. Crie `k8s/secret.yaml` a partir de `k8s/secret.example.yaml`, sem versioná-lo.
2. Garanta que o host `sqlserver` da connection string resolva para um Service SQL Server acessível no mesmo namespace. Ajuste o host se a infraestrutura usar outro nome.
3. Aplique `k8s/configmap.yaml`, `k8s/secret.yaml`, `k8s/deployment.yaml` e `k8s/service.yaml`.

## Limitações verificadas

- A API não expõe endpoints de health check. Por isso, as probes usam TCP na porta HTTP; elas verificam que o processo aceita conexões, mas não validam o SQL Server. Quando `/health/live` e `/health/ready` forem implementados, as probes devem passar a usar esses endpoints.
- A aplicação não aplica migrations automaticamente no startup. Antes de atender tráfego contra um banco vazio, as migrations de `AppDbContext` precisam ser aplicadas pela etapa de deploy apropriada.
- Embora exista documentação de um contrato RabbitMQ, a implementação registrada é `LogEventPublisher`, e não há configuração RabbitMQ consumida pela aplicação. RabbitMQ foi intencionalmente omitido do Compose e dos manifests para não provisionar uma dependência sem uso efetivo.