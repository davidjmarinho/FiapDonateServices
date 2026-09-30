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
- Executar kubectl get pods.
- Explicar os pods que estão no ar e os serviços expostos.

4. Mostrar observabilidade
- Abrir o Grafana.
- Exibir dashboard com métrica real da aplicação.
- Se houver, mostrar também health/metrics.

5. Mostrar autenticação
- Fazer login via Swagger ou Postman.
- Exibir o token JWT retornado.

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