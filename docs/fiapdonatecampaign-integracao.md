# Integração do FiapDonateCampaign com o FiapDonateServices

Este documento descreve os artefatos, contratos e dependências que o repositório `FiapDonateServices` deve considerar para executar o `FiapDonateCampaign` na plataforma distribuída.

## Responsabilidade do serviço

O `FiapDonateCampaign` expõe a API HTTP responsável por campanhas e pelo registro da intenção de doação. A aplicação é desenvolvida em .NET 8, usa SQL Server e valida autenticação JWT contra as tabelas ASP.NET Identity compartilhadas.

O projeto é composto pelos módulos:

- `FiapDonateCampaign.API`: host HTTP ASP.NET Core;
- `FiapDonateCampaign.Application`: casos de uso e DTOs;
- `FiapDonateCampaign.Domain`: entidades e regras de domínio;
- `FiapDonateCampaign.Infrastructure`: EF Core, repositórios, Identity e autenticação.

## Artefatos de execução fornecidos

O repositório contém os seguintes artefatos para uso pelo orquestrador:

| Artefato | Finalidade |
| --- | --- |
| `Dockerfile` | Gera a imagem da API em duas etapas, usando .NET SDK 8 para build e ASP.NET Core Runtime 8 para execução. |
| `docker-compose.yml` | Executa a API e um SQL Server local para desenvolvimento isolado. |
| `k8s/configmap.yaml` | Configura valores não sensíveis da API. |
| `k8s/secret.example.yaml` | Modelo de Secret com a connection string e a chave JWT. |
| `k8s/deployment.yaml` | Executa uma réplica da API na porta `8080`. |
| `k8s/service.yaml` | Expõe a API internamente no cluster com o Service `fiapdonatecampaign`. |

## Imagem e porta HTTP

A imagem padrão prevista pelo Deployment é:

```text
fiapdonatecampaign:local
```

A aplicação escuta HTTP na porta `8080`. Em Kubernetes, os demais serviços devem utilizar o DNS interno:

```text
http://fiapdonatecampaign:8080
```

O Service é `ClusterIP`; não há Ingress configurado neste repositório. A exposição externa, se necessária, deve ser definida pelo `FiapDonateServices`.

## Configurações necessárias

O .NET converte variáveis de ambiente com `__` em seções de configuração. O orquestrador deve fornecer:

| Variável | Sensível | Valor esperado |
| --- | --- | --- |
| `ASPNETCORE_ENVIRONMENT` | Não | `Production` |
| `ASPNETCORE_URLS` | Não | `http://+:8080` |
| `ConnectionStrings__DefaultConnection` | Sim | Connection string SQL Server que aponta para o banco compartilhado. |
| `Jwt__Key` | Sim | Chave de assinatura JWT, com pelo menos 32 caracteres aleatórios. |
| `Jwt__Issuer` | Não | `FiapDonateCampaign` na configuração atual. |
| `Jwt__Audience` | Não | `FiapDonateCampaignUsers` na configuração atual. |

No Kubernetes, o ConfigMap `fiapdonatecampaign-config` fornece as configurações não sensíveis e o Secret `fiapdonatecampaign-secrets` fornece `ConnectionStrings__DefaultConnection` e `Jwt__Key`.

O Secret real **não deve ser versionado**. O arquivo `k8s/secret.example.yaml` deve ser usado apenas como modelo.

## Banco de dados e migrations

O serviço utiliza SQL Server com `Microsoft.EntityFrameworkCore.SqlServer`.

- Banco usado pelo Compose local: `FiapDonateDb`.
- Host interno do Compose: `sqlserver`.
- A conexão Kubernetes de exemplo também usa o host `sqlserver`; esse valor deve ser ajustado caso o Service do banco tenha outro nome.
- A API é dona das migrations de campanhas e doações, executadas por `AppDbContext`.
- As tabelas do ASP.NET Identity são consultadas via `IdentityStoreDbContext`, mas as migrations delas **não** pertencem a este repositório; elas devem existir no banco que atende o `FiapDonateUsers`.
- A aplicação não executa migrations automaticamente no startup. O pipeline/deploy deve aplicar as migrations de `AppDbContext` antes de direcionar tráfego a um banco novo.

## Endpoints HTTP atuais

