# carga_Avansat_Terceros.py

import pandas as pd
import mysql.connector
from conexion_mysql import conectar_mysql


def _normalizar_columnas(df: pd.DataFrame) -> pd.DataFrame:
    # Evita que 'Placa' no coincida por NBSP / espacios invisibles
    df = df.copy()
    df.columns = (
        df.columns.astype(str)
        .str.replace("\u00a0", " ", regex=False)  # NBSP -> espacio normal
        .str.strip()
    )
    return df


def cargar_vehiculos(df, logger):
    logger.info("🚀 [ETL-VEHÍCULOS] Iniciando carga a MySQL...")
    conexion = conectar_mysql("log_AVANSAT")
    if not conexion:
        logger.error("❌ No hay conexión a BD. Abortando carga de vehículos.")
        return

    cursor = conexion.cursor()
    try:
        df = _normalizar_columnas(df)

        # 1) LIMPIAR STAGING (inicio)
        logger.info("🧹 Limpiando tabla staging_vehiculos_avansat (TRUNCATE vía SP)...")
        cursor.callproc("limpiar_staging_vehiculos")
        conexion.commit()

        # 2) INSERTAR EN STAGING (vía SP)
        cols_orden = [
            "Placa", "Marca", "Línea", "Modelo",
            "Ciudad Conductor", "Capacidad", "Estado Vehículo",
            "Nombre Conductor", "C.C. Conductor", "Celular Conductor", "Dirección Conductor"
        ]

        # Garantizar columnas
        for col in cols_orden:
            if col not in df.columns:
                df[col] = None

        datos_insert = df[cols_orden].where(pd.notnull(df), None).values.tolist()

        logger.info(f"📥 Insertando {len(datos_insert)} registros en staging vía SP insertar_en_staging_vehiculos...")

        # Inserción fila por fila vía SP (cumple tu regla de pipeline)
        for row in datos_insert:
            cursor.callproc("insertar_en_staging_vehiculos", row)

        conexion.commit()
        logger.info("✅ Staging vehículos cargado vía SP.")

        # 3) SINCRONIZAR staging -> destino (vía SP)
        logger.info("🔄 Ejecutando SP Maestro: sp_sincronizar_vehiculos_complejo...")
        args = [0, 0, 0]  # OUT: duracion, inserts, updates
        result = cursor.callproc("sp_sincronizar_vehiculos_complejo", args)
        conexion.commit()

        p_duracion, p_inserts, p_updates = result[0], result[1], result[2]
        logger.info(f"✅ Sincronización FINALIZADA. ⏱ {p_duracion}s | 🆕 {p_inserts} | ♻ {p_updates}")

        # 4) LIMPIAR STAGING (final)
        logger.info("🧹 Limpiando tabla staging_vehiculos_avansat (TRUNCATE vía SP) [final]...")
        cursor.callproc("limpiar_staging_vehiculos")
        conexion.commit()

    except mysql.connector.Error as err:
        logger.error(f"❌ Error MySQL Crítico en Carga Vehículos: {err}")
        conexion.rollback()
    except Exception as e:
        logger.error(f"❌ Error Python en Carga Vehículos: {e}")
        conexion.rollback()
    finally:
        if conexion.is_connected():
            cursor.close()
            conexion.close()
            logger.info("🔒 Conexión MySQL cerrada (Vehículos).")


def cargar_conductores(df, logger):
    logger.info("🚀 [ETL-CONDUCTORES] Iniciando carga a MySQL...")
    conexion = conectar_mysql("log_AVANSAT")
    if not conexion:
        return

    cursor = conexion.cursor()
    try:
        df = _normalizar_columnas(df)

        # 1) LIMPIAR STAGING (inicio)
        logger.info("🧹 Limpiando staging_conductores_avansat (TRUNCATE vía SP)...")
        cursor.callproc("limpiar_staging_conductores")
        conexion.commit()

        # 2) INSERTAR EN STAGING (vía SP)
        cols_orden = ["Nit o CC", "Nombre", "Estado"]
        for col in cols_orden:
            if col not in df.columns:
                df[col] = None

        datos_insert = df[cols_orden].where(pd.notnull(df), None).values.tolist()

        logger.info(f"📥 Insertando {len(datos_insert)} conductores en staging vía SP insertar_en_staging_conductores...")

        for row in datos_insert:
            cursor.callproc("insertar_en_staging_conductores", row)

        conexion.commit()
        logger.info("✅ Staging conductores cargado vía SP.")

        # 3) SINCRONIZAR
        logger.info("🔄 Ejecutando SP: sp_sincronizar_conductores...")
        args = [0, 0, 0]
        result = cursor.callproc("sp_sincronizar_conductores", args)
        conexion.commit()

        p_duracion, p_inserts, p_updates = result[0], result[1], result[2]
        logger.info(f"✅ Sincronización FINALIZADA. ⏱ {p_duracion}s | 🆕 {p_inserts} | ♻ {p_updates}")

        # 4) LIMPIAR STAGING (final)
        logger.info("🧹 Limpiando staging_conductores_avansat (TRUNCATE vía SP) [final]...")
        cursor.callproc("limpiar_staging_conductores")
        conexion.commit()

    except mysql.connector.Error as err:
        logger.error(f"❌ Error MySQL Conductores: {err}")
        conexion.rollback()
    except Exception as e:
        logger.error(f"❌ Error Python Conductores: {e}")
        conexion.rollback()
    finally:
        if conexion.is_connected():
            cursor.close()
            conexion.close()
