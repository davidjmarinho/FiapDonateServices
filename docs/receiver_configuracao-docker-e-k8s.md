# Configuração atual de Docker e Kubernetes

## 1. Visão geral

Este documento descreve como estão configurados atualmente os arquivos de containerização e orquestração do projeto `FiapDonateReceiver`.

Os arquivos analisados foram:

- `Dockerfile`
- `docker-compose.yml`
- `k8s/configmap.yaml`
- `k8s/deployment.yaml`
- `k8s/service.yaml`
- `k8s/secret.example.yaml`

A pasta `k8s` contém hoje os seguintes arquivos:

- `configmap.yaml`
- `deployment.yaml`
- `secret.example.yaml`
- `service.yaml`

---

## 2. Dockerfile

O arquivo `Dockerfile` está configurado para gerar a imagem do serviço `FiapDonateReceiver.Worker` usando build em múltiplas etapas.

### Estrutura atual

#### Etapa 1: build

A imagem base usada para compilação é:

```dockerfile
mcr.microsoft.com/dotnet/sdk:8.0
```

Nessa etapa:

- o diretório de trabalho é `/src`;
- o arquivo de solução `FiapDonateReceiver.slnx` é copiado para a imagem;
- os arquivos `.csproj` dos projetos `Worker`, `Infrastructure` e `Domain` são copiados separadamente;
- o comando `dotnet restore` é executado para restaurar as dependências do projeto `FiapDonateReceiver.Worker`;
- depois toda a pasta `src/` é copiada;
- o projeto `FiapDonateReceiver.Worker` é publicado em modo `Release` no diretório `/app/publish`.

Comando usado no publish:

```dockerfile
dotnet publish "src/FiapDonateReceiver.Worker/FiapDonateReceiver.Worker.csproj" -c Release -o /app/publish --no-restore
```

#### Etapa 2: runtime

A imagem final usada para execução é:

```dockerfile
mcr.microsoft.com/dotnet/aspnet:8.0
```

Nessa etapa:

- o diretório de trabalho é `/app`;
- os arquivos publicados da etapa anterior são copiados para a imagem final;
- a porta `8080` é exposta;
- o processo inicial executado é:

```dockerfile
ENTRYPOINT ["dotnet", "FiapDonateReceiver.Worker.dll"]
```

### Objetivo do Dockerfile

Essa configuração empacota apenas o serviço `FiapDonateReceiver.Worker`, que é o processo responsável por:

- consumir eventos RabbitMQ;
- processar doações;
- atualizar o banco PostgreSQL;
- expor endpoints HTTP como `/health` e `/metrics`.

---

## 3. docker-compose.yml

O arquivo `docker-compose.yml` atual sobe apenas a infraestrutura local mínima necessária para o worker funcionar em desenvolvimento.

### Serviços definidos

#### 3.1 PostgreSQL

Serviço:

```yaml
postgres:
  image: postgres:16
```

Configuração atual:

- banco: `conexao_solidaria`
- usuário: `postgres`
- senha: `postgres`
- porta publicada: `5432:5432`
- volume persistente: `postgres-data:/var/lib/postgresql/data`

Variáveis de ambiente configuradas:

```yaml
POSTGRES_DB: conexao_solidaria
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
```

Função desse container:

- armazenar os dados usados pelo worker;
- manter a tabela `Doacoes`;
- permitir acesso à tabela `Campanhas`, que é compartilhada com o outro serviço do ecossistema.

#### 3.2 RabbitMQ

Serviço:

```yaml
rabbitmq:
  image: rabbitmq:3.13-management
```

Configuração atual:

- porta AMQP: `5672:5672`
- interface de management: `15672:15672`

Função desse container:

- receber e disponibilizar os eventos de doação para consumo;
- permitir inspeção manual das filas pela interface web do RabbitMQ.

### Volumes definidos

O compose define um volume nomeado:

```yaml
postgres-data:
```

Esse volume é usado para persistir os dados do PostgreSQL entre reinicializações dos containers.

### Escopo atual do compose

O arquivo não sobe:

- o serviço `FiapDonateReceiver.Worker`;
- a API de campanhas;
- a API de usuários;
- Prometheus;
- Grafana;
- outros componentes de observabilidade.

Ou seja, ele sobe apenas os serviços de apoio para desenvolvimento local do worker.

---

## 4. Pasta k8s

A pasta `k8s` contém os manifests Kubernetes básicos para publicar o worker no cluster.

Estrutura atual:

```text
k8s/
  configmap.yaml
  deployment.yaml
  secret.example.yaml
  service.yaml
```

---

## 5. k8s/configmap.yaml

Esse arquivo define um `ConfigMap` chamado:

```yaml
fiapdonatereceiver-worker-config
```

### Dados configurados

