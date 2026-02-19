# 🚛 ETL Automation - Telemetry & Tracking Data

## 📋 Descripción del Proyecto
Este proyecto es un sistema **ETL (Extracción, Transformación y Carga)** automatizado desarrollado en Python. Su objetivo principal es extraer datos operativos, de rastreo y mantenimiento de vehículos desde múltiples fuentes (**Avansat, Satrack y CloudFleet**) y centralizarlos en una base de datos **MySQL** para su posterior análisis.

El sistema combina técnicas de **Web Scraping** (Selenium) para plataformas sin API pública y consumo de **APIs REST** para integración directa, manejando autenticación, paginación y límites de tasa (rate limiting).

## 🚀 Funcionalidades Principales
- **Avansat (Scraping):** 
  - Automatización de login y navegación con Selenium.
  - Descarga de reportes de Operación Nacional, Remesas, Vehículos y Conductores Terceros.
  - Transformación y limpieza de datos (Pandas) e inserción en MySQL.
- **Satrack (Scraping):**
  - Extracción de reportes de "Distancia, uso y velocidad" para flota propia.
  - Manejo de ventanas emergentes y selectores dinámicos.
- **CloudFleet (API):**
  - Consumo de endpoints para Vehículos, Órdenes de Trabajo, Combustible, Disponibilidad y Checklists.
  - Lógica robusta de **Rate Limiting** y paginación automática.
- **Base de Datos:**
  - Conexión resiliente a MySQL con verificación de conectividad (Ping/TCP checks).
  - Registro de auditoría de conexiones (IP/MAC).
- **Logging:** Sistema de logs dual (consola y archivo) para trazabilidad completa de errores y ejecución.

## 📂 Estructura del Proyecto

```text
02_Python_ETL/
│
├── 🚀 Ejecución Principal
│   ├── ETL_Main.py                 # Orquestador principal (Avansat + CloudFleet)
│   ├── SATRACK_ETL.py              # Script independiente para extracción Satrack
│
├── 🌐 Avansat (Módulos)
│   ├── avansat_login.py            # Automatización del login
│   ├── extraccion_Avansat.py       # Lógica de navegación y descarga de reportes
│   ├── transformacion_Avansat_*.py # Limpieza y estandarización de datos (Operación y Terceros)
│   ├── carga_Avansat_*.py          # Inserción de datos processados en MySQL
│
├── ☁️ CloudFleet (Módulos)
│   ├── cloudfleet_extraccion.py    # Consumo de API y almacenamiento JSON local
│   ├── cloudfleet_Transformation.py# Procesamiento de JSONs descargados
│   ├── cloudfleet_insercion.py     # Carga a BD
│   ├── api_utils.py                # Utilitarios API (Rate limit, Paginación, Auth)
│
├── 🛠 Utilidades y Configuración
│   ├── conexion_mysql.py           # Gestor de conexión a BD con health-checks
│   ├── logger_config.py            # Configuración de logs
│   ├── utils_rutas.py              # Manejo de rutas (compatible con PyInstaller)
│   ├── descargas_utils.py          # Espera activa de descargas
│
└── 📄 README.md                    # Documentación del proyecto
```

## ⚙️ Requisitos y Configuración

### Prerrequisitos
- Python 3.8+
- Servidor MySQL
- Google Chrome (u otro navegador compatible) y su respectivo WebDriver.

### Dependencias
Instalar las librerías necesarias ejecutando:
```bash
pip install pandas selenium mysql-connector-python python-dotenv requests webdriver-manager
```

### Configuración de Variables de Entorno (.env)
⚠️ **Nota Importante:** Este repositorio **no incluye** archivos con credenciales (`.env`). Para ejecutar el proyecto, debes crear los siguientes archivos `.env` en las rutas indicadas:

**1. Credenciales de Base de Datos**
Crear archivo en: `python/.env`

```ini
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=tu_usuario
MYSQL_PASS=tu_contraseña
MYSQL_DB=nombre_base_datos
```

**2. Credenciales de CloudFleet (API)**
Crear archivo en: `cloudfleet/.env`

```ini
API_KEY=tu_api_key_cloudfleet
```

**3. Credenciales de Avansat/Satrack**
*(Si los scripts las requieren en variables de entorno, agregarlas aquí. De lo contrario, verificar si el input es manual o está en otro archivo de configuración no incluido)*.

## ▶️ Uso

### Ejecutar el proceso completo (Avansat + CloudFleet)
```bash
python ETL_Main.py
```
Este script ejecutará secuencialmente:
1.  Descarga y procesamiento de Avansat.
2.  Descarga API y procesamiento de CloudFleet.
3.  Carga de ambos en la base de datos.
4.  Generación de logs en la carpeta `logs/`.

### Ejecutar solo Satrack
```bash
python SATRACK_ETL.py
```
Se abrirá el navegador automatizado para realizar la extracción de reportes de Satrack.

## 🛡 Consideraciones Técnicas
- **Manejo de Errores:** Si la conexión a la base de datos falla tras varios reintentos (Precheck TCP), el proceso se detiene ordenadamente para evitar inconsistencias.
- **Rutas:** El proyecto usa `utils_rutas.py` para garantizar que funcione tanto como script (`.py`) como empaquetado (`.exe` con PyInstaller).
- **Carpetas Temporales:** Se crean carpetas automáticas (`vehiculos_propios`, `informes_cloudfleet`, etc.) para gestionar las descargas temporales.

---
**Desarrollado por:** Juan Saavedra
