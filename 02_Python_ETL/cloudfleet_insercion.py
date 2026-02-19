# cloudfleet_insercion.py

import pandas as pd
import mysql.connector
from conexion_mysql import conectar_mysql
from pathlib import Path

# --- Rutas dinámicas ---
BASE_DIR = Path(__file__).parent.resolve()  # Carpeta donde está el script
RUTA_LOGS = BASE_DIR / "logs"
RUTA_LOGS.mkdir(exist_ok=True)  # Crear carpeta de logs si no existe


def nan_to_none(value):
    """
    Convierte valores NaN de pandas a None para MySQL.
    """
    return None if pd.isna(value) else value


def insertar_datos_cloudfleet(dfs_transformados, logger):
    """
    Inserta en MySQL los DataFrames transformados de CloudFleet:
    1. Extrae el DataFrame de vehículos del diccionario.
    2. Limpia la tabla de staging.
    3. Inserta registros en staging.
    4. Sincroniza staging con la tabla principal.
    """
    # Obtener DataFrame de vehículos
    df_vehicles = None
    for key, df in dfs_transformados.items():
        if 'vehicles' in key.lower():
            df_vehicles = df
            logger.info(f"DataFrame '{key}' listo para inserción. Total registros: {len(df_vehicles)}")
            break

    if df_vehicles is None or df_vehicles.empty:
        logger.warning("No se encontró el DataFrame de vehículos o está vacío. Abortando inserción.")
        return

    conn = None
    cursor = None
    try:
        conn = conectar_mysql()
        if not (conn and conn.is_connected()):
            logger.error("No se pudo establecer conexión con MySQL.")
            return
        cursor = conn.cursor()
        logger.info("Conexión a MySQL establecida correctamente.")

        # 1. Limpiar la tabla de staging
        logger.info("Limpiando staging 'staging_vehiculos_propios'...")
        cursor.callproc('limpiar_staging_vehiculos_propios')
        logger.info("Staging limpiado correctamente.")

        # 2. Insertar datos en staging
        total = len(df_vehicles)
        insert_count = 0
        logger.info(f"Iniciando inserción de {total} registros en staging...")
        for _, row in df_vehicles.iterrows():
            args = [nan_to_none(row[col]) for col in df_vehicles.columns]
            try:
                cursor.callproc('insertar_en_staging_vehiculos_propios', args)
                insert_count += 1
            except mysql.connector.Error as err:
                logger.error(f"MySQL error al insertar placa {row.get('placa')}: {err}")
            except Exception as e:
                logger.error(f"Error inesperado al procesar placa {row.get('placa')}: {e}")

        logger.info(f"{insert_count}/{total} registros insertados en staging.")

        # 3. Sincronizar staging con tabla principal
        logger.info("Sincronizando staging con 'vehiculos_propios'...")
        out_args = [0, 0, 0]
        result = cursor.callproc('sp_sincronizar_vehiculos_propios', out_args)
        logger.info(f"--- Resumen de sincronización: Duración {result[0]}s | Inserts {result[1]} | Updates {result[2]} ---")


        # 4. Limpieza final de tabla staging
        logger.info("Limpiando staging 'staging_vehiculos_propios'...")
        cursor.callproc('limpiar_staging_vehiculos_propios')
        logger.info("Staging limpiado correctamente.")

        # Commit
        conn.commit()
        logger.info("Transacción COMMIT ejecutada correctamente.")

    except mysql.connector.Error as err:
        logger.error(f"MySQL Error global: {err}")
        if conn and conn.is_connected():
            logger.warning("Ejecutando ROLLBACK.")
            conn.rollback()
    except Exception as e:
        logger.error(f"Error inesperado: {e}")
        if conn and conn.is_connected():
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()
            logger.info("Conexión a MySQL cerrada.")
