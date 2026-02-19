# avansat_login.py
import os
from dotenv import load_dotenv
from logger_config import configurar_logger
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from subprocess import CREATE_NO_WINDOW
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from utils_rutas import resource_path



# ==== Función principal de login ====
def login_avansat(ruta_descarga: str):
    """Abre sesión en AVANSAT y devuelve (driver, wait)."""

    # 1-a) Credenciales usando resource_path()
    dotenv_path = resource_path("avansat/.env")
    load_dotenv(dotenv_path)
    usuario = os.getenv("AVANSAT_USER")
    clave   = os.getenv("AVANSAT_PASS")

    # 1-b) Opciones de Chrome
    chrome_opts = Options()
    prefs = {
        "download.default_directory": ruta_descarga,
        "download.prompt_for_download": False,
        "directory_upgrade": True,
        "safebrowsing.enabled": True,
    }
    chrome_opts.add_experimental_option("prefs", prefs)
    chrome_opts.add_argument("--headless=new")  # Línea a comentar para desactivar modo HEADLESS
    chrome_opts.add_argument("--disable-gpu")
    chrome_opts.add_argument("--window-size=1920,1080")
    chrome_opts.add_argument("--no-sandbox")
    chrome_opts.add_experimental_option("excludeSwitches", ["enable-logging"])

    # 1-c) Servicio ChromeDriver SIN consola
    service = Service(
        creationflags=CREATE_NO_WINDOW,
        log_path=os.devnull  # oculta los logs de chromedriver
    )

    # 1-d) Crear WebDriver completamente silencioso
    driver = webdriver.Chrome(service=service, options=chrome_opts)
    wait   = WebDriverWait(driver, 20)

    # 1-e) Logger propio
    logger = configurar_logger("log_AVANSAT")

    # ==== 2. Flujo de login ====
    try:
        logger.info("Abriendo AVANSAT…")
        driver.get("https://oet-avansat2.intrared.net:8083/ap/sate_corpyp/session.php")
        wait.until(EC.presence_of_element_located((By.TAG_NAME, "body"))).send_keys("\n")

        logger.info("Esperando campos de login…")
        usuario_input = wait.until(EC.presence_of_element_located((By.ID, "usuario")))
        clave_input   = wait.until(EC.presence_of_element_located((By.ID, "clave")))

        logger.info("Escribiendo credenciales…")
        usuario_input.send_keys(usuario)
        clave_input.send_keys(clave)

        logger.info("Haciendo clic en Ingresar…")
        wait.until(EC.element_to_be_clickable((By.ID, "login-button"))).click()

        logger.info("Login exitoso.")
        return driver, wait


    except Exception as e:

        logger.error(f"Error en login: {e}")

        # Guardar HTML para diagnóstico en la carpeta "debug" junto al .exe

        debug_dir = resource_path("debug")
        debug_dir.mkdir(parents=True, exist_ok=True)
        with open(debug_dir / "error_login.html", "w", encoding="utf-8") as f:
            f.write(driver.page_source)

        driver.quit()

        raise

