# Docker e Kubernetes

Este documento resume como o projeto está configurado para execução local com Docker e para deploy em Kubernetes.

## docker-compose.yml

O arquivo `docker-compose.yml` sobe apenas as dependências externas necessárias para desenvolvimento local:

- `sqlserver`
  - Imagem: `mcr.microsoft.com/mssql/server:2022-latest`
  - Porta exposta: `1433:1433`
  - Variáveis de ambiente:
    - `ACCEPT_EULA=Y`
    - `MSSQL_SA_PASSWORD=YourStrong!Passw0rd`
  - Volume persistente: `sqlserver-data:/var/opt/mssql`

- `rabbitmq`
  - Imagem: `rabbitmq:3.13-management`
  - Portas expostas:
    - `5672:5672` para AMQP
    - `15672:15672` para a interface de gerenciamento

Também existe o volume nomeado `sqlserver-data`, usado para manter os dados do SQL Server entre reinicializações.

## Dockerfile

O `Dockerfile` usa build multi-stage para gerar a imagem final da aplicação:

1. Stage `build`
   - Base: `mcr.microsoft.com/dotnet/sdk:8.0`
   - Define `WORKDIR /src`
   - Copia a solution e os projetos `Api`, `Infrastructure` e `Domain`
   - Executa `dotnet restore` para a API
   - Copia o restante do código-fonte
   - Executa `dotnet publish` em Release para `src/FiapDonateWorker.Api/FiapDonateWorker.Api.csproj`

2. Stage `final`
   - Base: `mcr.microsoft.com/dotnet/aspnet:8.0`
   - Define `WORKDIR /app`
   - Copia os arquivos publicados do stage anterior
   - Expõe a porta `8080`
   - Inicia a aplicação com `dotnet FiapDonateWorker.Api.dll`

Em resumo, a imagem final contém apenas o runtime ASP.NET Core e os artefatos publicados, sem o SDK.

## Pasta k8s/

A pasta `k8s/` reúne os manifests para deploy local em Kubernetes.

### configmap.yaml

Cria o `ConfigMap` `fiapdonateworker-config` com configurações não sensíveis da aplicação:

- `RabbitMq__Host=rabbitmq`
- `RabbitMq__VirtualHost=/`
- `RabbitMq__Username=guest`

O host `rabbitmq` assume que o Service do RabbitMQ existe no cluster com esse nome. Se a infraestrutura compartilhada usar outro nome, esse valor deve ser ajustado.

### secret.example.yaml

É um exemplo de `Secret` chamado `fiapdonateworker-secret`.

- `RabbitMq__Password=guest`
- `ConnectionStrings__WorkerDb=Server=sqlserver,1433;Database=conexao_solidaria;User Id=sa;Password=CHANGE_ME;TrustServerCertificate=True;`

Esse arquivo serve como modelo para criar o `secret.yaml` real antes do deploy. O host `sqlserver` também pressupõe que exista um Service com esse nome no cluster.

### deployment.yaml

Define o `Deployment` `fiapdonateworker` com `1` réplica.

- Label selector: `app=fiapdonateworker`
- Container:
  - Nome: `worker`
  - Imagem: `fiapdonateworker:local`
  - `imagePullPolicy: IfNotPresent`
  - Porta do container: `8080`
- Variáveis de ambiente:
  - Carrega tudo do `ConfigMap` `fiapdonateworker-config`
  - Carrega tudo do `Secret` `fiapdonateworker-secret`
- Probes:
  - `livenessProbe` em `/health/live` na porta `8080`
  - `readinessProbe` em `/health/ready` na porta `8080`

As probes usam delays e intervalos diferentes para separar disponibilidade do processo e prontidão das dependências externas.

### service.yaml

Cria o `Service` `fiapdonateworker` do tipo `ClusterIP`.

- Seleciona os pods com `app=fiapdonateworker`
- Expõe a porta `8080`
- Encaminha para `targetPort: 8080`

Esse Service é destinado ao tráfego interno do cluster.

## Fluxo de uso

Para subir tudo localmente com Kubernetes, o fluxo esperado é:

1. Buildar a imagem local com `docker build -t fiapdonateworker:local .`
2. Criar o `k8s/secret.yaml` com base em `k8s/secret.example.yaml`
3. Aplicar os manifests com `kubectl apply -f k8s/configmap.yaml -f k8s/secret.yaml -f k8s/deployment.yaml -f k8s/service.yaml`

## Observação importante

O `docker-compose.yml` e os manifests de `k8s/` foram pensados para suportar o Worker com dependências externas. Eles não substituem a infraestrutura compartilhada da solução completa, apenas facilitam execução local e deploy controlado.