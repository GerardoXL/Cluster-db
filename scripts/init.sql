-- Creamos el usuario de replicación
CREATE ROLE usuario_replicacion WITH REPLICATION PASSWORD 'replica123' LOGIN;

-- Creamos el usuario para la app y el monitor
CREATE ROLE usuario_app WITH LOGIN PASSWORD 'usuario123';
CREATE ROLE usuario_monitorizacion WITH LOGIN PASSWORD 'monitor123';

-- Tu tabla de prueba para el TP
CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    saldo DECIMAL(10,2)
);

-- Le damos permisos al usuario de la app sobre la tabla
GRANT ALL PRIVILEGES ON TABLE clientes TO usuario_app;

-- Datos de prueba
INSERT INTO clientes (nombre, saldo) VALUES ('Cliente 1', 1500.00), ('Cliente 2', 300.50);