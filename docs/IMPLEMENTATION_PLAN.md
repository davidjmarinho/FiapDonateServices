# FiapDonateServices — Plano de Implementação

## 1. Objetivo

O `FiapDonateServices` será o **projeto de infraestrutura, integração, execução e observabilidade** da plataforma FiapDonate.

Este projeto não deve implementar regras de negócio de usuários, campanhas ou doações. Sua responsabilidade é garantir que os serviços desenvolvidos pelos demais integrantes possam ser executados juntos, configurados corretamente, comunicarem-se pela rede interna e sejam monitorados e entregues por CI/CD.

### Serviços da solução

| Serviço | Responsabilidade |
|---|---|
| `FiapDonateUsers` | Usuários, cadastro, autenticação, JWT e autorização |
| `FiapDonateCampaign` | Campanhas e transparência |
| `FiapDonateReceiver` | Entrada da intenção de doação e publicação do evento |
| `FiapDonateWorker` | Consumo assíncrono e processamento da doação |
| `FiapDonateServices` | Infraestrutura, integração, Kubernetes, observabilidade e CI/CD |

---

## Status da execução atual

### Auditoria concluída

- [x] Analisar o conteúdo atual do `FiapDonateServices`.
- [x] Identificar arquivos existentes.
- [x] Identificar Dockerfiles.
- [x] Identificar Docker Compose.
- [x] Identificar Kubernetes.
- [x] Identificar GitHub Actions.
- [x] Identificar configurações existentes.
- [x] Identificar observabilidade.
- [x] Identificar dependências externas.
- [x] Registrar bloqueio por ausência dos demais repositórios no workspace.

### Base implementada

- [x] Estrutura .NET da solução principal.
- [x] Aplicação com endpoints de health, ready, status e métricas.
- [x] Dockerfile base para empacotamento da API.
- [x] Docker Compose para API, RabbitMQ, Prometheus e Grafana.
- [x] Estrutura inicial de manifests Kubernetes.
- [x] GitHub Actions para build e empacotamento Docker.
- [x] Documentação inicial e status de implementação.

> Observação: os contratos de negócio e a integração real com `FiapDonateUsers`, `FiapDonateCampaign`, `FiapDonateReceiver` e `FiapDonateWorker` dependem dos demais repositórios, que não se encontram disponíveis neste workspace. A infraestrutura foi montada de forma consistente e pronta para receber os contratos reais quando os serviços forem adicionados.

## 2. Resultado esperado

Ao final, deverá ser possível executar a plataforma de forma integrada:

```text
Cliente
   |
   v
FiapDonateUsers
   |
   | JWT
   v
FiapDonateReceiver
   |
   | DoacaoRecebidaEvent
   v
RabbitMQ
   |
   v
FiapDonateWorker
   |
   v
FiapDonateCampaign
```

A infraestrutura deverá fornecer:

- execução local;
- execução em Docker;
- execução em Kubernetes;
- configuração por ambiente;
- comunicação entre serviços por DNS interno do Kubernetes;
- RabbitMQ;
- ConfigMaps;
- Secrets;
- health checks;
- métricas;
- Prometheus;
- Grafana;
- CI/CD com GitHub Actions;
- build das aplicações;
- geração das imagens Docker;
- possibilidade de deploy automatizado no Kubernetes.

---

# 3. Regra fundamental para o Copilot

> **Antes de alterar qualquer arquivo, faça uma auditoria do repositório atual.**

Não apague ou substitua arquivos existentes sem verificar sua finalidade.

Não invente endpoints, portas, nomes de filas, exchanges, routing keys, nomes de containers ou contratos de eventos se eles já estiverem definidos em outros projetos.

Quando uma informação estiver ausente, procure primeiro nos demais repositórios da solução e nos arquivos de configuração disponíveis.

Caso não seja possível determinar um contrato, registre a pendência e escolha uma convenção consistente, documentando-a.

---

# 4. Repositórios relacionados

- `FiapDonateUsers`
- `FiapDonateCampaign`
- `FiapDonateReceiver`
- `FiapDonateWorker`
- `FiapDonateServices`

Repositório deste projeto:

