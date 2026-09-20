#Cluster de Base de Datos - Alta Disponibiliadd y Replicacion
# Progreso del Proyecto - Infraestructura Base y Proxy

En esta primera etapa se preparó la base del clúster, la seguridad de las contraseñas y el punto de acceso centralizado:

# 1. estructura y Control de Versiones

* Se creo el repositorio Git con la estructura de carpetas requerida por el trabajo practico (node1/, node2/, node3/, config/, scripts/, etc.).
* Se organizo el flujo de trabajo con ramas separadas para no pisar el código entre integrantes.

# 2. seguridad y Variables de Entorno

* Se configuró el archivo .gitignore para evitar que las contraseñas reales y los datos de la base de datos se suban al repositorio.
* Se crearon los archivos .env.example (plantilla publica) y .env (privado local) definiendo los 4 usuarios pedidos por la consigna: administrador, replicación, aplicación y monitorización.

# 3. nodo primario de base de datos (node1)

* Se configuro el primer contenedor con PostgreSQL 17 en el archivo docker-compose.yml.
* Se le asigno un volumen para almacenamiento persistente (node1_data) para no perder datos al apagar el contenedor.
* Seguridad de red: El nodo se conectó a una red interna (cluster-net) sin exponer su puerto 5432 al exterior, evitando accesos directos no autorizados.

# 4. Proxy y Balanceador de carga (HAProxy)

* Se implemento HAProxy como puerta de entrada unica para los clientes, segun lo visto en la teoría de balanceo de carga.
* Se configuró el archivo config/haproxy.cfg dividiendo el tráfico:

  * Puerto 5000: Canal exclusivo para operaciones de escritura (hacia el nodo primario).
  * Puerto 5001: Canal para operaciones de lectura (preparado para balancear entre las futuras réplicas).
  * Puerto 8404: Panel web visual para monitorear en tiempo real el estado de los nodos.
* Se validó que tanto la base de datos como el proxy están funcionando y comunicándose correctamente en la red interna.

# 5. configuración del motor y Preparación para Replicación

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

<!-- --------------- -->
# progreso del proyecto - replicación física y automatización dinámica

en esta etapa se integro el trabajo de base de datos, se resolvió la clonación de los nodos secundarios y se automatizó la inicialización para garantizar la reproducibilidad del entorno:

# 1. detección y diagnóstico de autenticación

* al integrar los nodos secundarios (node2 y node3), los contenedores entraron en bucle de reinicio debido a un fallo de autenticación en pg_basebackup.
* *causa:* el script inicial init.sql contenía contraseñas fijas de ejemplo, las cuales no coincidían con las credenciales seguras definidas en el archivo privado .env.

# 2. solución: inicializacion dinamica mediante script bash (init.sh)

* se reemplazó el archivo estatico init.sql por un script de consola *scripts/init.sh*.
* al ejecutarse bajo bash dentro del contenedor, el script inyecta dinamicamente las variables de entorno ($replica_password, $app_password, etc.) en postgresql, vinculando la base de datos directamente con el archivo .env local.
* *seguridad y permisos:* se eliminaron las contraseñas en texto plano del código fuente y se le asignó el rol pg_monitor al usuario de monitorización para aplicar el principio de mínimos privilegios.
* se configuró el formato de saltos de línea en *lf* para asegurar compatibilidad nativa con linux dentro del contenedor.

# 3. configuración de red y acceso de replicación

* en el archivo config/pg_hba.conf se flexibilizó la regla de replicación (0.0.0.0/0 scram-sha-256) para garantizar la conectividad entre nodos sin importar la subred interna asignada por docker.

# 4. validación de streaming replication y reproducibilidad

* se levantó el cluster completamente desde cero (docker compose down -v y docker compose up -d).
* los 4 contenedores (db-node1, db-node2, db-node3 y haproxy-lib) iniciaron en estado operativo (up) de forma 100% autonoma y sin comandos manuales.
* mediante una consulta a pg_stat_replication en el nodo primario, se validaron dos conexiones activas de recepción de logs wal (walreceiver) en estado *streaming* y modo asíncrono, dejando la replicación física completamente funcional.
<!-- ----------- -->

## progreso del proyecto - stack de observabilidad y monitoreo (prometheus y grafana)

se implementó la arquitectura completa de observabilidad para supervisar el rendimiento y la salud del clúster de base de datos en tiempo real:

# 1. configuración del recolector (prometheus)

* se creó el archivo monitoring/prometheus.yml estableciendo un intervalo de recolección de 10 segundos para consultar el endpoint de métricas de postgresql.

# 2. integración de servicios en docker compose

