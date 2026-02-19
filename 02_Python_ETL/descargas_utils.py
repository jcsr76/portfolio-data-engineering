# descargas_utils.py

import os
import time

from logger_config import (
    configurar_logger,
)  # Importar la función para configurar logger


def esperar_descarga(directorio, extension=".csv", timeout=600):
    """
    Espera a que un archivo con la extensión especificada aparezca en el directorio dado
    y que no tenga extensión .crdownload (indicando que la descarga está incompleta).
    """

    # Usar el logger configurado
    logger = configurar_logger(
        "log_AVANSAT"
    )  # Llamamos la configuración común del logger

    logger.info(f"Esperando archivo con extensión {extension} en {directorio}...")
    tiempo_inicio = time.time()

    while time.time() - tiempo_inicio < timeout:
        archivos = os.listdir(directorio)
        archivos_filtrados = [
            f
            for f in archivos
            if f.endswith(extension) and not f.endswith(".crdownload")
        ]
        if archivos_filtrados:
            logger.info(f"Archivo detectado: {archivos_filtrados[0]}")
            return os.path.join(directorio, archivos_filtrados[0])
        time.sleep(1)

    # Si no se encuentra el archivo después del tiempo de espera
    logger.error(
        f"No se encontró ningún archivo {extension} en {directorio} tras {timeout} segundos."
    )
    raise TimeoutError(
        f"No se encontró ningún archivo {extension} en {directorio} tras {timeout} segundos."
    )