`https://github.com/davidjmarinho/FiapDonateServices`

O `FiapDonateServices` deve ser tratado como o ponto central de infraestrutura, mas não como dono das regras de negócio.

---

# 5. Responsabilidades

## 5.1 Docker

Criar ou ajustar a infraestrutura Docker necessária para executar a solução localmente.

Deve ser possível subir os serviços utilizando:

```bash
docker compose up --build
```

O ambiente local deve contemplar, conforme necessário:

- Users;
- Campaign;
- Receiver;
- Worker;
- RabbitMQ;
- Prometheus;
- Grafana.

Se os serviços dependerem de banco de dados, os respectivos containers devem ser incluídos somente quando forem necessários para a execução real.

Não criar dependências fictícias apenas para preencher o Compose.

---

# 6. Kubernetes

Criar uma estrutura `k8s/` organizada por componente.

Exemplo:

```text
k8s/
├── namespace.yaml
├── users/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── campaign/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── receiver/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── worker/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── rabbitmq/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── prometheus/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── grafana/
    ├── deployment.yaml
    └── service.yaml
```

A estrutura pode ser adaptada ao conteúdo real dos projetos.

## 6.1 Deployments

Cada aplicação executável deve possuir um `Deployment` Kubernetes quando aplicável.

Os Deployments devem:

- utilizar imagens Docker;
- definir portas corretamente;
- utilizar ConfigMaps e Secrets;
- possuir probes quando suportadas;
- evitar configurações específicas de `localhost`;
- utilizar nomes DNS dos Services para comunicação interna.

## 6.2 Services

Criar Kubernetes `Service` para os componentes que precisam receber comunicação de outros componentes.

Os nomes devem ser consistentes e documentados.

Dentro do cluster, os serviços devem se comunicar utilizando DNS Kubernetes, por exemplo:

```text
http://fiapdonate-campaign
```

e não:

```text
http://localhost:5000
```

---

# 7. ConfigMaps

As configurações não sensíveis devem ficar em `ConfigMap`.

Exemplos conceituais:

```text
CampaignApi__BaseUrl
RabbitMQ__Host
RabbitMQ__Port
RabbitMQ__VirtualHost
```

Os nomes devem ser adaptados às configurações efetivamente utilizadas pelas aplicações.

Não criar variáveis que as aplicações não consomem.

---

# 8. Secrets

Informações sensíveis devem utilizar Kubernetes Secrets.

Exemplos:

```text
JWT signing key
RabbitMQ password
database password
database connection string contendo credenciais
```

Nunca colocar senhas, chaves JWT, tokens ou credenciais diretamente em Deployment ou ConfigMap.

Para desenvolvimento local, utilizar `.env` ou mecanismo equivalente e garantir que credenciais reais não sejam versionadas.

---

# 9. RabbitMQ

RabbitMQ é o mecanismo de mensageria da solução.

Fluxo:

```text
FiapDonateReceiver
        |
        | DoacaoRecebidaEvent
        v
     RabbitMQ
        |
        v
FiapDonateWorker
```

## Regra importante

O `FiapDonateReceiver` **não deve atualizar diretamente o total arrecadado da campanha**.

A atualização deve ocorrer por meio do processamento assíncrono realizado pelo Worker.

## Contrato

Antes de criar configurações RabbitMQ, auditar:

- `FiapDonateReceiver`
- `FiapDonateWorker`

Identificar:

- exchange;
- queue;
- routing key;
- tipo do evento;
- nome da mensagem;
- payload;
- propriedades de serialização;
- MassTransit, caso utilizado;
- host;
- virtual host;
- credenciais;
- política de retry;
- comportamento de mensagens inválidas.

O `FiapDonateServices` deve configurar a infraestrutura de acordo com o contrato real.

Não criar um segundo contrato paralelo.

---

# 10. Comunicação HTTP entre serviços

Quando um serviço precisar chamar outro, a URL deve ser configurável.

Exemplo:

```text
CampaignApi__BaseUrl=http://fiapdonate-campaign
```

Nunca assumir `localhost` ou `127.0.0.1` como endereço permanente dentro do Kubernetes.

A configuração deve funcionar em:

- Local;
- Docker Compose;
- Kubernetes;

