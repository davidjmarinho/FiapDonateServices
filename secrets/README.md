# Secrets locais

Este diretório guarda arquivos de segredo do ambiente local e não deve ser versionado em repositórios públicos.

Crie os arquivos abaixo com valores locais reais para sua máquina:

- `rabbitmq_user.txt`
- `rabbitmq_password.txt`
- `grafana_admin_password.txt`

Exemplo:

```bash
printf 'guest' > secrets/rabbitmq_user.txt
printf 'change-me' > secrets/rabbitmq_password.txt
printf 'admin' > secrets/grafana_admin_password.txt
```

Eles são usados pelo Docker Compose via `secrets`, mantendo os valores fora do arquivo YAML versionado.
