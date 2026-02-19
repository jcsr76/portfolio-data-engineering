# logger_config.py
import logging
from pathlib import Path


def configurar_logger(name: str, log_file: str, also_console: bool = True) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    # Quitar SOLO handlers que nosotros agregamos antes (no tocar handlers externos/GUI).
    for h in list(logger.handlers):
        if getattr(h, "_avansat_owned", False):
            try:
                h.close()
            except Exception:
                pass
            logger.removeHandler(h)

    Path(log_file).parent.mkdir(parents=True, exist_ok=True)

    formatter = logging.Formatter("%(asctime)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S")

    file_handler = logging.FileHandler(log_file, encoding="utf-8", mode="w")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)
    file_handler._avansat_owned = True  # marca propia
    logger.addHandler(file_handler)

    if also_console:
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)
        console_handler._avansat_owned = True  # marca propia
        logger.addHandler(console_handler)

    # Evita que se duplique por propagación al root logger
    logger.propagate = False

    return logger