sem alteração de código.

---

# 11. Observabilidade

A solução precisa possuir observabilidade real.

## 11.1 Health Check

Cada aplicação que possuir suporte a health check deve expor um endpoint, por exemplo:

```text
/health
```

O caminho exato deve respeitar o que já existe no projeto.

No Kubernetes, utilizar o endpoint para readiness/liveness quando tecnicamente apropriado.

## 11.2 Métricas

As aplicações devem expor métricas em endpoint compatível com Prometheus, quando o projeto já possuir suporte.

Exemplo:

```text
/metrics
```

Não criar métricas fictícias.

Priorizar métricas que demonstrem funcionamento real:

- requests;
- erros;
- duração;
- mensagens processadas;
- mensagens rejeitadas;
- doações processadas;
- falhas de processamento.

---

# 12. Prometheus

Criar configuração para descoberta/coleta das métricas das aplicações.

O Prometheus deve conseguir coletar métricas dos serviços executados no ambiente.

Documentar:

- endpoint;
- porta;
- job;
- intervalo de scrape;
- target.

No Kubernetes, preferir configuração baseada nos Services existentes.

---

# 13. Grafana

Configurar Grafana para visualização das métricas coletadas.

Criar pelo menos um dashboard demonstrável contendo métricas reais da aplicação.

O dashboard deve permitir demonstrar:

- disponibilidade dos serviços;
- requisições;
- erros;
- processamento das mensagens;
- atividade do fluxo de doação.

Não criar gráficos baseados em dados inventados.

---

# 14. CI/CD

Criar GitHub Actions em:

```text
.github/workflows/
```

O pipeline deve executar em push para `main`.

Fluxo mínimo:

```text
Push
  |
  v
Checkout
  |
  v
Setup .NET
  |
  v
Restore
  |
  v
Build
  |
  v
Testes, quando existentes
  |
  v
Build Docker
  |
  v
Publicação da imagem
```

Caso o ambiente e as credenciais estejam disponíveis, poderá ser incluído deploy no Kubernetes.

O deploy automático é desejável, mas não deve impedir o pipeline obrigatório de build e geração das imagens.

---

# 15. Imagens Docker

Cada serviço executável deverá possuir uma estratégia clara para geração da imagem.

Antes de criar Dockerfiles, verificar se os demais repositórios já possuem Dockerfiles.

Se já existirem, reutilizá-los e orquestrá-los, evitando duplicação.

O `FiapDonateServices` não deve duplicar o código-fonte das aplicações.

---

# 16. Variáveis de ambiente

Centralizar e documentar as principais configurações.

Exemplo conceitual:

```text
JWT_ISSUER
JWT_AUDIENCE
JWT_KEY

RABBITMQ_HOST
RABBITMQ_PORT
RABBITMQ_USER
RABBITMQ_PASSWORD
RABBITMQ_VHOST

CAMPAIGN_API_URL

DATABASE_CONNECTION_STRING
```

Os nomes devem ser ajustados às configurações reais.

---

# 17. Ambientes

## Local

```text
Developer Machine
    |
    v
Docker Compose
```

## Kubernetes

```text
Kubernetes Cluster
    |
    ├── Users
    ├── Campaign
    ├── Receiver
    ├── Worker
    ├── RabbitMQ
    ├── Prometheus
    └── Grafana
```

A mesma aplicação deve poder utilizar configurações diferentes por ambiente sem alteração do código-fonte.

---

# 18. Ordem de implementação

## Fase 1 — Auditoria

- [ ] Analisar o conteúdo atual do `FiapDonateServices`.
- [ ] Identificar arquivos existentes.
- [ ] Identificar Dockerfiles.
- [ ] Identificar Docker Compose.
- [ ] Identificar Kubernetes.
- [ ] Identificar GitHub Actions.
- [ ] Identificar configurações existentes.
- [ ] Identificar observabilidade.
- [ ] Identificar dependências externas.
- [ ] Analisar contratos dos outros quatro serviços disponíveis no workspace.

## Fase 2 — Integração

