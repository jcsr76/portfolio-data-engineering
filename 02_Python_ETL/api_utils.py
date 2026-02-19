# api_utils.py

import json
import logging
import os
import re
import time
from datetime import datetime, timedelta

import requests
from dotenv import load_dotenv
from logger_config import configurar_logger


logger = configurar_logger("cloudfleet_main")


BASE_URL = "https://fleet.cloudfleet.com/api/v1/"

CODES = {
    200: "Petición exitosa",
    201: "Objeto creado exitosamente",
    204: "Operación completada sin respuesta",
    401: "No autorizado",
    403: "Acceso prohibido",
    404: "Recurso no encontrado",
    409: "Conflicto en los datos",
    415: "Error en el tipo de contenido",
    429: "Límite de peticiones excedido",
    500: "Error interno del servidor",
}


def safe_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def build_date_params(key_from, key_to, days_back):
    fecha_actual = datetime.utcnow()
    fecha_inicio = fecha_actual - timedelta(days=days_back)
    return {
        key_from: fecha_inicio.strftime("%Y-%m-%dT%H:%M:%SZ"),
        key_to: fecha_actual.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def get_params_for_endpoint(endpoint):
    import re

    # Si la URL ya tiene parámetros, no añadir más (para evitar error 409)
    if "?" in endpoint:
        return {}  # Ya hay parámetros, no intervenir

    if endpoint in ("checklist/", "checklist"):
        return build_date_params("checklistDateFrom", "checklistDateTo", days_back=30)

    if re.fullmatch(r"checklist/\d+", endpoint):
        return {}

    if endpoint == "work-orders/":
        # Limitar rango a 180 días exactos para evitar error 409
        return build_date_params("createdAtFrom", "createdAtTo", days_back=180)
    elif endpoint == "fuel-entries/":
        return build_date_params("createdAtFrom", "createdAtTo", days_back=180)
    elif endpoint == "availability":
        return build_date_params("dateFrom", "dateTo", days_back=30)
    elif endpoint == "maintenace-time":
        params = build_date_params("dateFrom", "dateTo", days_back=365)
        params["vehicleMeasureUnit"] = "hours"
        return params
    elif endpoint.startswith(("vendors", "people", "vehicles")) and re.fullmatch(
        r"\w+/\d+", endpoint
    ):
        return {}
    return {}


def consultar_api(endpoint):
    dotenv_path = os.path.join("cloudfleet", ".env")
    load_dotenv(dotenv_path=dotenv_path)
    API_KEY = os.getenv("API_KEY")
    if not API_KEY:
        logger.error("Error: No API Key en .env")
        return None, "Error: No API Key", {}

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json; charset=utf-8",
    }
    params = get_params_for_endpoint(endpoint)
    all_data = []
    next_url = BASE_URL + endpoint
    first = True

    while next_url:
        logger.info(f"Consultando: {next_url}")
        if first and params:
            logger.info(f"Parámetros: {params}")
        try:
            response = requests.get(
                next_url, headers=headers, params=params if first else None
            )
        except requests.exceptions.SSLError as e:
            logger.warning(f"Error SSL: {e}. Reintentando en 5s...")
            time.sleep(5)
            continue
        first = False

        code = response.status_code
        msg = CODES.get(code, "Código desconocido")
        rate = {
            "RateLimit-Limit": safe_int(response.headers.get("X-RateLimit-Limit")),
            "RateLimit-Remaining": safe_int(
                response.headers.get("X-RateLimit-Remaining")
            ),
            "RateLimit-Reset": safe_int(response.headers.get("X-RateLimit-Reset")),
        }

        logger.info(f"Respuesta: {code} - {msg}")
        logger.info(f"Rate: {rate}")

        if code == 429:
            retry_after = response.headers.get("Retry-After")
            reset = rate.get("RateLimit-Reset", 0)
            try:
                wait = (
                    int(retry_after)
                    if retry_after is not None
                    else (reset if reset > 0 else 60)
                )
            except (TypeError, ValueError):
                wait = reset if reset > 0 else 60
            wait += 3
            logger.warning(f"Límite excedido. Esperando {wait}s...")
            time.sleep(wait)
            continue

        if code == 404 and endpoint == "maintenace-time":
            err = ""
            try:
                err = response.json().get("error", {}).get("message", "")
            except Exception as e:
                logger.warning(f"No se pudo analizar el JSON de respuesta: {e}")
                err = ""

            if "No Vehicles found" in err:
                logger.warning("Sin datos de mantenimiento.")
                code, msg = 200, "Sin datos"
                break

        if code != 200:
            logger.error(f"Error {code}: {response.text}")
            return code, msg, rate

        try:
            data = response.json()
            all_data.extend(data if isinstance(data, list) else [data])
        except Exception as e:
            logger.error(f"JSON decode error: {e}")
            return code, msg, rate

        next_url = response.headers.get("X-NextPage")
        time.sleep(1)

    file_name = re.sub(r"[/?&=:]", "_", endpoint)
    path = os.path.join("informes_cloudfleet", f"{file_name}.json")
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(all_data, f, indent=4, ensure_ascii=False)
        logger.info(f"Guardado {path} ({len(all_data)} registros)")
    except Exception as e:
        logger.error(f"Error guardando archivo: {e}")

    return 200, "Petición exitosa (paginada)", rate
