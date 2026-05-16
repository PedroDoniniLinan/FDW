#!/bin/bash
docker compose down -v || exit 1
docker compose up -d || exit 1

until docker compose exec -T db pg_isready -U donini; do
    sleep 1
done

docker compose exec db psql -U donini -d prod -c "\dn"