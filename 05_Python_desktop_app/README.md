# Orquestador AVANSAT

## Descripción
**Orquestador AVANSAT** es una aplicación de escritorio diseñada para automatizar procesos masivos en la plataforma AVANSAT. Actúa como un asistente robótico que lee información desde un archivo Excel y ejecuta tareas repetitivas en el navegador web de forma automática, validando cada paso y reportando el progreso en tiempo real.

La herramienta centraliza cuatro procesos clave de facturación y liquidación, permitiendo a los usuarios procesar cientos de registros con mínima intervención manual.

## Características Principales
El orquestador automatiza los siguientes módulos en flujo continuo:

1.  **Liquidaciones de Manifiestos**: Cierra y factura manifiestos de carga automáticamente.
2.  **Servicios Especiales**: Procesa la liquidación de servicios especiales asociados.
3.  **Prefacturas**: Genera comprobantes de facturación masiva.
4.  **Actualización de Facturas**: Adiciona remesas a facturas existentes.

**Funcionalidades Adicionales:**
*   **Interfaz Gráfica Moderna (GUI)**: Construida con `customtkinter` para una experiencia de usuario limpia y oscura.
*   **Validación de Datos**: Verifica la integridad del Excel antes de iniciar.
*   **Manejo de Errores**: Captura screenshots y HTML del navegador en caso de fallas para facilitar la depuración.
*   **Log Detallado**: Registro completo de cada acción en archivos `.log` y consola en tiempo real.
*   **Modo Headless/Visible**: Opción para ver el navegador mientras trabaja o ejecutarlo en segundo plano.

## Estructura del Proyecto
*   `orquestador.py`: Controlador principal que coordina la ejecución secuencial de los módulos.
*   `gui_app.py`: Punto de entrada de la aplicación. Contiene la interfaz gráfica.
*   `avansat_login.py`: Módulo encargado de la autenticación segura en AVANSAT.
*   **Módulos de Automatización**:
    *   `liquidaciones_manifiestos_avansat.py`
    *   `liquidaciones_servicios_especiales.py`
    *   `prefacturas_avansat.py`
    *   `actualizar_factura.py`
*   `excel_io.py`: Utilidades para lectura y conteo de registros en Excel.
*   `logger_config.py`: Configuración centralizada de logs.
*   `assets/`: Contiene imágenes y recursos estáticos (iconos, logos).

## Requisitos Previos
*   **Sistema Operativo**: Windows 10/11.
*   **Google Chrome**: Debe estar instalado (la automatización se basa en Selenium WebDriver).
*   **Python 3.10+** (Para ejecución desde código fuente).

## Instalación y Configuración (Código Fuente)

1.  **Clonar o descargar el repositorio** en tu máquina local.
2.  **Crear un entorno virtual** (recomendado):
    ```bash
    python -m venv venv
    .\venv\Scripts\activate
    ```
3.  **Instalar dependencias**:
    ```bash
    pip install pandas openpyxl selenium customtkinter pyinstaller webdriver-manager
    ```
    *(Nota: Asegúrate de tener `webdriver-manager` o gestionar el driver de Chrome manualmente).*

## Uso de la Aplicación

1.  **Ejecutar la aplicación**:
    ```bash
    python gui_app.py
    ```
2.  **Interfaz**:
    *   **Cargar Excel**: Selecciona el archivo `.xlsx` con las pestañas requeridas (`Liquidacion`, `Servicios`, `prefacturas`, `actualizar_facturas`).
    *   **Verificar contadores**: La app mostrará cuántos registros detectó para cada módulo.
    *   **Credenciales**: Al dar clic en "INICIAR PROCESO", se solicitarán usuario y contraseña de AVANSAT.
    *   **Opciones**: Puedes marcar "Ver navegador" para supervisar visualmente la automatización.

## Generación de Ejecutable (.exe)
El proyecto incluye un archivo de especificación para **PyInstaller** (`OrquestadorAVANSAT.spec`). Para compilar la versión distribuible:

1.  Abre una terminal en la carpeta del proyecto.
2.  Ejecuta:
    ```bash
    pyinstaller OrquestadorAVANSAT.spec
    ```
3.  El ejecutable se generará en la carpeta `dist/OrquestadorAVANSAT/OrquestadorAVANSAT.exe` (si es carpeta) o `dist/OrquestadorAVANSAT.exe` (si es archivo único, dependiendo de la configuración del .spec).

## Estructura del Archivo Excel
El archivo de entrada debe tener las siguientes hojas (los nombres deben coincidir exactamente):

*   `Liquidacion`: Para liquidación de manifiestos.
*   `Servicios`: Para servicios especiales.
*   `prefacturas`: Para generación de prefacturas.
*   `actualizar_facturas`: Para adición de remesas.

Cada hoja debe contener las columnas específicas que esperan los scripts de automatización (ej. `Remesa`, `CIUDAD ORIGEN`, `AGENCIA FACTURACION`, etc.).

## Soporte
Desarrollado para automatización interna de procesos PyP.
**Versión actual**: 3.5 (Modern UI)
**Desarrollador**: Juan Saavedra
