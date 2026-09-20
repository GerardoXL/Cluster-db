#!/bin/bash
set -e

PRIMARY_HOST="node1"
PGDATA="/var/lib/postgresql/data"

# Si el datadir ya tiene una base inicializada (PG_VERSION existe),
# no tocamos nada y dejamos que postgres arranque normal.
if [ -s "$PGDATA/PG_VERSION" ]; then
    echo "Datadir ya inicializado como standby, arrancando normalmente..."
else
    echo "Datadir vacío. Esperando a que $PRIMARY_HOST esté disponible..."
    until pg_isready -h "$PRIMARY_HOST" -U "$REPLICA_USER"; do
        sleep 2
    done

    echo "Clonando datos desde $PRIMARY_HOST con pg_basebackup..."
    pg_basebackup -h "$PRIMARY_HOST" -D "$PGDATA" -U "$REPLICA_USER" -Fp -Xs -P -R

    chmod 0700 "$PGDATA"
fi

# Delegamos al entrypoint original de la imagen postgres,
# que detecta PG_VERSION y arranca sin volver a hacer initdb.
# --- para inicie también con 300 conexiones ---
exec docker-entrypoint.sh postgres -c max_connections=300