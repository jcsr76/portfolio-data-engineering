import glob
import os
import pandas as pd
from logger_config import configurar_logger
from utils_rutas import resource_path

# Rutas dinámicas
RUTA_VEHICULOS = resource_path("vehiculos_terceros")
RUTA_CONDUCTORES = resource_path("conductores_terceros")

# Columnas exactas validadas
COLS_VEHICULOS_OBJETIVO = [
    "Placa", "Marca", "Línea", "Modelo",
    "Ciudad Conductor", "Capacidad", "Estado Vehículo",
    "Nombre Conductor", "C.C. Conductor", "Celular Conductor", "Dirección Conductor"
]

COLS_CONDUCTORES_OBJETIVO = [
    "Nit o CC", "Nombre", "1er apellido", "Estado"
]


def obtener_ultimo_archivo(ruta_carpeta):
    """Busca el archivo más reciente (.xls o .html) en la carpeta."""
    patron = str(ruta_carpeta / "*.*")
    archivos = [f for f in glob.glob(patron) if f.endswith(('.xls', '.html'))]
    if not archivos:
        return None
    return max(archivos, key=os.path.getmtime)


def limpiar_celda(val):
    """Limpia espacios en blanco y convierte 'nan' a None para MySQL."""
    if pd.isna(val):
        return None
    if isinstance(val, str):
        val = val.strip()
        if val.lower() in ["nan", "none", "", "null"]:
            return None
    return val


def transformar_vehiculos_terceros(logger=None):
    if logger is None:
        logger = configurar_logger("log_AVANSAT")

    logger.info("🚙 Iniciando transformación de Vehículos Terceros...")
    archivo = obtener_ultimo_archivo(RUTA_VEHICULOS)

    if not archivo:
        logger.error("❌ No se encontró archivo en carpeta vehiculos_terceros.")
        return None

    try:
        logger.info(f"Leyendo archivo: {os.path.basename(archivo)}")
        # Leemos sin header, asumiendo encoding latin-1 (validado en pruebas)
        dfs = pd.read_html(archivo, flavor='bs4', encoding='latin-1', header=None)
        df_raw = dfs[0]

        # Lógica de Rescate (Validada):
        # Fila 1 = Encabezados reales
        # Fila 3 en adelante = Datos reales

        # Asignar encabezados desde Fila 1
        headers = [str(c).strip() for c in df_raw.iloc[1].tolist()]
        df_raw.columns = headers

        # Filtrar datos desde fila 3
        df_datos = df_raw.iloc[3:].copy()

        # ✅ Descartar registros de prueba (Nombre Tenedor = 'CREADO AVANSAT PRUEBA')
        if "Nombre Tenedor" in df_datos.columns:
            # normalizar para comparación (strip + upper)
            mask_pruebas = (
                df_datos["Nombre Tenedor"]
                .astype(str)
                .str.strip()
                .str.upper()
                .eq("CREADO AVANSAT PRUEBA")
            )
            descartados = int(mask_pruebas.sum())
            df_datos = df_datos.loc[~mask_pruebas].copy()
            logger.info(f"🧹 Registros descartados por Nombre Tenedor='CREADO AVANSAT PRUEBA': {descartados}")
        else:
            logger.warning("⚠️ La columna 'Nombre Tenedor' no existe; no se aplicó filtro de registros de prueba.")

        # Seleccionar columnas objetivo
        cols_finales = [c for c in COLS_VEHICULOS_OBJETIVO if c in df_datos.columns]
        df_final = df_datos[cols_finales].copy()

        # Limpieza de valores
        df_final = df_final.applymap(limpiar_celda)

        # Eliminar registros sin Placa (basura al final del reporte)
        df_final = df_final.dropna(subset=['Placa'])

        logger.info(f"✅ Transformación Vehículos completada. {len(df_final)} registros listos.")
        return df_final

    except Exception as e:
        logger.error(f"❌ Error transformando Vehículos: {e}")
        return None


def transformar_conductores_terceros(logger=None):
    if logger is None:
        logger = configurar_logger("log_AVANSAT")

    logger.info("👨‍✈️ Iniciando transformación de Conductores Terceros...")
    archivo = obtener_ultimo_archivo(RUTA_CONDUCTORES)

    if not archivo:
        logger.error("❌ No se encontró archivo de Conductores.")
        return None

    try:
        # En conductores, la tabla suele ser la índice 1 (validado previamente)
        # Probamos leer buscando la tabla correcta
        dfs = pd.read_html(archivo, flavor='bs4', encoding='latin-1', header=0)

        df_target = None
        for df in dfs:
            # Normalizar nombres de columnas para buscar
            cols = [str(c).strip() for c in df.columns]
            if "Nit o CC" in cols:
                df.columns = cols
                df_target = df
                break

        if df_target is None:
            # Fallback: Intentar lógica manual similar a vehículos si falla la detección automática
            logger.warning("No se detectó tabla por headers estándar. Intentando rescate manual...")
            dfs = pd.read_html(archivo, flavor='bs4', encoding='latin-1', header=None)
            df_raw = dfs[0]
            # Asumimos header en fila 0 o 1
            headers = [str(c).strip() for c in df_raw.iloc[0].tolist()]
            if "Nit o CC" in headers:
                df_raw.columns = headers
                df_target = df_raw.iloc[1:].copy()
            else:
                logger.error("❌ No se pudo identificar la estructura del reporte de Conductores.")
                return None

        # Seleccionar y Limpiar
        cols_finales = [c for c in COLS_CONDUCTORES_OBJETIVO if c in df_target.columns]
        df_final = df_target[cols_finales].copy()

        df_final = df_final.applymap(limpiar_celda)
        df_final = df_final.dropna(subset=['Nit o CC'])

        logger.info(f"✅ Transformación Conductores completada. {len(df_final)} registros listos.")
        return df_final

    except Exception as e:
        logger.error(f"❌ Error transformando Conductores: {e}")
        return None
