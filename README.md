#Cluster de Base de Datos - Alta Disponibiliadd y Replicacion
# Progreso del Proyecto - Infraestructura Base y Proxy

En esta primera etapa se preparó la base del clúster, la seguridad de las contraseñas y el punto de acceso centralizado:

# 1. Estructura y Control de Versiones

* Se creo el repositorio Git con la estructura de carpetas requerida por el trabajo practico (node1/, node2/, node3/, config/, scripts/, etc.).
* Se organizo el flujo de trabajo con ramas separadas para no pisar el código entre integrantes.

# 2. Seguridad y Variables de Entorno

* Se configuró el archivo .gitignore para evitar que las contraseñas reales y los datos de la base de datos se suban al repositorio.
* Se crearon los archivos .env.example (plantilla publica) y .env (privado local) definiendo los 4 usuarios pedidos por la consigna: administrador, replicación, aplicación y monitorización.

# 3. Nodo Primario de Base de Datos (node1)

* Se configuro el primer contenedor con PostgreSQL 17 en el archivo docker-compose.yml.
* Se le asigno un volumen para almacenamiento persistente (node1_data) para no perder datos al apagar el contenedor.
* Seguridad de red: El nodo se conectó a una red interna (cluster-net) sin exponer su puerto 5432 al exterior, evitando accesos directos no autorizados.

# 4. Proxy y Balanceador de Carga (HAProxy)

* Se implemento HAProxy como puerta de entrada unica para los clientes, segun lo visto en la teoría de balanceo de carga.
* Se configuró el archivo config/haproxy.cfg dividiendo el tráfico:

  * Puerto 5000: Canal exclusivo para operaciones de escritura (hacia el nodo primario).
  * Puerto 5001: Canal para operaciones de lectura (preparado para balancear entre las futuras réplicas).
  * Puerto 8404: Panel web visual para monitorear en tiempo real el estado de los nodos.
* Se validó que tanto la base de datos como el proxy están funcionando y comunicándose correctamente en la red interna.

# 5. Configuración del Motor y Preparación para Replicación (Persona 2)

En esta etapa se configuró el núcleo de PostgreSQL en el Nodo Primario para habilitar la replicación y se poblaron los datos iniciales:

* Se crearon los archivos de configuración nativa (`config/postgresql.conf` y `config/pg_hba.conf`) definiendo los parámetros de *Streaming Replication* (wal_level, max_wal_senders) y estableciendo las reglas de acceso seguras para los nodos secundarios.
* Se diseñó el script de inicialización (`scripts/init.sql`) que crea automáticamente los roles definidos en el `.env`, aplica los permisos correspondientes y genera la tabla `clientes` con datos de prueba iniciales.
* Se modificó el `docker-compose.yml` para inyectar estos archivos mediante volúmenes al nodo primario.
* Se dejaron definidos y preparados los contenedores de los nodos secundarios (`node2` y `node3`) a la espera de la clonación de datos.
* Se forzó la zona horaria a UTC para evitar conflictos de compatibilidad con el sistema operativo host.

# 6. Puesta en Marcha de la Replicación y Resolución de Fallos de Red

En esta etapa se completó la clonación de los nodos secundarios y se resolvieron los problemas de conectividad que surgieron durante las pruebas iniciales:

* Se creó el script `scripts/setup-replica.sh`, que se ejecuta como entrypoint en node2 y node3: al detectar un datadir vacío, espera a que node1 esté disponible y ejecuta `pg_basebackup` con la opción `-R` para clonar los datos y generar automáticamente el `standby.signal` y el `primary_conninfo`.
* Se corrigió `config/pg_hba.conf` para autorizar las conexiones de replicación desde la subred real del clúster (`172.19.0.0/16`), reemplazando un rango incorrecto que rechazaba las conexiones de los nodos secundarios.
* Se identificó que `postgresql.conf` necesita declarar explícitamente `hba_file = '/etc/postgresql/pg_hba.conf'` para que node1 use el archivo de reglas personalizado en lugar del generado por defecto en el datadir.
* Se verificó el estado de la replicación consultando `pg_stat_replication` en node1, confirmando ambos nodos secundarios en estado `streaming`, y `pg_is_in_recovery()` en node2 y node3 confirmando su rol de standby.
* Se detectó que HAProxy resuelve el nombre `db-node1` a una IP una única vez al iniciar, por lo que un reinicio del nodo primario podía dejarlo apuntando a una IP obsoleta. Se corrigió agregando una sección `resolvers docker_dns` en `config/haproxy.cfg`, apuntando al DNS interno de Docker (`127.0.0.11:53`), para que HAProxy revalide la IP de los nodos automáticamente.