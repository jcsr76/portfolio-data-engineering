# 🚚 Sistema de Gestión de Operaciones Logísticas (Access VBA)

## 📋 Descripción General
Esta aplicación es el módulo central para la gestión operativa en P&P. Desarrollada en **Microsoft Access con VBA**, permite a los despachadores y coordinadores registrar, monitorear y auditar toda la operación de transporte y logística en tiempo real.

Se conecta a la misma base de datos MySQL (`pypdb`) que el módulo de Talento Humano y el sistema ETL, garantizando integridad y unicidad en la información.

## 🏗️ Arquitectura y Flujo de Datos
- **Entrada de Datos:** Formularios Access para captura manual en sitio.
- **Validación:** Lógica de negocio en VBA (Validación de horas, kilometrajes, conductores activos).
- **Almacenamiento:** Base de datos MySQL remota.

## 📂 Componentes del Sistema

### 1. 🖥️ Formularios Operativos (`Form_*.cls`)
Estos formularios gestionan el "Ciclo de Vida del Despacho":

- **Apertura de Operación:**
  - `Form_Apertura_Operacion.cls`: Registro inicial del viaje. Vincula Conductor, Vehículo (Propio o Tercero), Ruta y Cliente.
  - `Form_Actualizar_Apertura_Operacion.cls`: Corrección de datos iniciales.

- **Gestión y Seguimiento:**
  - `Form_Back_Office.cls`: Módulo administrativo para gestión de novedades operativa.
  - `Form_Auxiliar_Tercero.cls`: Gestión rápida de datos para vehículos tercerizados.

- **Cierre y Auditoría:**
  - `Form_Cierre_Operacion.cls`: Registro de finalización de ruta, kilometraje final, devoluciones y novedades de entrega.
  - `Form_Conciliacion_Operacion.cls`: Herramienta para cruzar datos operativos vs lo planificado/facturado.

### 2. ⚙️ Módulos de Soporte (`*.bas`)
Comparten la misma base lógica que otros módulos del ERP P&P para mantener consistencia:

- **`modEntornoServerMySQL.bas`**: Gestión centralizada de la cadena de conexión ODBC a MySQL.
- **`Globales.bas`**: Variables de sesión (Usuario actual, permisos de dispatcher).
- **`modFuncionesHoras.bas`**: Vital para calcular tiempos de operación, horas extras y cumplimiento de itinerarios.
- **`modUtils.bas`**: Validaciones genéricas (RUT/NIT, Placas, Emails).

## 🚀 Flujo de Trabajo Típico
1. **Apertura:** El usuario registra la salida del vehículo en `Apertura_Operacion`. El sistema valida que el conductor y vehículo estén habilitados.
2. **Monitoreo:** Novedades durante el viaje se gestionan en `Back_Office`.
3. **Cierre:** Al finalizar, se ingresan los datos de cierre (Km, hora). El sistema calcula automáticamente rendimientos.
4. **Conciliación:** Auditoría posterior para validar la consistencia de los datos antes de nómina/facturación.

## ⚙️ Requisitos Técnicos
- Access 2016+
- Conexión ODBC a MySQL configurada (DSN de Sistema).
- Permisos de red al puerto 3306 del servidor de BD.

---
**Desarrollado por:** Juan Saavedra
