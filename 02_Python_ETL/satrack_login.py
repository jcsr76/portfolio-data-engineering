import os

from dotenv import load_dotenv
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def login_satrack(flota, ruta_descarga):
    # Cargar variables de entorno desde scripts/satrack/.env
    dotenv_path = os.path.join(os.path.dirname(__file__), "satrack", ".env")
    load_dotenv(dotenv_path)

    # Seleccionar credenciales según el tipo de flota
    if flota.lower() == "propia":
        usuario = os.getenv("SATRACK_USER")
        clave = os.getenv("SATRACK_PASSWORD")
    elif flota.lower() == "tercera":
        usuario = os.getenv("SATRACK_USER_2")
        clave = os.getenv("SATRACK_PASSWORD_2")
    else:
        raise ValueError("El valor de 'flota' debe ser 'propia' o 'tercera'")

    # Configurar navegador
    options = webdriver.ChromeOptions()
    prefs = {
        "download.default_directory": ruta_descarga,
        "download.prompt_for_download": False,
        "directory_upgrade": True,
        "safebrowsing.enabled": True,
    }
    options.add_experimental_option("prefs", prefs)
    options.add_argument("--start-maximized")

    driver = webdriver.Chrome(options=options)
    wait = WebDriverWait(driver, 20)

    try:
        print("Abriendo SATRACK...")
        driver.get("https://login.satrack.com/login")
        wait.until(EC.presence_of_element_located((By.TAG_NAME, "body")))

        print("Esperando campos de login...")
        campo_usuario = wait.until(
            EC.presence_of_element_located((By.ID, "txt_login_username"))
        )
        campo_clave = wait.until(
            EC.presence_of_element_located((By.ID, "txt_login_password"))
        )

        print("Escribiendo credenciales desde .env...")
        campo_usuario.send_keys(usuario)
        campo_clave.send_keys(clave)

        print("Haciendo clic en Iniciar sesión...")
        boton_login = wait.until(
            EC.element_to_be_clickable(
                (By.XPATH, "//a[contains(text(), 'Iniciar sesión')]")
            )
        )
        boton_login.click()

        print("Login exitoso.")
        return driver, wait

    except Exception as e:
        print(f"Error en login: {e}")
        try:
            with open("error_login.html", "w", encoding="utf-8") as f:
                f.write(driver.page_source)
        except Exception as write_error:
            print(f"No se pudo guardar el HTML del error: {write_error}")
        driver.quit()
        raise