| Método | Rota | Autorização |
| --- | --- | --- |
| `POST` | `/api/auth/login` | Pública; valida o usuário armazenado no Identity. |
| `POST` | `/api/campaign` | JWT com role `GestorONG`. |
| `PUT` | `/api/campaign/{id}` | JWT com role `GestorONG`. |
| `GET` | `/api/campaign/ativas` | JWT válido. |
| `GET` | `/api/campaign/{id}` | JWT válido. |
| `POST` | `/api/doacoes` | JWT com role `Doador`. |

O endpoint de login emite um token assinado com os valores `Jwt__Issuer`, `Jwt__Audience` e `Jwt__Key` configurados nesta API. Caso todos os serviços validem os mesmos tokens, o `FiapDonateServices` deve coordenar os valores de emissor, audiência e chave com o repositório proprietário da autenticação antes do deploy integrado.

## Health checks, métricas e probes

No estado atual, a API não expõe `/health`, `/health/live`, `/health/ready` nem `/metrics`.

Por isso, o Deployment usa probes TCP na porta `8080`:

- liveness: verifica que o processo aceita conexões;
- readiness: verifica que a porta HTTP está disponível.

Essas probes não validam a conectividade com o SQL Server. Quando health checks forem implementados pela API, o `FiapDonateServices` deve substituir as probes TCP pelos endpoints HTTP correspondentes e configurar o scrape Prometheus apenas quando houver endpoint de métricas real.

## RabbitMQ e evento de doação

O projeto contém o contrato `DoacaoRecebidaEvent` e cria esse evento quando recebe `POST /api/doacoes`. Contudo, a implementação ativa de `IEventPublisher` é `LogEventPublisher`, que apenas registra a publicação em log. A classe `RabbitMqEventPublisher` é um scaffold e não está registrada em DI nem conectada a um broker.

Consequentemente:

- RabbitMQ não é uma dependência operacional atual do `FiapDonateCampaign`;
- o Compose e os manifests deste repositório não criam ou configuram RabbitMQ;
- o fluxo assíncrono Campaign → RabbitMQ → Worker não está ativo;
- o `FiapDonateServices` não deve assumir que uma intenção registrada neste serviço já chega ao Worker.

Quando a publicação real for implementada, a equipe deve alinhar o produtor ao contrato MassTransit documentado em `docs/worker-receiver-integration.md`: exchange `FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`, fila `doacao-recebida-queue`, content type `application/vnd.masstransit+json` e message type `urn:message:FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`.

## Execução pelo FiapDonateServices

Para integrar em Docker Compose centralizado:

1. Construa a imagem a partir deste repositório ou publique-a em um registry acessível.
2. Injete as variáveis listadas na seção de configuração.
3. Garanta que o host SQL Server da connection string seja resolvido na rede interna do Compose.
4. Exponha a porta `8080` apenas se o acesso externo for necessário.
5. Execute a migration de `AppDbContext` antes de iniciar o tráfego.

Para integrar em Kubernetes:

1. Publique a imagem em um registry acessível ao cluster e substitua `fiapdonatecampaign:local` no Deployment pelo nome e tag publicados.
2. Crie o Secret real a partir de `k8s/secret.example.yaml`.
3. Garanta que a connection string aponta para um SQL Server acessível via DNS do cluster.
4. Aplique ConfigMap, Secret, Deployment e Service no mesmo namespace da infraestrutura dependente.
5. Use `http://fiapdonatecampaign:8080` para a comunicação interna.

## Bloqueios e alinhamentos pendentes

| Assunto | Estado atual | Impacto | Responsável pela definição |
| --- | --- | --- | --- |
| JWT compartilhado | Issuer e audience locais, chave injetada por ambiente. | Tokens emitidos por outro serviço podem falhar se os valores não coincidirem. | Equipe de autenticação e `FiapDonateServices`. |
| Identity compartilhado | A Campaign consulta tabelas Identity, mas não as cria. | Login e autorização dependem de schema e usuários previamente provisionados. | `FiapDonateUsers`. |
| Migrations | Não são automáticas. | Banco vazio impede a execução funcional. | Pipeline/deploy do `FiapDonateServices`. |
| Health e métricas | Não implementados. | Não há readiness por dependência nem observabilidade Prometheus real. | `FiapDonateCampaign`. |
| RabbitMQ | Publicador real não está ativo. | Intenções de doação não são processadas pelo Worker de forma assíncrona. | `FiapDonateCampaign` em conjunto com Receiver/Worker. |