# transformacion_Avansat_Op_Nal.py

import glob
from pathlib import Path
import warnings

import numpy as np
import pandas as pd
from logger_config import configurar_logger
from utils_rutas import resource_path

RUTA_OPERACION_NAL = resource_path("operacion_nacional")
RUTA_OPERACION_NAL.mkdir(exist_ok=True)


def transformar_reporte_operacion_nal(ruta_descargas=None, logger=None):
    if logger is None:
        logger = configurar_logger("log_AVANSAT")

    warnings.simplefilter(action="ignore", category=FutureWarning)

    # Si no se recibe ruta, usar la ruta absoluta dinámica
    if ruta_descargas is None:
        ruta_descargas = RUTA_OPERACION_NAL

    archivos = glob.glob(str(ruta_descargas / "*.html"))
    if archivos:
        archivo_reciente = max(archivos, key=lambda x: Path(x).stat().st_mtime)
        logger.info(f"Archivo cargado: {archivo_reciente}")
    else:
        logger.error("No se encontraron archivos HTML en la carpeta de descargas.")
        return None

    logger.info("Intentando leer todas las tablas del archivo HTML Operacion Nacional...")
    try:
        tables = pd.read_html(archivo_reciente)
        # Combinar todas las tablas del HTML en un solo DataFrame
        if len(tables) > 1:
            df = pd.concat(tables, ignore_index=True)
            logger.info(
                f"Se encontraron {len(tables)} tablas en el HTML, concatenadas en un DataFrame único."
            )
        else:
            df = tables[0]
            logger.info("Primera (única) tabla del HTML cargada correctamente.")

        # Paso 1: Eliminar columnas innecesarias
        columnas_a_eliminar = [
            "Contenedor 1", "Contenedor 2", "Asesor Comercial", "Tiquete Cargue",
            "Tiquete Descargue", "Novedad Reportada", "Descripción Nov. Cum.",
            "Campo1 (Opcional)", "Orden de Servicio", "Remesa Padre", "Aplica Rentabilidad",
            "Manifiesto Paqueteo", "Nro. Remesa Paqueteo", "Tipo de Manifiesto",
            "Aplica Rentabilidad.1", "Val. Ser. Esp. Rem.", "Val. Ser. Esp. Man."
        ]
        df.drop(columns=columnas_a_eliminar, axis=1, inplace=True, errors="ignore")

        # Paso 2: Limpiar cadenas inválidas en columnas de fecha
        logger.info("Reemplazando valores no válidos en columnas de fecha...")
        valores_invalidos = ["Sin Llegar", "Sin Salir", "0000-00-00", "0000-00-00 00:00:00", "2001-00-00 00:00:00"]
        columnas_datetime = [
            "Fecha Manifiesto", "Fecha Remesa", "Fecha Salida Despacho", "Fecha Llegada Despacho",
            "Cumplida", "Fecha Llegada de Cargue", "Fecha Salida de Cargue", "Fecha Llegada de Descargue",
            "Fecha Salida de Descargue", "Fecha Factura", "Fecha Vencimiento", "Fecha Cumplido Manifiesto",
            "Fecha Liquid.", "Fecha Pago", "Fecha de Recaudo",
            "Fecha y Hora Entrada al Cargue", "Fecha y Hora Entrada al Descargue"
        ]
        for col in columnas_datetime:
            if col in df.columns:
                df[col] = df[col].astype(str).replace(valores_invalidos, np.nan)

        # Paso 3: Eliminar siempre la última fila (Totales), si hay más de una fila
        if df.shape[0] > 1:
            df = df.iloc[:-1]
            logger.info("Última fila eliminada (Totales).")
        else:
            logger.warning(
                "El DataFrame solo tiene una fila. No se eliminará la última fila para evitar pérdida total de datos."
            )

        # Paso 4: Confirmar resultado
        logger.info(f"Forma final del DataFrame: {df.shape}")
        logger.info(f"Columnas del DataFrame: {df.columns.tolist()} (Total: {len(df.columns)})")
        logger.info("✅ Proceso de transformación y limpieza completado con éxito.")
        return df

    except Exception as e:
        logger.error(f"❌ Error al leer el archivo HTML Operacion Nacional: {e}")
        return None
