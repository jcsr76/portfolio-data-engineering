# ETL_Main.py
from datetime import datetime

from logger_config import configurar_logger
from carga_Avansat_Op_Nal import cargar_operacion_nacional
from extraccion_Avansat import descargar_informes_avansat
from transformacion_Avansat_Op_Nal import transformar_reporte_operacion_nal
from cloudfleet_extraccion import descargar_datos_cloudfleet
from cloudfleet_Transformation import obtener_dfs_transformados
from cloudfleet_insercion import insertar_datos_cloudfleet
from transformacion_Avansat_Terceros import transformar_vehiculos_terceros, transformar_conductores_terceros
from carga_Avansat_Terceros import cargar_vehiculos, cargar_conductores


# ==== Función para ejecutar ETL Avansat ====
def ejecutar_etl_avansat(logger):
    try:
        logger.info("🚀 Iniciando proceso ETL AVANSAT Completo...")

        # ==========================================
        # ETAPA 1: EXTRACCIÓN (Común para todos)
        # ==========================================
        inicio_extraccion = datetime.now()
        logger.info("🔽 Paso 1: Extracción de reportes desde AVANSAT")

        # Descarga Operación Nal, Vehículos y Conductores
        extraccion_exitosa = descargar_informes_avansat(logger=logger)

        if not extraccion_exitosa:
            logger.error("❌ La extracción falló. Abortando todo el proceso Avansat.")
            return

        fin_extraccion = datetime.now()
        duracion_extraccion = (fin_extraccion - inicio_extraccion).total_seconds()
        logger.info(f"⏱ Duración de la extracción global: {duracion_extraccion:.2f} segundos.")

        # ==========================================
        # ETAPA 2 y 3: PROCESAMIENTO POR REPORTE
        # ==========================================

        # --- A. OPERACIÓN NACIONAL ---
        logger.info("--- Procesando: Operación Nacional ---")
        df_op = transformar_reporte_operacion_nal(logger=logger)
        if df_op is not None:
            cargar_operacion_nacional(df_op, logger)
        else:
            logger.warning("⚠️ Saltando carga de Operación Nacional por error en transformación.")

        # --- B. VEHÍCULOS TERCEROS ---
        logger.info("--- Procesando: Vehículos Terceros ---")
        df_veh = transformar_vehiculos_terceros(logger)
        if df_veh is not None and not df_veh.empty:
            cargar_vehiculos(df_veh, logger)
        else:
            logger.warning("⚠️ No hay datos de Vehículos para cargar.")

        # --- C. CONDUCTORES TERCEROS ---
        logger.info("--- Procesando: Conductores Terceros ---")
        df_cond = transformar_conductores_terceros(logger)
        if df_cond is not None and not df_cond.empty:
            cargar_conductores(df_cond, logger)
        else:
            logger.warning("⚠️ No hay datos de Conductores para cargar.")

    except Exception as e:
        logger.error(f"❌ Error inesperado durante el proceso ETL de Avansat: {e}")


# ==== Función para ejecutar ETL CloudFleet ====
def ejecutar_etl_cloudfleet(logger):
    try:
        logger.info("🚛 Iniciando proceso ETL CloudFleet...")

        # ETAPA 1: EXTRACCIÓN
        inicio_ex = datetime.now()
        logger.info("🔽 Paso 1: Extracción de datos desde CloudFleet")
        descargar_datos_cloudfleet(logger=logger)
        fin_ex = datetime.now()
        logger.info(f"⏱ Duración de la extracción CloudFleet: {(fin_ex - inicio_ex).total_seconds():.2f} segundos.")

        # ETAPA 2: TRANSFORMACIÓN
        inicio_tr = datetime.now()
        logger.info("🧪 Paso 2: Transformación de datos CloudFleet")
        dfs_cf = obtener_dfs_transformados()
        fin_tr = datetime.now()
        logger.info(f"⏱ Duración de la transformación CloudFleet: {(fin_tr - inicio_tr).total_seconds():.2f} segundos.")

        if not dfs_cf:
            logger.error("❌ Transformación CloudFleet fallida. Abortando.")
            return

        # ETAPA 3: CARGA
        inicio_cd = datetime.now()
        logger.info("🛠 Paso 3: Inserción de datos transformados CloudFleet en MySQL")
        insertar_datos_cloudfleet(dfs_cf, logger)
        fin_cd = datetime.now()
        logger.info(f"⏱ Duración de la carga CloudFleet: {(fin_cd - inicio_cd).total_seconds():.2f} segundos.")

    except Exception as e:
        logger.error(f"❌ Error inesperado durante ETL CloudFleet: {e}")


# ==== Main ====
if __name__ == "__main__":
    logger = configurar_logger("log_ETL_GENERAL")
    inicio_global = datetime.now()

    # 1. Ejecutar Todo el bloque Avansat (Op. Nal + Vehículos + Conductores)
    ejecutar_etl_avansat(logger)

    # 2. Ejecutar CloudFleet
    ejecutar_etl_cloudfleet(logger)

    fin_global = datetime.now()
    logger.info(
        f"🕒 Duración total de todos los procesos ETL: {(fin_global - inicio_global).total_seconds():.2f} segundos.")
