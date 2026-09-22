# Secrets locais

Este diretório guarda arquivos de segredo do ambiente local e não deve ser versionado em repositórios públicos.

Crie os arquivos abaixo com valores locais reais para sua máquina:

- `rabbitmq_user.txt`
- `rabbitmq_password.txt`
- `sqlserver_sa_password.txt`
- `postgres_password.txt`
- `grafana_admin_password.txt`

Exemplo:

```bash
printf 'fiapdonate' > secrets/rabbitmq_user.txt
openssl rand -base64 32 > secrets/rabbitmq_password.txt
openssl rand -base64 32 > secrets/sqlserver_sa_password.txt
openssl rand -base64 32 > secrets/postgres_password.txt
openssl rand -base64 32 > secrets/grafana_admin_password.txt
```

Eles são usados pelo Docker Compose via `secrets`, mantendo os valores fora do arquivo YAML versionado.
