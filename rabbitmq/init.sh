#!/bin/sh
set -eu

rabbitmq_user="$(cat /run/secrets/rabbitmq_user)"
rabbitmq_password="$(cat /run/secrets/rabbitmq_password)"
rabbitmq_api="http://rabbitmq:15672/api"

curl --fail --silent --show-error \
  --user "${rabbitmq_user}:${rabbitmq_password}" \
  --header "content-type: application/json" \
  --request PUT \
  --data '{"type":"fanout","durable":true,"auto_delete":false,"internal":false,"arguments":{}}' \
  "${rabbitmq_api}/exchanges/%2F/FiapDonateWorker.Api.Events%3ADoacaoRecebidaEvent"

curl --fail --silent --show-error \
  --user "${rabbitmq_user}:${rabbitmq_password}" \
  --header "content-type: application/json" \
  --request PUT \
  --data '{"durable":true,"auto_delete":false,"arguments":{}}' \
  "${rabbitmq_api}/queues/%2F/doacao-recebida-queue"

curl --fail --silent --show-error \
  --user "${rabbitmq_user}:${rabbitmq_password}" \
  --header "content-type: application/json" \
  --request POST \
  --data '{"routing_key":"","arguments":{}}' \
  "${rabbitmq_api}/bindings/%2F/e/FiapDonateWorker.Api.Events%3ADoacaoRecebidaEvent/q/doacao-recebida-queue"
