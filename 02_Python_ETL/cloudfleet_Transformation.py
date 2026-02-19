# cloudfleet_Trnasformation.py

import os
import json
import pandas as pd
from logger_config import configurar_logger
from datetime import datetime
from pathlib import Path

# Diccionario de tipología
tipologia_dict = {
    'NKR': 1, 'NHR': 2, 'NNR': 3, 'FRR': 4, 'NPR': 5, 'NQR': 6,
    'SENCILLO': 7, 'MOTOCARRO': 8, 'TRACTOCAMION': 11, 'VAN': 12,
    'NO ESPECIFICADO': 13
}

codigos_dict = {
    "APO": 2, "AUC": 3, "AXM": 25, "BAQ": 4, "BGA": 28,
    "BOG": 5, "CLO": 31, "CTG": 6, "CUC": 23, "EJA": 28,
    "EPY": 10, "FLA": 9, "HAY": 12, "IBE": 30, "IPI": 22,
    "LET": 1, "MDE": 2, "MTR": 14, "MVP": 32, "MZL": 8,
    "NAL": 34, "NVA": 18, "PCR": 33, "PEI": 26, "PPN": 11,
    "PSO": 22, "PUU": 24, "PVA": 22, "RCH": 19, "SJE": 17,
    "SMR": 20, "TCO": 22, "UIB": 13, "VGZ": 24, "VUP": 12,
    "VVC": 21, "NAL/URB": 34
}

# Modelos clasificados como "Patineta Poderosa"
patineta_poderosa_modelos = [
    {"brand": "International", "line": "7600 SBA 4X2"},
    {"brand": "Hino", "line": "500 SG1AF7B"},
    {"brand": "Sinotruck", "line": "ZZ4187N361GF1"}
]

# Modelos clasificados como "Patineta" (normal)
patineta_normal_modelos = [
    {"brand": "Freightliner", "line": "M2 106"},
    {"brand": "Mercedes Benz", "line": "ATEGO 1730 S"},
    {"brand": "Renault", "line": "MIDLUM 280"}
]


# Logger
logger = configurar_logger("cloudfleet_main")

# Rutas de salida (pueden ser opcionales si solo se busca el retorno en memoria)
ruta_salida = r"C:\temp"
os.makedirs(ruta_salida, exist_ok=True) # Asegura que la carpeta exista

# Funciones auxiliares
def cargar_json(ruta_completa):
    if not os.path.exists(ruta_completa):
        logger.error(f"No se encontró el archivo: {ruta_completa}")
        raise FileNotFoundError(f"No se encontró el archivo: {ruta_completa}")

    logger.info(f"Cargando archivo: {ruta_completa}")
    with open(ruta_completa, "r", encoding="utf-8") as f:
        data = json.load(f)

    return pd.DataFrame(data)

def exportar_excel(df, nombre_archivo_salida):
    """Función para exportar un DataFrame a Excel. Ahora es una función auxiliar."""
    ruta_excel = os.path.join(ruta_salida, nombre_archivo_salida)
    df.to_excel(ruta_excel, index=False)
    logger.info(f"Exportado a: {ruta_excel} → {len(df)} registros")

def asignar_id_tipologia(row):
    tipo = str(row["typeName"]).strip().upper()
    marca = str(row["brandName"]).strip()
    modelo = str(row["lineName"]).strip()

    if tipo != "PATINETA":
        return tipologia_dict.get(tipo, 13)

    marca_lower = marca.lower()
    modelo_lower = modelo.lower()

    for p_poderosa in patineta_poderosa_modelos:
        if marca_lower == p_poderosa["brand"].lower() and modelo_lower == p_poderosa["line"].lower():
            return 10
    for p_normal in patineta_normal_modelos:
        if marca_lower == p_normal["brand"].lower() and modelo_lower == p_normal["line"].lower():
            return 9

    logger.warning(f"PATINETA no clasificada para marca: {marca}, modelo: {modelo}. Asignando 'NO ESPECIFICADO' (ID 13).")
    return 13

