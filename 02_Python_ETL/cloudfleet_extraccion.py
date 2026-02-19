# cloudfleet_extraccion.py

import json
import time
from pathlib import Path
from api_utils import consultar_api

# Carpeta base donde corre el script
BASE_DIR = Path(__file__).parent.resolve()
CARPETA_INFORMES = BASE_DIR / "informes_cloudfleet"


def limpiar_carpeta(logger):
    logger.info("Limpiando carpeta 'informes_cloudfleet'...")
    if CARPETA_INFORMES.exists():
        for archivo in CARPETA_INFORMES.iterdir():
            try:
                if archivo.is_file():
                    archivo.unlink()
                    logger.info(f"Eliminado {archivo.name}")
            except Exception as e:
                logger.error(f"Error eliminando {archivo.name}: {e}")
        logger.info("Carpeta 'informes_cloudfleet' limpiada correctamente")
    else:
        CARPETA_INFORMES.mkdir(parents=True, exist_ok=True)
        logger.info("Carpeta 'informes_cloudfleet' creada")


def control_tasa_consumo(headers, logger):
    rate_remaining = headers.get("RateLimit-Remaining", 1)
    rate_reset = headers.get("RateLimit-Reset", 0)
    logger.info(f"Peticiones restantes: {rate_remaining}")
    logger.info(f"Tiempo hasta reinicio: {rate_reset} segundos (se usará 60s si es 0)")
    if rate_remaining == 0:
        wait = (rate_reset if rate_reset > 0 else 60) + 3
        logger.warning(f"Se alcanzó el límite de peticiones. Esperando {wait} segundos...")
        time.sleep(wait)
    time.sleep(2)


def procesar_individual(ruta, clave_id, path_template, logger):
    ruta_path = Path(ruta)
    if not ruta_path.exists():
        logger.warning(f"Archivo no encontrado: {ruta}. Se omite esta consulta.")
        return []

    try:
        with ruta_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
            ids = [item[clave_id] for item in data]
            logger.info(f"{len(ids)} items para consulta individual desde {ruta}")
    except Exception as e:
        logger.error(f"Error cargando {ruta}: {e}")
        return []

    for id_val in ids:
        codigo, mensaje, headers = consultar_api(path_template.format(id_val))
        logger.info(f"Consulta {path_template.format(id_val)} → {codigo} - {mensaje}")
        control_tasa_consumo(headers, logger)
    return ids


def descargar_datos_cloudfleet(logger):
    logger.info("--- Inicio de descarga desde CloudFleet ---")

    endpoints = ["vehicles/", "work-orders/", "fuel-entries/", "availability"]
    limpiar_carpeta(logger)

    for endpoint in endpoints:
        logger.info(f"Consultando endpoint: {endpoint}")
        try:
            codigo, mensaje, headers = consultar_api(endpoint)
        except Exception as e:
            logger.error(f"Error al consultar {endpoint}: {e}")
            continue
        control_tasa_consumo(headers, logger)

    # Checklists de últimos 30 días
    checklist_ids = []
    checklist_path = CARPETA_INFORMES / "checklist_.json"
    if checklist_path.exists():
        try:
            with checklist_path.open("r", encoding="utf-8") as f:
                checklist_data = json.load(f)
                checklist_ids = [item["number"] for item in checklist_data]
                logger.info(f"{len(checklist_ids)} checklists encontrados en los últimos 30 días")
        except Exception as e:
            logger.error(f"Error al procesar checklist_.json: {e}")

    for chk_id in checklist_ids:
        codigo, mensaje, headers = consultar_api(f"checklist/{chk_id}")
        logger.info(f"Checklist {chk_id} → {codigo} - {mensaje}")
        control_tasa_consumo(headers, logger)

    logger.info("--- Fin de descarga desde CloudFleet ---")