```yaml
RabbitMq__Host: "rabbitmq"
RabbitMq__VirtualHost: "/"
RabbitMq__Username: "guest"
```

### Finalidade

Esse `ConfigMap` fornece configurações não sensíveis para o worker, especialmente relacionadas ao RabbitMQ.

Na configuração atual:

- o host do broker está definido como `rabbitmq`;
- o virtual host é `/`;
- o usuário é `guest`.

Esses valores são carregados pelo container por meio de `envFrom` no deployment.

---

## 6. k8s/secret.example.yaml

Esse arquivo é um exemplo de `Secret` Kubernetes chamado:

```yaml
fiapdonatereceiver-worker-secret
```

### Dados definidos no exemplo

```yaml
RabbitMq__Password: "guest"
ConnectionStrings__ReceiverDb: "Host=postgres;Port=5432;Database=conexao_solidaria;Username=postgres;Password=postgres"
```

### Finalidade

Esse arquivo concentra os dados sensíveis necessários para o worker iniciar.

Ele inclui:

- senha do RabbitMQ;
- connection string do banco PostgreSQL.

### Observação importante

O arquivo presente no repositório é apenas um exemplo. O fluxo sugerido pelo próprio projeto é copiar esse arquivo para um `secret.yaml` local antes de aplicar no cluster.

---

## 7. k8s/deployment.yaml

Esse arquivo define um `Deployment` chamado:

```yaml
fiapdonatereceiver-worker
```

### Configuração principal

- `replicas: 1`
- label principal: `app: fiapdonatereceiver-worker`
- container com nome `worker`
- imagem usada:

```yaml
fiapdonatereceiver-worker:local
```

- `imagePullPolicy: IfNotPresent`
- porta exposta pelo container: `8080`

### Injeção de variáveis de ambiente

O container consome variáveis a partir de:

- `configMapRef: fiapdonatereceiver-worker-config`
- `secretRef: fiapdonatereceiver-worker-secret`

Isso significa que o deployment depende diretamente da existência prévia desses objetos no cluster.

### Probes configuradas

#### Liveness probe

```yaml
path: /health/live
port: 8080
initialDelaySeconds: 15
periodSeconds: 15
```

Essa probe verifica se o processo está vivo.

#### Readiness probe

```yaml
path: /health/ready
port: 8080
initialDelaySeconds: 5
periodSeconds: 10
```

Essa probe verifica se o serviço está pronto para receber tráfego e operar com suas dependências.

### Finalidade do deployment

Esse manifesto sobe o worker como um pod HTTP em Kubernetes, permitindo:

- consumo do RabbitMQ em background;
- exposição dos endpoints de saúde;
- integração futura com scraping de métricas via service interno.

---

## 8. k8s/service.yaml

Esse arquivo define um `Service` do tipo:

```yaml
ClusterIP
```

Nome do serviço:

```yaml
fiapdonatereceiver-worker
```

### Configuração de rede

- selector: `app: fiapdonatereceiver-worker`
- porta do serviço: `8080`
- `targetPort: 8080`

### Finalidade

Esse serviço expõe o worker internamente dentro do cluster Kubernetes.

Como ele é `ClusterIP`, o acesso é interno ao cluster. Isso é suficiente para:

- probes;
- scraping por Prometheus, se configurado depois;
- comunicação interna entre pods, caso necessária.

---

## 9. Relação entre os arquivos

A configuração atual funciona da seguinte forma:

1. O `Dockerfile` gera a imagem do worker.
2. O `docker-compose.yml` sobe PostgreSQL e RabbitMQ para desenvolvimento local.
3. O `ConfigMap` fornece configuração não sensível do RabbitMQ em Kubernetes.
4. O `Secret` fornece senha do RabbitMQ e string de conexão com o PostgreSQL.
5. O `Deployment` sobe o container do worker usando esses dados.
6. O `Service` expõe o worker internamente no cluster.

---

## 10. Resumo do estado atual

Hoje a configuração de Docker e Kubernetes do projeto está focada no microsserviço `FiapDonateReceiver.Worker`.

### Já existe

- `Dockerfile` multi-stage para build e runtime do worker;
- `docker-compose.yml` com PostgreSQL e RabbitMQ;
- manifests Kubernetes básicos para `ConfigMap`, `Secret`, `Deployment` e `Service`;
- probes de liveness e readiness apontando para `/health/live` e `/health/ready`.

### Ainda não aparece nesses arquivos

- execução do worker dentro do `docker-compose.yml`;
- manifests para outros microsserviços do ecossistema;
- ingress;
- Prometheus e Grafana;
- volumes persistentes Kubernetes explícitos;
- namespace dedicado;
- autoscaling.

Em resumo, o estado atual cobre bem o empacotamento do worker e a infraestrutura mínima necessária para rodá-lo localmente ou em um cluster Kubernetes simples.