- [ ] Mapear portas.
- [ ] Mapear URLs internas.
- [ ] Mapear dependências.
- [ ] Mapear RabbitMQ.
- [ ] Mapear endpoints de health.
- [ ] Mapear endpoints de métricas.
- [ ] Mapear variáveis de ambiente.
- [ ] Mapear Secrets.
- [ ] Validar o contrato `DoacaoRecebidaEvent`.

## Fase 3 — Docker

- [ ] Ajustar `docker-compose.yml`.
- [ ] Configurar network.
- [ ] Configurar dependências.
- [ ] Configurar RabbitMQ.
- [ ] Configurar variáveis de ambiente.
- [ ] Garantir que nenhum serviço dependa de `localhost` para comunicação entre containers.
- [ ] Testar subida completa.

## Fase 4 — Kubernetes

- [ ] Criar namespace.
- [ ] Criar Deployments.
- [ ] Criar Services.
- [ ] Criar ConfigMaps.
- [ ] Criar Secrets sem credenciais reais versionadas.
- [ ] Configurar probes.
- [ ] Configurar comunicação interna.
- [ ] Configurar RabbitMQ.
- [ ] Configurar Prometheus.
- [ ] Configurar Grafana.
- [ ] Testar os manifests.

## Fase 5 — Observabilidade

- [ ] Validar `/health`.
- [ ] Validar `/metrics`.
- [ ] Configurar Prometheus.
- [ ] Configurar Grafana.
- [ ] Criar dashboard.
- [ ] Validar métricas reais.
- [ ] Demonstrar processamento de uma doação.

## Fase 6 — CI/CD

- [ ] Criar workflow de build.
- [ ] Restaurar dependências.
- [ ] Compilar projetos.
- [ ] Executar testes disponíveis.
- [ ] Construir imagens Docker.
- [ ] Publicar imagens quando registry estiver configurado.
- [ ] Validar execução do pipeline.

## Fase 7 — Teste integrado

Executar:

```text
1. Usuário realiza cadastro
2. Usuário realiza login
3. Users retorna JWT
4. Cliente envia JWT ao Receiver
5. Receiver valida autenticação
6. Receiver valida campanha
7. Receiver registra intenção
8. Receiver publica DoacaoRecebidaEvent
9. RabbitMQ recebe evento
10. Worker consome evento
11. Worker processa evento
12. Campaign atualiza a informação necessária
13. Consulta pública apresenta o total atualizado
14. Prometheus registra métricas
15. Grafana apresenta os dados
```

Se algum passo depender de implementação ainda inexistente em outro repositório, não criar implementação duplicada dentro do `FiapDonateServices`. Registrar a dependência como bloqueio.

---

# 19. Critérios de aceite

## Infraestrutura

- [ ] Docker Compose executa a solução.
- [ ] Kubernetes executa a solução.
- [ ] Deployments estão definidos.
- [ ] Services estão definidos.
- [ ] ConfigMaps estão definidos.
- [ ] Secrets estão definidos para informações sensíveis.
- [ ] Comunicação interna utiliza DNS dos Services.

## Mensageria

- [ ] RabbitMQ está disponível.
- [ ] Receiver consegue publicar o evento.
- [ ] Worker consegue consumir o evento.
- [ ] Contrato de evento é consistente entre produtor e consumidor.
- [ ] Receiver não atualiza diretamente o total da campanha.

## Observabilidade

- [ ] Health checks funcionam.
- [ ] Métricas funcionam.
- [ ] Prometheus coleta métricas.
- [ ] Grafana apresenta métricas reais.
- [ ] O fluxo de doação pode ser demonstrado no dashboard.

## CI/CD

- [ ] Workflow executa no push para `main`.
- [ ] Build .NET funciona.
- [ ] Testes existentes são executados.
- [ ] Imagens Docker são construídas.
- [ ] Publicação das imagens está configurada quando houver registry.

## Integração

- [ ] Users funciona com JWT.
- [ ] Receiver aceita autenticação.
- [ ] Campaign está acessível.
- [ ] Worker processa eventos.
- [ ] RabbitMQ conecta os componentes necessários.
- [ ] O fluxo ponta a ponta funciona.

---

# 20. Regras para implementação pelo GitHub Copilot

