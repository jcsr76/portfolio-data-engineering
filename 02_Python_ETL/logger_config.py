# logger_config.py

import logging
import os
from datetime import datetime


def configurar_logger(name):
    logger = logging.getLogger(name)
    if not logger.hasHandlers():
        logger.setLevel(logging.INFO)

        # Crear carpeta logs si no existe
        os.makedirs("logs", exist_ok=True)

        # Crear archivo por nombre + timestamp
        fecha_log = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = os.path.join("logs", f"{name}_logs_{fecha_log}.log")

        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        file_handler.setLevel(logging.INFO)

        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)

        formatter = logging.Formatter(
            "%(asctime)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger
