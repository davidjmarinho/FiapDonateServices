# Integração com o FiapDonateServices

Este documento explica, para o repositório `FiapDonateServices`, como o `FiapDonateWorker` foi construído, quais dependências ele possui e como conectá-lo corretamente ao ambiente orquestrado.

## Objetivo do Worker

O `FiapDonateWorker` é o serviço responsável por consumir eventos de doação recebida e refletir esse processamento no banco de dados.

Fluxo funcional:

1. O serviço produtor publica o evento `DoacaoRecebidaEvent` no RabbitMQ.
2. O `FiapDonateWorker` consome a mensagem da fila `doacao-recebida-queue`.
3. O Worker verifica se a doação já foi processada.
4. O Worker localiza a campanha correspondente no banco.
5. Se a campanha estiver ativa, incrementa `ValorArrecadado`.
6. A doação é registrada na tabela `Doacoes` com status `Creditada` ou `Rejeitada`.

## Como a aplicação foi construída

O projeto segue uma separação simples por camadas:

- `src/FiapDonateWorker.Api`
  - Host ASP.NET Core da aplicação
  - Configuração de DI, MassTransit, health checks e métricas
  - Consumer do RabbitMQ

- `src/FiapDonateWorker.Domain`
  - Entidades de domínio
  - Regras de negócio para decidir se uma doação deve ser creditada ou rejeitada

- `src/FiapDonateWorker.Infrastructure`
  - Persistência com EF Core
  - Mapeamento das tabelas
  - Repositório de processamento da doação
  - Migrations da tabela `Doacoes`

## Tecnologias usadas

- .NET 8
- ASP.NET Core
- MassTransit
- RabbitMQ
- Entity Framework Core
- SQL Server
- Prometheus.NET para métricas

## Dependências externas esperadas

O `FiapDonateServices`, como orquestrador, precisa disponibilizar para o Worker:

- um broker RabbitMQ acessível pela aplicação
- um SQL Server acessível pela aplicação
- uma base `conexao_solidaria` contendo a tabela `Campanhas`

O Worker cria e mantém apenas sua tabela `Doacoes` por migration automática no startup. A tabela `Campanhas` não pertence a este repositório.

## Contrato com o banco de dados

O ponto mais importante da integração com o `FiapDonateServices` está no contrato da tabela `Campanhas`.

O Worker espera:

- tabela `Campanhas` já existente
- coluna `Id` como identificador da campanha
- coluna `Status` gravada como texto
- coluna `ValorArrecadado` compatível com `decimal(18,2)`

Valores aceitos para `Status`:

- `Ativa`
- `Concluida`
- `Cancelada`

Esses valores precisam estar exatamente assim. Se o serviço orquestrador gravar outro texto, outro casing ou um valor numérico, o Worker deixará de reconhecer a campanha como ativa e passará a rejeitar as doações.

## Contrato do evento

O evento consumido é `DoacaoRecebidaEvent`, com o seguinte payload lógico:

```json
{
  "doacaoId": "GUID",
  "idCampanha": "GUID",
  "valorDoacao": 50.00,
  "dataHoraRecebida": "2026-08-17T12:00:00Z"
}
```

Campos:

- `doacaoId`: identificador único da doação
- `idCampanha`: identificador da campanha alvo
- `valorDoacao`: valor recebido
- `dataHoraRecebida`: data/hora original do recebimento

## Contrato de mensageria com RabbitMQ

O Worker usa MassTransit e escuta a fila:

- `doacao-recebida-queue`

Para compatibilidade com o formato já esperado pelo consumer, o produtor no `FiapDonateServices` deve publicar no envelope do MassTransit. Exemplo:

```json
{
  "message": {
    "doacaoId": "22222222-2222-2222-2222-222222222222",
    "idCampanha": "11111111-1111-1111-1111-111111111111",
    "valorDoacao": 50.00,
    "dataHoraRecebida": "2026-08-17T12:00:00Z"
  },
  "messageType": [
    "urn:message:FiapDonateWorker.Api.Events:DoacaoRecebidaEvent"
  ]
}
```

Também é importante usar o header:

- `content_type: application/vnd.masstransit+json`

Se o `FiapDonateServices` também usar MassTransit com o mesmo contrato de mensagem, a integração tende a ser direta.

## Configurações que o orquestrador deve fornecer

O Worker lê sua configuração por `appsettings` ou variáveis de ambiente.

### Banco

- `ConnectionStrings__WorkerDb`

Exemplo:

