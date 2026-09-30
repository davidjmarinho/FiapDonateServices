# Consolidado de pendências para entrega: FiapDonateUsers + FiapDonateReceiver

## 1. Objetivo

Este documento unifica os dois relatórios existentes para criar uma visão única do que ainda falta para a entrega do projeto Conexão Solidária nos dois repositórios citados:

- FiapDonateUsers
- FiapDonateReceiver

Documentos de origem considerados:

- `docs/o-que-falta-para-a-entrega.md` (foco macro em Receiver/Worker e ecossistema)
- `docs/analise-fiapdonateusers-entrega-atualizada.md` (foco técnico no Users)

---

## 2. Situação consolidada por repositório

## 2.1 FiapDonateUsers (estado atual)

Já implementado:

- cadastro de usuário (`POST /api/users/register`);
- Identity com persistência em SQL Server;
- validação com FluentValidation;
- roles semeadas (`GestorONG`, `Doador`);
- hash de senha via ASP.NET Identity (seguro por padrão da plataforma).

Ainda falta para entrega integrada:

- login (`POST /api/users/login`);
- emissão de JWT (issuer, audience, expiração, assinatura);
- configuração de autenticação e autorização bearer;
- endpoints protegidos por role;
- inclusão e validação de CPF;
- testes de autenticação/autorização;
- atualização do arquivo HTTP de testes para endpoints reais.

## 2.2 FiapDonateReceiver (estado consolidado a partir do relatório macro)

Já implementado no relatório original:

- consumo de evento de doação via RabbitMQ;
- processamento assíncrono com idempotência;
- atualização de valor arrecadado no fluxo do worker;
- endpoints de health e métricas no worker;
- base inicial de infraestrutura local e Kubernetes.

Ainda falta para entrega integrada:

- API produtora da intenção de doação (entrada autenticada);
- validações de campanha ativa e valor de doação antes de publicar evento;
- validação final de contrato de evento com o produtor:
  - nome de exchange/queue;
  - routing key;
  - payload JSON e tipo de evento;
  - compatibilidade de serialização MassTransit;
- validação de integração com repositório Campaign;
- fechamento do fluxo ponta a ponta com o serviço de Users autenticando o doador.

---

## 3. Reconciliação de divergências entre os dois documentos

1. Hash de senha no Users:
- No relatório macro, aparecia como pendente (ex.: BCrypt).
- Na análise técnica do Users, já existe hash seguro via ASP.NET Identity.
- Consolidação: requisito de segurança de hash está tecnicamente atendido, mesmo sem BCrypt explícito.

2. Escopo de infraestrutura:
- O relatório macro descreve lacunas de múltiplos serviços e observabilidade completa.
- O relatório do Users cobre apenas o escopo do repositório de identidade.
- Consolidação: o gap de infraestrutura permanece válido, mas depende do repositório de services/orquestração e da integração entre microsserviços.

---

## 4. Pendências unificadas por prioridade

### P0 (bloqueadores)

1. Implementar login + JWT no FiapDonateUsers.
2. Implementar autorização por role no FiapDonateUsers.
3. Implementar CPF no fluxo de cadastro do FiapDonateUsers.
4. Disponibilizar API produtora de doação autenticada no lado Receiver/entrada.
5. Fechar contrato de evento entre produtor e consumidor (queue/exchange/routing key/payload/tipo).
6. Garantir Campaign disponível e integrada para regras de campanha ativa e atualização de valores.

### P1 (obrigatórios para demonstração confiável)

1. Rodar fluxo completo: login -> campanha -> doação -> publicação -> consumo -> atualização pública.
2. Adicionar testes de integração para login, autorização e publicação/consumo de evento.
3. Ajustar arquivo de testes HTTP do Users para cenários reais.
4. Padronizar contrato de autenticação para os demais serviços (claims e validações).

### P2 (integração e operação)

1. Compose/Kubernetes com todos os serviços e configuração de rede interna.
2. ConfigMaps/Secrets consistentes para todos os ambientes.
3. Eliminar dependência de localhost em comunicação entre serviços containerizados/pods.
4. Endpoints de health/readiness e métricas por serviço.

### P3 (demonstração e observabilidade)

1. Dashboard mínimo de Grafana com métricas de autenticação e processamento de doação.
2. Configuração Prometheus scrape para todos os serviços.
3. Evidência de fluxo feliz e evidência de rejeição (auth inválida, campanha inativa, payload inválido).

---

## 5. Checklist único de entrega (Users + Receiver)

### FiapDonateUsers

- [x] Cadastro de usuários
- [x] Roles iniciais (`GestorONG`, `Doador`)
- [x] Hash de senha com Identity
- [ ] Login
- [ ] JWT
- [ ] Endpoints protegidos por role
- [ ] CPF com validação e unicidade
- [ ] Testes de auth/authorization
- [ ] Arquivo HTTP atualizado

### FiapDonateReceiver

- [x] Consumo de evento e processamento assíncrono base
- [x] Health e métricas no worker
- [ ] API de intenção de doação autenticada (produtor)
- [ ] Validação pré-publicação da doação
- [ ] Contrato RabbitMQ fechado com o produtor
- [ ] Integração confirmada com Campaign
- [ ] Testes E2E de publicação e consumo

### Integração entre ambos

- [ ] JWT emitido pelo Users aceito pelos serviços de entrada de doação
- [ ] Jornada ponta a ponta validada em ambiente integrado
- [ ] Observabilidade mínima funcional (Prometheus + dashboard básico)

---

## 6. Ordem prática recomendada

1. Fechar FiapDonateUsers em P0 (login, JWT, authorize, CPF).
2. Fechar API produtora e contrato de evento no lado Receiver/entrada.
3. Rodar teste de integração entre Users + Receiver com campanha ativa.
4. Consolidar infraestrutura integrada e observabilidade mínima.
5. Preparar demonstração com evidências de sucesso e de rejeição controlada.

---

## 7. Conclusão

A unificação dos dois documentos mostra que:

- o FiapDonateUsers já possui base sólida de identidade, mas ainda falta autenticação completa para integração (login/JWT/authorize/CPF);
- o FiapDonateReceiver já possui base sólida de processamento no consumidor, mas ainda depende do produtor de doação autenticado e do fechamento formal do contrato de mensageria;
- a entrega final só fecha com integração real entre Users, Receiver, Campaign e infraestrutura compartilhada.
