# Status de Implementação

## O que foi implementado

- Estrutura base do projeto `.NET` com solução e API principal
- Endpoint `GET /health`, `GET /ready`, `GET /metrics` e `GET /api/status`
- Endpoints para registrar processamento de doações e mensagens rejeitadas
- Dockerfile para empacotamento da API
- `docker-compose.yml` com infraestrutura local para API, RabbitMQ, Prometheus e Grafana
- Configuração de Prometheus para coleta de métricas da API
- Configuração de Grafana apontando para Prometheus
- Estrutura inicial `k8s/` com namespace, serviços, secrets, configmaps e deployments
- Workflow GitHub Actions para build, testes e empacotamento Docker
- Documentação inicial do projeto em `README.md`

## O que foi validado

- `dotnet new sln` e `dotnet new webapi` criados com sucesso
- `dotnet restore` executado com sucesso
- `dotnet build` ainda precisa ser validado após ajustes finais da API
- Arquivos de infraestrutura e orquestração criados no repositório

## O que ficou pendente

- Ajuste definitivo de contratos de negócio com `FiapDonateUsers`, `FiapDonateCampaign`, `FiapDonateReceiver` e `FiapDonateWorker`
- Validação real do fluxo RabbitMQ com os serviços reais
- Ajustes finais dos `Deployment` do Kubernetes com os nomes exatos dos serviços de negócio, quando estiverem disponíveis
- Dashboard Grafana específico para fluxo de doação, dependendo das métricas reais dos serviços de negócio
- Deploy automático em cluster real, condicionado a credenciais e ambiente Kubernetes

## Bloqueios

- Não há outros repositórios da solução no workspace; portanto, os contratos reais de API e RabbitMQ não puderam ser inferidos do código-fonte
- O `FiapDonateServices` foi implementado como infraestrutura compatível e pronta para integração, mas não pode declarar contratos de negócio que não existem neste workspace

## Comandos executados

```bash
cd /Users/david/Documents/repo_fase_5/FiapDonateServices
ls -la

dotnet --version

dotnet new sln -n FiapDonateServices

dotnet new webapi -n FiapDonateServices.Api --use-program-main false --no-https -f net10.0

dotnet sln FiapDonateServices.sln add FiapDonateServices.Api/FiapDonateServices.Api.csproj
```

## Próximos passos

1. Reunir os demais repositórios da solução para alinhar contratos reais.
2. Ajustar `docker-compose.yml` e `k8s` com nomes e portas definitivos dos serviços.
3. Validar a API com build real e testes.
4. Integrar o Prometheus/Grafana com métricas reais dos serviços de negócio.
5. Adicionar dashboards e pipelines de deploy após o alinhamento de contratos.
