#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

 ---- Crear roles utilizando las variables de entorono del .env------
CREATE ROLE $REPLICA_USER WITH REPLICATION PASSWORD '$REPLICA_PASSWORD' LOGIN;
CREATE ROLE $APP_USER WITH LOGIN PASSWORD '$APP_PASSWORD';
CREATE ROLE $MONITOR_USER WITH LOGIN PASSWORD '$MONITOR_PASSWORD';

 ---- permiso oficial para que el usuario de monitorizacion pueda leer metricas ----

GRANT pg_monitor TO $MONITOR_USER;

 ---- tabla de prueba para el cluster ----
CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    saldo DECIMAL(10,2)
);

 ---- permisos para la aplicacion -----

GRANT ALL PRIVILEGES ON TABLE clientes TO $APP_USER;

 ---- datos de prueba ----

INSERT INTO clientes (nombre,saldo) VALUES ('Cliente 1',1500.00),('Cliente 2',300.50);
EOSQL
