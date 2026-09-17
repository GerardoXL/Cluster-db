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
