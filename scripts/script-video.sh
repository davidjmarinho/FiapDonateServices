#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
ROTEIRO DO VÍDEO - FIAPDONATE

1. Abrir a arquitetura
- Mostrar o diagrama da solução.
- Explicar rapidamente os papéis de Users, Campaign, Receiver, Worker, RabbitMQ, Kubernetes, Prometheus e Grafana.

2. Mostrar o pipeline de CI
- Abrir o workflow GitHub Actions.
- Demonstrar o build executando e a imagem Docker sendo gerada com sucesso.

3. Mostrar o cluster
- Executar kubectl get pods -n fiapdonate
- Explicar os pods que estão no ar e os serviços expostos.

4. Mostrar observabilidade
- Abrir o Grafana.
- Exibir dashboard com métrica real da aplicação.
- Se houver, mostrar também health/metrics.

5. Mostrar autenticação
- Fazer login via Swagger ou Postman.
- Exibir o token JWT retornado.

5.1 Testar com Postman
- Criar uma collection chamada FiapDonate.
- Configurar uma variável de ambiente baseUrl com a URL da API.
- Fazer a chamada de login primeiro e salvar o token JWT em uma variável jwt.
- Reutilizar o header Authorization: Bearer {{jwt}} nos endpoints protegidos.
- Ordem sugerida de teste:
  1. POST /api/users/login
  2. POST /api/campaign
  3. POST /api/doacoes
  4. GET /api/campaign/{id}
- O Receiver não é chamado diretamente no Postman; ele é interno ao fluxo via RabbitMQ.
- Use token de GestorONG para criar campanha e token de Doador para registrar doação.
- Exemplo de login:
  {
    "email": "gestor@fiapdonate.com",
    "senha": "Gestor@123"
  }
- Exemplo de campanha:
  {
    "titulo": "Campanha E2E",
    "descricao": "Campanha para validação de arquitetura",
    "dataInicio": "2026-09-30T02:33:10",
    "dataFim": "2026-10-30T02:33:10",
    "metaFinanceira": 1000
  }
- Exemplo de doação:
  {
    "idCampanha": "{{campaignId}}",
    "valorDoacao": 150
  }
- Após a doação, fazer GET na campanha e mostrar o campo valorArrecadado atualizado.

5.2 Executar deploy e teste no terminal
- Abrir o terminal na pasta do projeto.
- Executar o deploy local com o ambiente Kubernetes:
  ./scripts/deploy-local.sh k8s
- Em seguida, executar o teste E2E com os port-forwards configurados:
  USERS_API=http://localhost:28417 CAMPAIGN_API=http://localhost:25064 RECEIVER_API=http://localhost:21562 PROMETHEUS_URL=http://localhost:28105 GRAFANA_URL=http://localhost:27888 RABBITMQ_API=http://localhost:23390 ./scripts/hackathon5-teste.sh
- Mostrar a saída final com o resultado do E2E.

6. Criar campanha
- Executar o endpoint de criação de campanha.
- Mostrar a resposta com o identificador da campanha.

7. Simular doação
- Enviar o payload da doação para o Receiver.
- Mostrar que a API não atualiza a campanha diretamente.

8. Mostrar RabbitMQ
- Abrir a interface do RabbitMQ.
- Exibir a mensagem na fila ou o evento trafegando pelo broker.

9. Mostrar Worker processando
- Abrir logs do Worker.
- Mostrar o consumo da mensagem e o processamento da atualização.

10. Confirmar atualização da campanha
- Consultar a campanha pela API pública.
- Mostrar que o valor arrecadado foi atualizado pelo Worker.

11. Encerramento
- Reforçar a arquitetura:
  API -> RabbitMQ -> Worker -> Banco
  com Kubernetes, observabilidade e CI/CD.

EOF