```text
Server=sqlserver,1433;Database=conexao_solidaria;User Id=sa;Password=CHANGE_ME;TrustServerCertificate=True;
```

### RabbitMQ

- `RabbitMq__Host`
- `RabbitMq__VirtualHost`
- `RabbitMq__Username`
- `RabbitMq__Password`

Exemplo:

```text
RabbitMq__Host=rabbitmq
RabbitMq__VirtualHost=/
RabbitMq__Username=guest
RabbitMq__Password=guest
```

## Como conectar no FiapDonateServices via Docker Compose

Se o `FiapDonateServices` for o repositório que sobe toda a stack local, ele precisa garantir que:

1. O container do Worker esteja na mesma rede do `rabbitmq` e do `sqlserver`.
2. Os nomes DNS internos usados nas variáveis de ambiente coincidam com os nomes dos serviços do Compose.
3. A base `conexao_solidaria` esteja acessível ao Worker.

Exemplo de configuração esperada para o serviço do Worker dentro do Compose do orquestrador:

```yaml
fiapdonateworker:
  build:
    context: ../FiapDonateWorker
  environment:
    ConnectionStrings__WorkerDb: Server=sqlserver,1433;Database=conexao_solidaria;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;
    RabbitMq__Host: rabbitmq
    RabbitMq__VirtualHost: /
    RabbitMq__Username: guest
    RabbitMq__Password: guest
  depends_on:
    - sqlserver
    - rabbitmq
  ports:
    - "8080:8080"
```

Se o orquestrador usar outro nome para os serviços, basta refletir isso nas variáveis de ambiente do Worker.

## Como conectar no FiapDonateServices via Kubernetes

No Kubernetes, o orquestrador deve fornecer:

1. Um `ConfigMap` com host, virtual host e usuário do RabbitMQ.
2. Um `Secret` com a senha do RabbitMQ e a connection string do SQL Server.
3. Um `Deployment` com a imagem do Worker.
4. Um `Service` interno para expor a porta HTTP do Worker, se necessário.

Os manifests deste repositório já seguem essa ideia:

- `k8s/configmap.yaml`
- `k8s/secret.example.yaml`
- `k8s/deployment.yaml`
- `k8s/service.yaml`

No cluster do `FiapDonateServices`, os nomes abaixo precisam apontar para serviços reais e acessíveis:

- `rabbitmq`
- `sqlserver`

Se os Services tiverem nomes diferentes, ajuste:

- `RabbitMq__Host`
- `ConnectionStrings__WorkerDb`

## Endpoints expostos pelo Worker

O Worker expõe HTTP na porta `8080`.

Endpoints disponíveis:

- `/`
  - retorna status simples do serviço
- `/health/live`
  - valida apenas se o processo está em execução
- `/health/ready`
  - valida SQL Server e RabbitMQ
- `/health`
  - alias de `/health/ready`
- `/metrics`
  - endpoint Prometheus

Isso permite ao `FiapDonateServices` usar health checks, probes e observabilidade sem acoplamento extra.

## Comportamentos importantes para a orquestração

- O Worker aplica `migrations` automaticamente ao iniciar.
- O processamento é idempotente com base no `DoacaoId`.
- Há retry imediato no consumo da mensagem em caso de falha transitória.
- O incremento em `ValorArrecadado` usa controle de concorrência otimista para evitar perda de atualização.

## Checklist de integração

Antes de considerar a integração pronta no `FiapDonateServices`, valide:

1. O Worker consegue resolver DNS do RabbitMQ e do SQL Server.
2. A string `ConnectionStrings__WorkerDb` aponta para a mesma base onde está `Campanhas`.
3. A tabela `Campanhas` possui `Status` com os nomes esperados pelo Worker.
4. O produtor publica no formato de mensagem compatível com MassTransit.
5. A fila `doacao-recebida-queue` está acessível ao Worker.
6. O endpoint `/health/ready` responde com sucesso após subir a infraestrutura.
7. O endpoint `/metrics` fica disponível para observabilidade.

## Resumo prático

O `FiapDonateServices` deve tratar o `FiapDonateWorker` como um consumidor independente, conectado ao mesmo RabbitMQ e ao mesmo banco lógico usado pela solução. A integração depende de três contratos estáveis:

- contrato da mensagem `DoacaoRecebidaEvent`
- contrato da tabela `Campanhas`
- injeção correta das configurações de infraestrutura

Se esses três pontos forem preservados, o Worker pode ser plugado ao ambiente orquestrado sem necessidade de alteração de código.