# --- Función principal de transformación ---
def obtener_dfs_transformados():
    """
    Carga y transforma los DataFrames JSON desde la ruta fija 'informes_cloudfleet'.
    Retorna un diccionario con los DataFrames transformados.
    """
    BASE_DIR = Path(__file__).parent.resolve()  # Carpeta donde está el script
    CARPETA_CLOUD_FLEET = BASE_DIR / "informes_cloudfleet"
    ruta_base_archivos = CARPETA_CLOUD_FLEET

    dataframes = {}
    nombres_df_cargados = []

    for archivo_path in Path(ruta_base_archivos).iterdir():
        if archivo_path.suffix.lower() == ".json":
            try:
                if "vehicles" in archivo_path.name.lower():
                    with archivo_path.open("r", encoding="utf-8") as f:
                        data = json.load(f)
                    df = pd.json_normalize(data)
                else:
                    df = cargar_json(archivo_path)

                base_sin_ext = archivo_path.stem.replace('-', '_')
                dataframes[base_sin_ext] = df
                nombres_df_cargados.append(base_sin_ext)

            except Exception as e:
                logger.error(f"Error procesando {archivo_path.name}: {e}")

    logger.info(f"DataFrames cargados: {nombres_df_cargados}")
    for nombre_df_k, df_v in dataframes.items():
        logger.info(f"{nombre_df_k}: {len(df_v)} registros, columnas: {list(df_v.columns)}")

    # --- Transformación específica para df_vehicles ---
    nombre_df_vehicles = next((k for k in dataframes if "vehicles" in k.lower()), None)

    if nombre_df_vehicles:
        logger.info(f"Iniciando transformación de '{nombre_df_vehicles}'...")

        df_vehicles = dataframes[nombre_df_vehicles].copy()

        # Ajuste en la función procesar_odometer
        def procesar_odometer_mejorado(row):
            km = row.get('odometer.lastMeter')
            fecha_raw = row.get('odometer.lastMeterAt')

            fecha = None
            if pd.notna(fecha_raw) and isinstance(fecha_raw, str):
                try:
                    # 1. Intenta parsear el formato YYYY-MM-DDTHH:MM:SS (común en APIs)
                    fecha = datetime.strptime(fecha_raw.split('.')[0], "%Y-%m-%dT%H:%M:%S")
                except ValueError:
                    try:
                        # 2. Intenta parsear el formato DD/MM/YYYY HH:MM:SS (24 horas, el formato de tu último error)
                        fecha = datetime.strptime(fecha_raw, "%d/%m/%Y %H:%M:%S")
                    except ValueError:
                        try:
                            # 3. Intenta parsear el formato DD/MM/YYYY HH:MM:SS AM/PM (formato de 12 horas con AM/PM)
                            fecha = datetime.strptime(fecha_raw, "%d/%m/%Y %I:%M:%S %p.")
                        except ValueError:
                            logger.warning(f"Formato de fecha de odómetro inválido: '{fecha_raw}'. Se asignará None.")

            # Si la fecha fue parseada con éxito a un objeto datetime, formatéala a YYYY-MM-DD HH:MM:SS
            if isinstance(fecha, datetime):
                return pd.Series([km, fecha.strftime("%Y-%m-%d %H:%M:%S")])
            else:
                return pd.Series([km, None])


        if 'odometer.lastMeter' in df_vehicles.columns and 'odometer.lastMeterAt' in df_vehicles.columns:
            # CAMBIO CRÍTICO: Renombrar a 'odometer' y 'fecha_ult_med' directamente
            # Aplicar la función que ahora maneja ambos formatos posibles
            df_vehicles[['odometer', 'fecha_ult_med']] = df_vehicles.apply(procesar_odometer_mejorado, axis=1)
            logger.info("Columnas 'odometer' y 'fecha_ult_med' creadas y pobladas desde 'odometer'.")
            # Elimina las columnas originales
            df_vehicles = df_vehicles.drop(columns=['odometer.lastMeter', 'odometer.lastMeterAt'], errors='ignore')
        else:
            logger.warning("Las columnas 'odometer.lastMeter' o 'odometer.lastMeterAt' no se encontraron. No se aplicará la transformación de odómetro.")
            df_vehicles['odometer'] = None
            df_vehicles['fecha_ult_med'] = None


        # --- Transformación de id_tipologia ---
        if 'brandName' in df_vehicles.columns and 'lineName' in df_vehicles.columns and 'typeName' in df_vehicles.columns:
            df_vehicles.loc[:, "id_tipologia"] = df_vehicles.apply(asignar_id_tipologia, axis=1)
        else:
            logger.error("Faltan columnas 'brandName', 'lineName' o 'typeName' para asignar id_tipologia.")


        # --- Transformación de id_base ---
        logger.info("Iniciando asignación de 'id_base' a partir de la columna 'city.code' en df_vehicles")
        if 'city.code' in df_vehicles.columns:
            df_vehicles.loc[:, "id_base"] = df_vehicles["city.code"].apply(
                lambda x: codigos_dict.get(x) if x else None
            )
            logger.info("Columna 'id_base' creada exitosamente en df_vehicles")
            df_vehicles = df_vehicles.drop(columns=['city.id', 'city.name', 'city.code'], errors='ignore')
        else:
            logger.warning("La columna 'city.code' no existe en df_vehicles. No se creará 'id_base'.")
            df_vehicles['id_base'] = None

        # --- Transformación de costCenter ---
        logger.info("Iniciando transformación de la columna 'costCenter.name' en df_vehicles.")
        if 'costCenter.name' in df_vehicles.columns:
            df_vehicles.loc[:, 'centro_costo'] = df_vehicles['costCenter.name']
            logger.info("Columna 'centro_costo' transformada exitosamente para conservar solo el nombre.")
            df_vehicles = df_vehicles.drop(columns=['costCenter.id', 'costCenter.name', 'costCenter.code'], errors='ignore')
        else:
            logger.warning("La columna 'costCenter.name' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['centro_costo'] = None

        # --- Transformación de weightCapacity ---
        logger.info("Iniciando transformación de la columna 'weightCapacity.value' en df_vehicles.")
        if 'weightCapacity.value' in df_vehicles.columns:
            df_vehicles.loc[:, 'capacidad'] = df_vehicles['weightCapacity.value']
            logger.info("Columna 'capacidad' transformada exitosamente para conservar solo el valor numérico.")
            df_vehicles = df_vehicles.drop(columns=['weightCapacity.value', 'weightCapacity.unit'], errors='ignore')
        else:
            logger.warning("La columna 'weightCapacity.value' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['capacidad'] = None


        # --- Transformación de createdAt ---
        logger.info("Iniciando transformación de la columna 'createdAt' en df_vehicles para formato MySQL DATETIME.")
        if 'createdAt' in df_vehicles.columns:
            def format_created_at(date_str):
                if pd.isna(date_str) or not isinstance(date_str, str):
                    return None
                try:
                    dt_obj = datetime.strptime(date_str.split('.')[0], "%Y-%m-%dT%H:%M:%S")
                    return dt_obj.strftime("%Y-%m-%d %H:%M:%S")
                except Exception as e:
                    logger.warning(f"Error procesando createdAt '{date_str}': {e}. Se asignará None.")
                    return None

            df_vehicles.loc[:, 'fecha_creacion'] = df_vehicles['createdAt'].apply(format_created_at)
            logger.info("Columna 'fecha_creacion' transformada exitosamente a formato MySQL DATETIME.")
            df_vehicles = df_vehicles.drop(columns=['createdAt'], errors='ignore')
        else:
             logger.warning("La columna 'createdAt' no existe en df_vehicles. No se aplicará la transformación de fecha.")
             df_vehicles['fecha_creacion'] = None

        # --- Transformación de purchaseDate ---
        logger.info("Iniciando transformación de la columna 'purchaseDate' en df_vehicles para formato MySQL DATE.")
        if 'purchaseDate' in df_vehicles.columns:
            def format_purchase_date(date_str):
                if pd.isna(date_str) or not isinstance(date_str, str):
                    return None
                try:
                    dt_obj = datetime.fromisoformat(date_str.split('T')[0])
                    return dt_obj.strftime("%Y-%m-%d")
                except Exception as e:
                    logger.warning(f"Error procesando purchaseDate '{date_str}': {e}. Se asignará None.")
                    return None

            df_vehicles.loc[:, 'fecha_compra'] = df_vehicles['purchaseDate'].apply(format_purchase_date)
            logger.info("Columna 'fecha_compra' transformada exitosamente a formato MySQL DATE.")
            df_vehicles = df_vehicles.drop(columns=['purchaseDate'], errors='ignore')
        else:
             logger.warning("La columna 'purchaseDate' no existe en df_vehicles. No se aplicará la transformación de fecha.")
             df_vehicles['fecha_compra'] = None

        # --- Transformación de fuelType ---
        logger.info("Iniciando transformación de la columna 'mainFuelType' en df_vehicles.")
        if 'mainFuelType' in df_vehicles.columns:
            df_vehicles.loc[:, 'tipo_combustible'] = df_vehicles['mainFuelType']
            logger.info("Columna 'tipo_combustible' transformada exitosamente.")
            df_vehicles = df_vehicles.drop(columns=['mainFuelType', 'auxFuelType'], errors='ignore')
        else:
            logger.warning("La columna 'mainFuelType' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['tipo_combustible'] = None

        # --- Transformación de owner ---
        logger.info("Iniciando transformación de la columna 'owner.name' en df_vehicles.")
        if 'owner.name' in df_vehicles.columns:
            df_vehicles.loc[:, 'propietario'] = df_vehicles['owner.name']
            logger.info("Columna 'propietario' transformada exitosamente.")
            df_vehicles = df_vehicles.drop(columns=['owner.id', 'owner.name'], errors='ignore')
        else:
            logger.warning("La columna 'owner.name' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['propietario'] = None

        # --- Transformación de engine ---
        logger.info("Iniciando transformación de la columna 'engine.code' en df_vehicles.")
        if 'engine.code' in df_vehicles.columns:
            df_vehicles.loc[:, 'motor'] = df_vehicles['engine.code']
            logger.info("Columna 'motor' transformada exitosamente.")
            df_vehicles = df_vehicles.drop(columns=['engine.brand', 'engine.line', 'engine.code'], errors='ignore')
        else:
            logger.warning("La columna 'engine.code' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['motor'] = None

        # --- Transformación de createdBy ---
        logger.info("Iniciando transformación de la columna 'createdBy.name' en df_vehicles.")
        if 'createdBy.name' in df_vehicles.columns:
            df_vehicles.loc[:, 'creado_por'] = df_vehicles['createdBy.name']
            logger.info("Columna 'creado_por' transformada exitosamente.")
            df_vehicles = df_vehicles.drop(columns=['createdBy.id', 'createdBy.name'], errors='ignore')
        else:
            logger.warning("La columna 'createdBy.name' no existe en df_vehicles. No se aplicará la transformación.")
            df_vehicles['creado_por'] = None


        # Renombrar columnas para que coincidan con la tabla de staging
        df_vehicles = df_vehicles.rename(columns={
            'code': 'placa',
            'brandName': 'marca',
            'lineName': 'modelo',
            'year': 'anio',
            'maxOdometerDay': 'max_km_diario',
            'avgOdometerDay': 'prom_km_diario', # <--- CORREGIDO AQUÍ
            'vin': 'vin',
            'chassisNumber': 'num_chasis',
            'serialNumber': 'num_serial',
            'purchasePrice': 'costo'
        })
        logger.info("Columnas de df_vehicles renombradas para coincidir con la tabla de staging.")

        # --- REINDEXADO FINAL PARA ASEGURAR EL ORDEN EXACTO PARA LA INSERCIÓN ---
        # Este es el ajuste crucial para el orden que mencionaste.
        final_columns_order = [
            'placa', 'id_tipologia', 'marca', 'modelo', 'odometer',
            'fecha_ult_med', 'anio', 'tipo_combustible', 'max_km_diario',
            'prom_km_diario', # <--- CORREGIDO AQUÍ
            'id_base', 'centro_costo', 'vin', 'propietario',
            'motor', 'capacidad', 'num_chasis', 'num_serial', 'fecha_compra',
            'costo', 'fecha_creacion', 'creado_por'
        ]

        # Aseguramos que todas las columnas en final_columns_order existan.
        # Si alguna no existe después de todas las transformaciones, se creará con NaN (que nan_to_none convertirá a None).
        existing_columns = df_vehicles.columns.tolist()
        for col in final_columns_order:
            if col not in existing_columns:
                df_vehicles[col] = pd.NA # Usar pd.NA para Pandas 1.0+ para valores nulos que respeten tipos
                logger.warning(f"Columna '{col}' no existía y se creó vacía para mantener el orden final.")


        df_vehicles = df_vehicles[final_columns_order]
        logger.info("Orden final de columnas de df_vehicles establecido para coincidir con el procedimiento de inserción.")


        logger.info("Transformación de df_vehicles completada.")
        dataframes[nombre_df_vehicles] = df_vehicles

        # Exportar a Excel el DataFrame de vehículos transformado
        exportar_excel(df_vehicles, "df_vehiculos_transformados.xlsx")
    else:
        logger.warning("df_vehicles no fue encontrado para transformar.")

    return dataframes