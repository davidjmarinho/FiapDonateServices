# Integração do FiapDonateCampaign

## Infraestrutura provisionada

O Campaign é preparado como uma API HTTP independente na porta `8080`:

- DNS Docker: `fiapdonatecampaign`;
- DNS Kubernetes: `http://fiapdonatecampaign:8080`;
- banco SQL Server: `FiapDonateDb` no host `sqlserver`;
- imagem Kubernetes: `fiapdonatecampaign:local`.

O overlay [docker-compose.integrations.yml](../docker-compose.integrations.yml) constrói o repositório irmão `../FiapDonateCampaign` e injeta somente configurações não sensíveis como variáveis de ambiente. A connection string e `Jwt__Key` são lidos de Docker Secrets em runtime.

## Kubernetes

O manifesto [k8s/campaign/deployment.yaml](../k8s/campaign/deployment.yaml) cria:

- `ConfigMap` `fiapdonatecampaign-config`;
- `Deployment` `fiapdonatecampaign`;
- `Service` interno `fiapdonatecampaign`.

O deploy requer o Secret não versionado `fiapdonatecampaign-secrets`, com as chaves:

- `ConnectionStrings__DefaultConnection`;
- `Jwt__Key`.

As probes são TCP porque a versão atual da API não fornece endpoints de health. O Prometheus não coleta essa API enquanto ela não expuser `/metrics`.

## Migrations e dependências de domínio

A API não aplica migrations no startup. Antes de direcionar tráfego, o pipeline deve aplicar as migrations de `AppDbContext` para `FiapDonateDb`. As tabelas Identity pertencem ao `FiapDonateUsers`, portanto o schema e os usuários devem existir no banco compartilhado antes de usar login ou endpoints autorizados.

A publicação RabbitMQ não foi ativada: a implementação efetiva de `IEventPublisher` é `LogEventPublisher`. Por isso, esta infraestrutura não declara o Campaign como produtor de eventos. Quando o repositório trocar para um publisher MassTransit/RabbitMQ, deverá publicar para o contrato já provisionado do Worker:

- exchange `FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`;
- fila `doacao-recebida-queue`;
- tipo `urn:message:FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`;
- `content_type` `application/vnd.masstransit+json`.

## Pendências de integração

O Campaign registra campanhas em `FiapDonateDb` (SQL Server), enquanto o Worker atualmente espera a tabela `Campanhas` em `conexao_solidaria` (também SQL Server). Antes do fluxo de doação assíncrono ser considerado integrado, a equipe deve alinhar o banco proprietário da tabela `Campanhas` e atualizar a connection string do Worker ou a arquitetura de integração.

A chave JWT, issuer e audience do Campaign também devem ser alinhados com o serviço proprietário de autenticação antes de liberar autenticação compartilhada entre serviços.
