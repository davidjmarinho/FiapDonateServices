# Integração do Worker e Receiver

## Contrato provisionado no RabbitMQ

A infraestrutura cria no vhost `/`:

- exchange fanout `FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`;
- fila durável `doacao-recebida-queue`;
- binding do exchange para a fila.

Esse é o contrato MassTransit informado pelo `FiapDonateWorker`. O produtor deve publicar o envelope MassTransit com `content_type: application/vnd.masstransit+json` e o `messageType` `urn:message:FiapDonateWorker.Api.Events:DoacaoRecebidaEvent`.

## Serviços externos

Os repositórios dos serviços não estão neste workspace. Por isso, os deployments Kubernetes usam as imagens esperadas `fiapdonateworker:local` e `fiapdonatereceiver-worker:local`; as imagens devem existir no registry usado pelo cluster antes do deploy.

## Configuração e secrets

- Worker: `RabbitMq__Host`, `RabbitMq__VirtualHost` e `RabbitMq__Username` vêm do ConfigMap. `RabbitMq__Password` e `ConnectionStrings__WorkerDb` vêm de `fiapdonate-worker-secrets`.
- Receiver: `RabbitMq__Host`, `RabbitMq__VirtualHost` e `RabbitMq__Username` vêm do ConfigMap. `RabbitMq__Password` e `ConnectionStrings__ReceiverDb` vêm de `fiapdonate-receiver-secrets`.

O Compose inclui SQL Server para o Worker e PostgreSQL para o Receiver. Nenhuma senha é salva nos arquivos versionados.

## Pendência de domínio

Os dois documentos fornecidos descrevem a tabela `Campanhas` em bancos diferentes: SQL Server para o Worker e PostgreSQL para o Receiver. Um mesmo banco lógico não pode ser compartilhado entre esses motores. Antes do fluxo completo, a equipe precisa definir o banco proprietário de `Campanhas` e alinhar as duas connection strings com essa decisão.