1. **Auditar antes de modificar.**
2. Não apagar código existente sem justificativa.
3. Não criar regras de negócio duplicadas.
4. Não implementar Users, Campaign, Receiver ou Worker dentro deste projeto.
5. Não inventar contratos de API quando puderem ser obtidos dos projetos reais.
6. Não inventar contratos RabbitMQ quando puderem ser obtidos do Receiver e Worker.
7. Não usar `localhost` para comunicação entre containers/pods.
8. Não versionar credenciais reais.
9. Não criar métricas falsas.
10. Não criar dashboards com dados fictícios.
11. Manter nomes de configuração consistentes.
12. Preferir mudanças pequenas e verificáveis.
13. Após cada alteração importante, executar validação/build.
14. Registrar bloqueios quando uma dependência externa impedir a conclusão.
15. Não alterar regras de negócio dos outros projetos.
16. Não adicionar tecnologias desnecessárias.
17. Priorizar os requisitos obrigatórios do Hackathon.
18. Manter a solução simples o suficiente para ser demonstrada durante o Hackathon.

---

# 21. Prompt operacional para o GitHub Copilot Agent

> Você é responsável pela implementação do projeto `FiapDonateServices`.
>
> Primeiro, faça uma auditoria completa do repositório atual e dos projetos relacionados disponíveis no workspace.
>
> Leia este arquivo `IMPLEMENTATION_PLAN.md` integralmente antes de alterar qualquer código.
>
> O objetivo é transformar `FiapDonateServices` no projeto de infraestrutura, integração, Kubernetes, observabilidade e CI/CD da plataforma FiapDonate.
>
> Não implemente regras de negócio que pertencem a Users, Campaign, Receiver ou Worker.
>
> Antes de criar qualquer configuração, descubra os contratos reais existentes nos projetos:
>
> - endpoints;
> - portas;
> - URLs;
> - variáveis de ambiente;
> - JWT;
> - RabbitMQ;
> - exchange;
> - queue;
> - routing key;
> - `DoacaoRecebidaEvent`;
> - health checks;
> - métricas;
> - Dockerfiles.
>
> Depois:
>
> 1. produza uma auditoria do estado atual;
> 2. liste problemas e bloqueios;
> 3. implemente as mudanças necessárias seguindo este documento;
> 4. valide cada etapa;
> 5. execute build e testes disponíveis;
> 6. valide Docker Compose;
> 7. valide os manifests Kubernetes;
> 8. valide Prometheus/Grafana;
> 9. valide o pipeline GitHub Actions;
> 10. faça o máximo possível do fluxo integrado;
> 11. não invente dependências;
> 12. não esconda erros ou bloqueios.
>
> Sempre que encontrar incompatibilidade entre serviços, registre:
>
> - serviço envolvido;
> - configuração atual;
> - configuração esperada;
> - impacto;
> - alteração necessária;
> - se a alteração deve ocorrer neste repositório ou no repositório responsável pelo serviço.
>
> Ao final, atualize este documento com checkboxes concluídos e crie, se necessário, `IMPLEMENTATION_STATUS.md` contendo:
>
> - o que foi implementado;
> - o que foi validado;
> - o que ficou pendente;
> - bloqueios;
> - comandos utilizados;
> - próximos passos.
>
> Priorize primeiro os requisitos obrigatórios do Hackathon e somente depois melhorias opcionais.

---

# 22. Definição final

O `FiapDonateServices` deve ser entendido como o projeto responsável por fazer todos os componentes funcionarem como **uma única aplicação distribuída**:

```text
                    FiapDonateServices
                           |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
   Kubernetes         Observability        CI/CD
        |                  |                  |
        v                  v                  v
 Deployments          Prometheus          GitHub Actions
 Services             Grafana             Docker Build
 ConfigMaps           Health              Registry
 Secrets              Metrics
        |
        v
   Integração
        |
   +----+----+---------+---------+
   |         |         |         |
 Users   Campaign   Receiver   Worker
                  |
                  v
               RabbitMQ
```

O foco do Integrante 5 é **fazer todos os componentes da plataforma funcionarem como uma única solução distribuída**, sem assumir as responsabilidades de negócio dos demais integrantes.
