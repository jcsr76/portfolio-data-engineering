# 🗄️ SQL Scripts - P&P Database

## 📋 Descripción General
Este directorio contiene los scripts SQL necesarios para definir, desplegar y mantener la base de datos `pypdb`. Esta base de datos es el núcleo central para la gestión de operaciones, recursos humanos y control de flota de una empresa de transporte, y sirve como destino final para los procesos ETL automatizados.

## 🏗️ Estructura de la Base de Datos (`BD.sql`)
El esquema `pypdb` está modularizado para soportar distintas áreas del negocio:

### 1. 🌍 Módulo Geográfico
Tablas para normalización de ubicaciones:
- `paises`, `departamentos_col`, `ciudades` (incluye latitud/longitud).

### 2. 👥 Módulo Talento Humano
Gestión integral de colaboradores:
- `colaboradores`: Información personal y contrato.
- `contratos`: Detalles de vinculación, salario y vigencia.
- `dotacion` e `inventario_dotacion`: Control de entregas de uniformes/EPP.
- `seguridad_social`, `beneficiarios`, `incapacidades`.

### 3. 🚛 Módulo de Flota (Vehículos)
Gestión híbrida de flota:
- **Flota Propia (`vehiculos_propios`):** Control detallado de activos, mantenimiento y kilometraje.
- **Terceros (`vehiculos_terceros`):** Vehículos externos vinculados a la operación.
- **Tipologías:** Clasificación por `grupos_vehiculo`, `categorias` y `tipologias`.

### 4. 📦 Módulo de Operaciones
Núcleo del negocio logístico:
- `operaciones`: Registro principal de servicios, tonelaje, rutas y tiempos.
- `envios`, `rutas`, `clientes`.
- `ordenes_trabajo_vehiculo`: Trazabilidad de OTs.
- `operaciones_avansat`: Tablas espejo para la integración con datos de Avansat.

### 5. 🛠️ Módulo Administrativo y Auditoría
- `auditoria` y `auditoria_backup`: Trazabilidad de cambios en datos sensibles.
- `log_conexiones`: Registro de accesos (IP, Usuario, MAC).
- `usuarios`: Gestión de credenciales de aplicación.

## 📜 Scripts Clave

### `BD.sql`
Script DDL principal. Ejecutar este archivo crea toda la estructura de tablas y restricciones (Foreign Keys). Es idempotente (`IF NOT EXISTS`), lo que permite correrlo de manera segura para actualizar esquemas sin borrar datos existentes.

### `Procedimientos almacenados con transacciones.sql`
Contiene la lógica de negocio encapsulada en la base de datos.
- **Transaccionalidad:** Uso de `START TRANSACTION`, `COMMIT` y `ROLLBACK` para garantizar integridad.
- **ETL:** Procedimientos como `insertar_en_staging_operaciones` y `sp_sincronizar_operaciones_avansat` son vitales para la carga masiva desde Python.
- **Auditoría:** `MoverAuditoriaBackup` gestiona el particionamiento de logs antiguos.

### `Python_ETL.sql`
Configuración de seguridad para la integración con Python.
- Crea el usuario `python_user`.
- Asigna permisos mínimos (Principio de Menor Privilegio):
    - `EXECUTE` solo en procedimientos de carga específicos.
    - `SELECT` solo en logs de errores necesarios para depuración.
    - Bloqueo de acceso directo (`DELETE`/`DROP`) a tablas críticas.

### `Vistas.sql`
Capa de abstracción para reportes y Power BI. Simplifica consultas complejas uniendo múltiples tablas normalizadas (ej: uniendo `colaboradores` con `departamentos`, `cargos` y `ciudades`).

## ⚙️ Despliegue e Instalación

1. **Crear Base de Datos:**
   Ejecutar `BD.sql` en su servidor MySQL (versión 8.0+ recomendada).

2. **Cargar Lógica de Negocio:**
   Ejecutar `Procedimientos almacenados con transacciones.sql` y `Funciones.sql`.

3. **Configurar Seguridad:**
   Ejecutar `Python_ETL.sql` para crear el usuario que utilizará el script de automatización. Asegúrese de cambiar la contraseña `'123456'` por una segura antes de producción.

4. **Vistas:**
   Ejecutar `Vistas.sql` para habilitar las capas de reporte.

---
**Base de datos diseñada por:** Juan Saavedra
