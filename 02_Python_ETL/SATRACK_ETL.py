# SATRACK_ETL.py

import logging
import os
import sys
import time
from datetime import datetime

from descargas_utils import esperar_descarga
from satrack_login import login_satrack
from selenium import webdriver
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

# Crear carpeta logs si no existe
os.makedirs("logs", exist_ok=True)

# Crear nombre de archivo log con fecha y hora
nombre_log = (
    f"log_SATRACK_flota_propia_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.txt"
)
ruta_log = os.path.join("logs", nombre_log)


# DualLogger para registrar en consola y archivo
class DualLogger:
    def __init__(self, ruta_archivo):
        self.terminal = sys.stdout
        self.log = open(ruta_archivo, "a", encoding="utf-8")
        self.buffer = ""

    def write(self, mensaje):
        self.buffer += mensaje
        while "\n" in self.buffer:
            linea, self.buffer = self.buffer.split("\n", 1)
            if linea.strip():
                timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S] ")
                linea = timestamp + linea
            self.terminal.write(linea + "\n")
            self.log.write(linea + "\n")

    def flush(self):
        self.terminal.flush()
        self.log.flush()


# Configurar logger
sys.stdout = DualLogger(ruta_log)
sys.stderr = sys.stdout

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger()

# Rutas descargas
ruta_descarga_vehiculos_propios = os.path.join(os.getcwd(), "vehiculos_propios")
ruta_descarga_vehiculos_terceros = os.path.join(os.getcwd(), "vehiculos_terceros")

try:
    driver, wait = login_satrack("propia", ruta_descarga_vehiculos_propios)

    logger.info("Esperando que 'Informes' esté disponible...")
    informe_tab = wait.until(
        EC.element_to_be_clickable((By.ID, "tab_nav_menu_Reports"))
    )
    logger.info("Haciendo clic en Informes...")
    informe_tab.click()
    time.sleep(2)

    logger.info("Esperando que reporte 'Distancia uso y velocidad' esté disponible...")
    reporte_distancia = wait.until(
        EC.element_to_be_clickable(
            (By.XPATH, "//span[contains(text(), 'Distancia uso y velocidad')]")
        )
    )
    logger.info("Haciendo clic en Distancia uso y velocidad")
    reporte_distancia.click()
    time.sleep(2)

    try:
        logger.info("Buscando alertas o ventanas emergentes")
        alert = WebDriverWait(driver, 10).until(EC.alert_is_present())
        alert.accept()
    except TimeoutException:
        logger.info("No se encontró una alerta.")

    logger.info("Esperando campo 'Elige un vehículo'...")
    campo_vehiculo = wait.until(
        EC.element_to_be_clickable((By.ID, "mnu_filter_vehicles"))
    )
    logger.info("Haciendo clic en Elige un vehículo")
    campo_vehiculo.click()

    logger.info("Esperando selección 'Todos los vehículos'...")
    todos_vehiculos = wait.until(
        EC.element_to_be_clickable(
            (By.XPATH, "//span[contains(text(), 'Todos los vehículos')]")
        )
    )
    logger.info("Haciendo clic en Todos los vehículos")
    todos_vehiculos.click()

    logger.info("Cerrando selector de vehículos...")
    fondo_overlay = wait.until(
        EC.presence_of_element_located((By.CLASS_NAME, "cdk-overlay-container"))
    )
    webdriver.ActionChains(driver).move_to_element_with_offset(
        fondo_overlay, 5, 5
    ).click().perform()

    logger.info("Seleccionando campo de fecha...")
    campo_fecha = wait.until(EC.element_to_be_clickable((By.ID, "mnu_filter_date")))
    campo_fecha.click()

    logger.info("Esperando opción 'Ayer'...")
    ayer_option = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.ID, "opt_filter_calendar_yesterday"))
    )
    logger.info("Haciendo clic en Ayer")
    ayer_option.click()

    logger.info("Esperando botón 'Generar informe'...")
    boton_generar = wait.until(
        EC.element_to_be_clickable((By.ID, "btn_filter_generate"))
    )
    logger.info("Haciendo clic en GENERAR INFORME")
    boton_generar.click()

    # Limpiar archivos anteriores
    logger.info("Limpiando archivos anteriores en la carpeta de descarga...")
    try:
        for archivo in os.listdir(ruta_descarga_vehiculos_propios):
            ruta_archivo = os.path.join(ruta_descarga_vehiculos_propios, archivo)
            if os.path.isfile(ruta_archivo):
                os.remove(ruta_archivo)
    except Exception as e:
        logger.error(f"⚠️ Error al eliminar archivos anteriores: {e}")

    max_intentos = 3
    espera_entre_intentos = 10  # segundos
    exito = False

    logger.info("Intentando encontrar y hacer clic en el botón de Descargar...")

    for intento in range(1, max_intentos + 1):
        logger.info(f"🔄 Intento {intento} de {max_intentos}...")
        try:
            btn_descarga = WebDriverWait(driver, espera_entre_intentos).until(
                EC.element_to_be_clickable((By.ID, "btn_behavior_export"))
            )
            logger.info("✅ Botón encontrado.")
            time.sleep(10)
            logger.info("✅   Haciendo clic en DESCARGAR INFORME")
            btn_descarga.click()
            exito = True
            break
        except TimeoutException:
            logger.warning(
                f"⚠️ El botón no estuvo disponible en el intento {intento}. Reintentando..."
            )

    if not exito:
        logger.error(
            "❌ No se pudo encontrar el botón de Descargar después de varios intentos."
        )
        driver.save_screenshot("error_btn_descargar.png")
        raise TimeoutException(
            "No se encontró el botón de Descargar tras múltiples intentos."
        )

    logger.info("Esperando que la descarga termine...")
    time.sleep(10)
    archivo_descargado = esperar_descarga(
        ruta_descarga_vehiculos_propios, extension=".xlsx", timeout=120
    )
    logger.info(f"✅ Archivo descargado: {archivo_descargado}")

except TimeoutException as e:
    logger.error(f"❌ Error de tiempo de espera: {e}")
    driver.save_screenshot("error_timeout.png")
except WebDriverException as e:
    logger.error(f"❌ Error del navegador: {e}")
    driver.save_screenshot("error_navegador.png")
except Exception as e:
    logger.error(f"❌ Error inesperado: {e}")
    driver.save_screenshot("error_general.png")
finally:
    logger.info("Cerrando navegador...")
    try:
        driver.quit()
    except Exception:
        pass
