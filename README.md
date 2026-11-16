# Clinisys

Sistema de gestion clinica desarrollado como proyecto final de la carrera Tecnico Superior en Tecnologias de la Informacion y la Comunicacion (CTA Paraguay-Corea). Aplicacion web en JSP con base de datos PostgreSQL.

## Modulos

- Referenciales
- Proceso 1: Gestion medica
- Proceso 2: Gestion administrativa (orden de compra, recepcion de insumos, gestion de compra, prefacturacion y acumulacion de cargos, gestion de ventas, control de stock e inventario, cierre de facturacion)

## Estructura del repositorio

- fuente/ProyectoTURNOn2026: proyecto Maven (empaquetado WAR) con el codigo fuente.
- sql: respaldo de la base de datos sistema_nutricion (formato personalizado de PostgreSQL, se restaura con pg_restore) y script de actualizacion de la tabla de ventas.
- portable: scripts para armar y ejecutar la version portable en Windows. Los programas (JDK, Tomcat y PostgreSQL) no se incluyen en el repositorio por su tamano.
- docs/historial: notas de las correcciones y mejoras realizadas.

## Requisitos para ejecutar desde el codigo fuente

- Java 17
- Maven
- Apache Tomcat 10.1
- PostgreSQL 17

## Pasos

1. Crear la base de datos y restaurar el respaldo:

       createdb -U postgres sistema_nutricion
       pg_restore -U postgres -d sistema_nutricion --no-owner --no-privileges sql/sistema_nutricion.dump

2. Compilar el proyecto:

       cd fuente/ProyectoTURNOn2026
       mvn clean package -DskipTests

3. Copiar target/ProyectoTN2026-1.0-SNAPSHOT.war a la carpeta webapps de Tomcat con el nombre ProyectoTURNOn2026.war e iniciar Tomcat.

4. Abrir http://localhost:8084/ProyectoTURNOn2026/ (o el puerto que use Tomcat).

La aplicacion se conecta a localhost:5432, base sistema_nutricion, usuario postgres. Los datos de conexion estan escritos en los archivos JSP del proyecto.

## Version portable

Los scripts de la carpeta portable esperan que junto a ellos esten las carpetas runtime (JDK 17), postgres (PostgreSQL 17) y tomcat (Tomcat 10.1) y el archivo config/db_password.txt con la clave de PostgreSQL. Ver portable/LEEME.txt.
