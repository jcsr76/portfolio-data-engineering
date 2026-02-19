# avansat_login.py
import os
from subprocess import CREATE_NO_WINDOW

from logger_config import configurar_logger
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from utils_rutas import work_path


def login_avansat(ruta_descarga: str, usuario: str, clave: str, logger=None, ver_navegador: bool = False):
    """
    Abre sesión en AVANSAT y devuelve (driver, wait).

    ver_navegador:
        - False: headless (no se ve Chrome)
        - True : se ve la ventana de Chrome (útil para depurar)
    """

    if logger is None:
        log_file = str(work_path("logs/run.log"))
        logger = configurar_logger("run", log_file)

    chrome_opts = Options()
    prefs = {
        "download.default_directory": ruta_descarga,
        "download.prompt_for_download": False,
        "directory_upgrade": True,
        "safebrowsing.enabled": True,
    }
    chrome_opts.add_experimental_option("prefs", prefs)

    # Solo headless si NO se quiere ver el navegador
    if not ver_navegador:
        chrome_opts.add_argument("--headless=new")  # modo headless moderno en Chromium [web:226]

    chrome_opts.add_argument("--disable-gpu")
    chrome_opts.add_argument("--window-size=1920,1080")
    chrome_opts.add_argument("--no-sandbox")
    chrome_opts.add_experimental_option("excludeSwitches", ["enable-logging"])

    service = Service(
        creationflags=CREATE_NO_WINDOW,
        log_path=os.devnull
    )

    driver = webdriver.Chrome(service=service, options=chrome_opts)
    wait = WebDriverWait(driver, 20)

    try:
        logger.info("Abriendo AVANSAT…")
        driver.get("https://oet-avansat2.intrared.net:8083/ap/sate_corpyp/session.php")

        wait.until(EC.presence_of_element_located((By.TAG_NAME, "body"))).send_keys("\n")

        logger.info("Esperando campos de login…")
        usuario_input = wait.until(EC.presence_of_element_located((By.ID, "usuario")))
        clave_input = wait.until(EC.presence_of_element_located((By.ID, "clave")))

        logger.info("Escribiendo credenciales…")
        usuario_input.send_keys(usuario)
        clave_input.send_keys(clave)

        logger.info("Haciendo clic en Ingresar…")
        wait.until(EC.element_to_be_clickable((By.ID, "login-button"))).click()

        logger.info("Login exitoso.")
        return driver, wait

    except Exception as e:
        logger.error(f"Error en login: {e}")

        debug_dir = work_path("debug")
        debug_dir.mkdir(parents=True, exist_ok=True)
        try:
            with open(debug_dir / "error_login.html", "w", encoding="utf-8") as f:
                f.write(driver.page_source)
        except Exception:
            logger.warning("No se pudo guardar el HTML de error de login.")

        driver.quit()
        raise
