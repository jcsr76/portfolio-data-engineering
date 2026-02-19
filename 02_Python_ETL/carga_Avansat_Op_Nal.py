from pathlib import Path
import mysql.connector
import pandas as pd
import json
import sys
import os
from conexion_mysql import conectar_mysql


# Función para obtener la ruta correcta del recurso (soporta PyInstaller)
def get_resource_path(relative_path):
    """ Devuelve la ruta absoluta al recurso tanto en .py como en .exe """
    try:
        # Cuando se ejecuta desde un .exe empaquetado con PyInstaller
        base_path = sys._MEIPASS
    except Exception:
        # Cuando se ejecuta normalmente con Python
        base_path = Path(__file__).parent.resolve()
    return os.path.join(base_path, relative_path)


# Ruta al archivo de mapeo
RUTA_MAPEO_COLUMNAS = get_resource_path(os.path.join("etl_utils", "mapeo_columnas.json"))


def cargar_operacion_nacional(df, logger):
    conexion = conectar_mysql("log_AVANSAT")
    if not conexion:
        logger.error("❌ No se pudo conectar a MySQL. Abortando carga.")
        return

    try:
        cursor = conexion.cursor()

        # Paso 1: Truncar la tabla de staging usando SP
        logger.info("🧹 Limpiando tabla staging_operaciones_avansat...")
        cursor.callproc("limpiar_staging_operaciones")
        conexion.commit()
        logger.info("✅ Tabla staging limpiada correctamente.")

        # Paso 2: Cargar el mapeo de columnas
        with open(RUTA_MAPEO_COLUMNAS, "r", encoding="utf-8") as f:
            mapeo_columnas = json.load(f)

        logger.info("🔁 Renombrando columnas del DataFrame...")
        df.rename(columns=mapeo_columnas, inplace=True)
        logger.info(f"Columnas renombradas: {list(df.columns)}")

        # Paso 3: Insertar fila por fila mediante SP
        logger.info("Iniciando Inserción de Datos en pypdb-MySQL, tabla staging_operaciones...")
        procedimiento = "insertar_en_staging_operaciones"
        total_insertados = 0

        for _, fila in df.iterrows():
            try:
                fila_convertida = [
                    None if pd.isna(x) or (isinstance(x, str) and x.strip().lower() == "nan") else x
                    for x in fila.tolist()
                ]

                cursor.callproc(procedimiento, fila_convertida)
                total_insertados += 1

            except mysql.connector.Error as err:
                logger.warning(f"⚠️ Error MySQL al insertar fila: {err}")
                try:
                    cursor.callproc(
                        "registrar_error_etl",
                        (
                            procedimiento,
                            str(err),
                            f"{fila.get('manifiesto')}|{fila.get('fecha_manifiesto')}|{fila.get('placa')}",
                        ),
                    )
                    conexion.commit()
                except Exception as log_err:
                    logger.error(f"⚠️ Fallo al registrar error en log_errores_etl: {log_err}")

        conexion.commit()
        logger.info(f"✅ Carga completada: {total_insertados} registros insertados en staging_operaciones_avansat.")

        # Paso 4: Ejecutar sincronización con tabla final con parámetros OUT
        logger.info("🔄 Iniciando sincronización con operaciones_avansat...")

        try:
            args = [0, 0, 0]  # valores iniciales de los parámetros OUT
            result_args = cursor.callproc("sp_sincronizar_operaciones_avansat", args)

            p_duracion = result_args[0]
            p_inserts = result_args[1]
            p_updates = result_args[2]

            conexion.commit()

            logger.info(
                f"✅ Sincronización completada: {p_inserts} insertados, {p_updates} actualizados, duración total: {p_duracion} segundos."
            )

            logger.info("🧹 Limpiando tabla staging_operaciones_avansat luego de sincronización exitosa...")
            cursor.callproc("limpiar_staging_operaciones")
            conexion.commit()
            logger.info("✅ Tabla staging limpiada correctamente después de sincronización.")

        except mysql.connector.Error as err:
            conexion.rollback()
            logger.error(f"❌ Error al ejecutar sp_sincronizar_operaciones_avansat: {err}")

    except Exception as e:
        logger.error(f"❌ Error en proceso de carga: {e}")

    finally:
        if conexion.is_connected():
            cursor.close()
            conexion.close()
            logger.info("🔒 Conexión MySQL cerrada.")