* se agregaron tres nuevos contenedores conectados a la red interna cluster-net con almacenamiento persistente:

   *postgres-exporter:* agente que extrae métricas de db-node1 utilizando el usuario seguro usuario_monitorizacion. se mapeó al puerto de host 19187 para evitar conflictos de puertos reservados por el sistema operativo en windows.
   *prometheus:* base de datos de series temporales (puerto 9090) con volumen persistente prometheus_data.
   *grafana:* plataforma de visualización gráfica (puerto 3000) con volumen persistente grafana_data y credenciales iniciales configuradas.

# 3. validación de extracción de métricas

* se verificó la disponibilidad del exportador en /metrics.
* en la consola de prometheus (status > targets), se comprobó que el objetivo de recolección (postgres) se encuentra en estado *up* en verde brillante, garantizando la ingesta continua de telemetría por la red interna.

# 4. configuración y visualización en grafana

* se vinculó prometheus como fuente de datos (data source) a través de la url interna http://prometheus:9090.
* se importó la plantilla gráfica oficial recomendada por la cátedra (dashboard id: 9628).
* se validó la recepción en vivo de las métricas clave de postgresql 17: uso de cpu, memoria ram consumida, descriptores de archivo abiertos y conexiones activas.

<!-- -------- -->

# progreso del proyecto - ajustes del cluster, cliente sql y benchmarking con pgbench

en esta etapa se optimizaron las reglas del balanceador y del motor, se valido el acceso del cliente a traves del proxy y se ejecutaron las pruebas de estres obligatorias:

# 1. optimizacion del balanceador haproxy

* **tiempos de espera:** se incrementaron los valores de inactividad (timeout client y timeout server) a 30 minutos en config/haproxy.cfg, evitando cortes inesperados de conexion tcp durante sesiones interactivas y pruebas de carga prolongadas.
* **politicas de lectura/escritura:** se configuro la directiva backup en el nodo primario dentro del backend de lectura (puerto 5001). con esto se garantizo que las lecturas se distribuyan exclusivamente entre los nodos secundarios (node2 y node3), liberando al primario de carga y asegurando que cualquier intento de escritura por el puerto 5001 sea rechazado por tratarse de replicas en modo solo lectura (read-only transaction).

# 2. seguridad y validacion del cliente sql

* se otorgaron permisos explicitos sobre las secuencias automaticas (grant all privileges on all sequences) al rol usuario_app, solucionando el error de insercion autoincremental sin otorgar privilegios de superusuario.
* se valido el flujo de operaciones a traves de haproxy:

  * escritura exitosa por el puerto 5000 (derivada a db-node1).
  * lectura inmediata y consistente por el puerto 5001 (derivada a las replicas).

# 3. deteccion y resolucion del cuello de botella en postgresql

* durante las pruebas iniciales de carga con 100 clientes, el motor alcanzo su limite por defecto arrojando fatal: sorry, too many clients already.
* **solucion aplicada:** se ajusto el parametro max_connections = 300 en config/postgresql.conf, asignando la memoria necesaria para soportar alta concurrencia sumada a las conexiones fijas de replicacion y monitorizacion.

# 4. resultados de benchmarking y concurrencia (pgbench)

se inicializo el esquema de pruebas con un factor de escala de 10 (-s 10, 1.000.000 de registros) y se ejecutaron pruebas de estres de 10 segundos continuos variando la concurrencia a traves del puerto 5000 del balanceador:

* *10 clientes:* 2.616 tps | latencia promedio: 3.82 ms | fallos: 0%
* *25 clientes:* 3.733 tps | latencia promedio: 6.69 ms | fallos: 0%
* *50 clientes:* 4.251 tps | latencia promedio: 11.76 ms | fallos: 0%
* *100 clientes* (pico optimo):** 4.417 tps | latencia promedio: 22.64 ms | fallos: 0%
* *200 clientes* (saturacion/degradacion):** 4.198 tps | latencia promedio: 47.64 ms | fallos: 0%

**conclusion del estres:** el sistema demostro su punto de maxima eficiencia alrededor de los 100 clientes concurrentes. al duplicar la carga a 200 clientes, el rendimiento cayo levemente y la latencia se duplico debido a la contencion de recursos y cambios de contexto en cpu.

# 5. telemetria y portabilidad

* en grafana se verifico un indice de eficiencia de memoria sobresaliente con un **cache hit rate del 98.92%** y **cero interbloqueos** (deadlocks).
* se exporto la definicion del tablero a monitoring/dashboard-postgres.json para asegurar la reconstruccion inmediata del entorno de monitoreo.

