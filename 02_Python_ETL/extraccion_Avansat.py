# extraccion_Avansat.py

import os
import time
from datetime import datetime, timedelta

from avansat_login import login_avansat
from descargas_utils import esperar_descarga
from logger_config import configurar_logger
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from utils_rutas import resource_path

# Definir rutas absolutas para cada informe
ruta_operacion_nacional = resource_path("operacion_nacional")
ruta_operacion_nacional.mkdir(exist_ok=True)

ruta_informe_remesas = resource_path("informe_remesas")
ruta_informe_remesas.mkdir(exist_ok=True)

ruta_vehiculos_terceros = resource_path("vehiculos_terceros")
ruta_vehiculos_terceros.mkdir(exist_ok=True)

ruta_conductores_terceros = resource_path("conductores_terceros")
ruta_conductores_terceros.mkdir(exist_ok=True)


# ── Función para guardar HTML de error ──────────────────────────────────────
def guardar_html_error(nombre_archivo, driver, logger):
    try:
        error_file = resource_path(f"debug/{nombre_archivo}")
        error_file.parent.mkdir(parents=True, exist_ok=True)
        with open(error_file, "w", encoding="utf-8") as f:
            f.write(driver.page_source)
        logger.info(f"HTML de error guardado en: {error_file}")
    except Exception:
        logger.warning("No se pudo guardar el HTML de error.")


def descargar_informes_avansat(logger=None):
    if logger is None:
        logger = configurar_logger("log_AVANSAT")

    op_nacional_exitosa = False

    fecha_year = (datetime.today() - timedelta(days=183)).strftime("%Y-%m-%d")
    fecha_manana = datetime.today().strftime("%Y-%m-%d")

    # ============ INFORME: OPERACIÓN NACIONAL ============
    ruta_op = str(ruta_operacion_nacional)
    driver, wait = login_avansat(ruta_op)

    try:
        logger.info("Accediendo a informe 'Operación Nacional'...")
        driver.switch_to.default_content()
        logger.info("Seleccionando el Frame de Menú'...")
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))
        logger.info("Seleccionando Sección de Informes'...")
        wait.until(EC.element_to_be_clickable((By.ID, "433ID"))).click()
        time.sleep(1)
        logger.info("Seleccionando informe 'Operación Nacional'...")
        wait.until(EC.element_to_be_clickable((By.ID, "23ID"))).click()
        time.sleep(2)

        driver.switch_to.default_content()
        logger.info("Seleccionando el Frame Central'...")
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

        logger.info("Configurando informe 'Operación Nacional'...")
        logger.info("Seleccionando 'Todos'...")
        wait.until(EC.element_to_be_clickable((By.ID, "todosID"))).click()
        time.sleep(2)

        logger.info("Ingresando 'Fecha Inicial'...")
        wait.until(EC.presence_of_element_located((By.ID, "fec_iniciaID"))).send_keys(fecha_year)
        time.sleep(2)
        logger.info("Ingresando 'Fecha Final'...")
        wait.until(EC.presence_of_element_located((By.ID, "fec_finaliID"))).send_keys(fecha_manana)
        time.sleep(2)
        logger.info("Clic en Botón 'Aceptar'...")
        wait.until(EC.element_to_be_clickable((By.ID, "BTAceptarID"))).click()

        logger.info("Esperando Icono de descarga de Reporte en HTML...")
        icono_html = WebDriverWait(driver, 500).until(
            EC.element_to_be_clickable((By.XPATH, "//img[contains(@onclick, \"generateReport('html')\")]"))
        )

        logger.info("Eliminando archivos de la carpeta de descarga de Operación Nal....")
        for archivo in os.listdir(ruta_op):
            ruta = os.path.join(ruta_op, archivo)
            if os.path.isfile(ruta):
                os.remove(ruta)

        logger.info("Clic en Icono de descarga de Reporte en HTML...")
        icono_html.click()
        inicio_descarga_op_nal = datetime.now()

        archivo_descargado = esperar_descarga(ruta_op, extension=".html", timeout=600)

        logger.info(f"✅ Descarga completada (Operación Nacional): {archivo_descargado}")
        op_nacional_exitosa = True

        fin_descarga_op_nal = datetime.now()
        duracion_descarga_op_nal = (fin_descarga_op_nal - inicio_descarga_op_nal).total_seconds()
        logger.info(f"⏱ Duración de la descarga: {duracion_descarga_op_nal:.2f} segundos.")

    except Exception as e:
        logger.error(f"Error en descarga de Operación Nacional: {e}")
        guardar_html_error("error_page_operacion_nacional.html", driver, logger)
    finally:
        driver.quit()
        logger.info("Navegador cerrado (Operación Nacional)")

    # ============ INFORME: REMESAS ============
    ruta_rem = str(ruta_informe_remesas)
    driver, wait = login_avansat(ruta_rem)

    try:
        logger.info("Accediendo a 'Informe de Remesas'...")
        driver.switch_to.default_content()
        logger.info("Seleccionando el Frame de Menú'...")
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))
        logger.info("Seleccionando Sección de Informes'...")
        wait.until(EC.element_to_be_clickable((By.ID, "433ID"))).click()
        time.sleep(1)
        logger.info("Seleccionando informe 'Informe Remesas'...")
        wait.until(EC.element_to_be_clickable((By.ID, "20ID"))).click()
        time.sleep(2)

        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

        logger.info("Configurando informe 'Remesas'...")
        wait.until(
            EC.element_to_be_clickable(
                (By.CSS_SELECTOR, "input[type='radio'][name='filtro'][value='0']")
            )
        ).click()
        time.sleep(1)

        logger.info("Limpiando campo e Ingresando 'Fecha Inicial'...")
        campo_ini = wait.until(EC.presence_of_element_located((By.ID, "fecha_inicial")))
        campo_ini.clear()
        for parte in fecha_year.split("-"):
            campo_ini.send_keys(parte)
            time.sleep(1)

        logger.info("Limpiando campo e Ingresando 'Fecha Final'...")
        campo_fin = wait.until(EC.presence_of_element_located((By.ID, "fecha_final2")))
        campo_fin.clear()
        for parte in fecha_manana.split("-"):
            campo_fin.send_keys(parte)
            time.sleep(1)

        logger.info("Esperando Botón 'Enviar'...")
        wait.until(
            EC.element_to_be_clickable(
                (By.XPATH, "//input[@class='button_enviar' and @value='Aceptar']")
            )
        ).click()
        logger.info("Clic en Botón 'Enviar'...")

        for archivo in os.listdir(ruta_rem):
            ruta = os.path.join(ruta_rem, archivo)
            if os.path.isfile(ruta):
                os.remove(ruta)

        logger.info("Eliminando archivos de la carpeta de descarga de Informe Remesas....")

        time.sleep(10)
        wait.until(
            EC.element_to_be_clickable(
                (By.XPATH, "//img[@src='images/botone/exportar.gif']")
            )
        ).click()
        logger.info("Clic en Icono de descarga de Reporte Informe Remesas Excel...")
        inicio_descarga_inf_remesas = datetime.now()

        archivo_descargado = esperar_descarga(ruta_rem, extension=".xls", timeout=600)
        logger.info(f"✅ Descarga completada (Informe de Remesas): {archivo_descargado}")

        fin_descarga_inf_remesas = datetime.now()
        duracion_descarga_inf_remesas = (fin_descarga_inf_remesas - inicio_descarga_inf_remesas).total_seconds()
        logger.info(f"⏱ Duración de la descarga: {duracion_descarga_inf_remesas:.2f} segundos.")

    except Exception as e:
        logger.error(f"Error en descarga de Informe de Remesas: {e}")
        guardar_html_error("error_page_informe_remesas.html", driver, logger)
    finally:
        driver.quit()
        logger.info("Navegador cerrado (Informe de Remesas)")

    # ============ INFORME: VEHÍCULOS/CONDUCTORES AVANSAT ============
    ruta_op = str(ruta_vehiculos_terceros)
    driver, wait = login_avansat(ruta_op)

    try:
        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))

        logger.info("Recursos ➜ Vehiculos ➜ Listar")
        wait.until(EC.element_to_be_clickable((By.ID, "385ID"))).click()  # Recursos
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "715ID"))).click()  # Vehiculos
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "131ID"))).click()  # Listar

        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

        wait.until(EC.element_to_be_clickable((By.ID, "buscarID"))).click()
        wait.until(
            EC.element_to_be_clickable(
                (By.XPATH, "//div[contains(@class,'sweet-alert') and contains(@class,'visible')]//button[text()='Si']")
            )
        ).click()

        logger.info("Limpiando archivos previos en carpeta de descarga…")
        for archivo in os.listdir(ruta_op):
            ruta_abs = os.path.join(ruta_op, archivo)
            if os.path.isfile(ruta_abs):
                os.remove(ruta_abs)

        logger.info("Esperando botón Exportar a Excel…")
        wait.until(EC.element_to_be_clickable((By.ID, "btn_exportID"))).click()

        inicio = datetime.now()
        archivo_xls = esperar_descarga(ruta_op, extension=".xls", timeout=600)
        fin = datetime.now()

        logger.info(f"✅ Descarga completada: {archivo_xls} ({(fin - inicio).total_seconds():.2f}s)")

    except Exception as e:
        logger.error(f"Error durante la descarga de vehiculos_terceros: {e}")
        guardar_html_error("error_page_vehiculos_terceros.html", driver, logger)
    finally:
        driver.quit()
        logger.info("Navegador cerrado (Vehículos Terceros)")

    # ============ INFORME: CONDUCTORES TERCEROS ============
    ruta_op = str(ruta_conductores_terceros)
    driver, wait = login_avansat(ruta_op)

    try:
        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))

        wait.until(EC.element_to_be_clickable((By.ID, "385ID"))).click()  # Recursos
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "705ID"))).click()  # Terceros
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "700ID"))).click()  # Conductores
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "17ID"))).click()  # Listar

        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

        wait.until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, "input[type='submit'][name='Buscar']"))
        ).click()

        logger.info("Limpiando carpeta conductores_terceros…")
        for f in os.listdir(ruta_op):
            fp = os.path.join(ruta_op, f)
            if os.path.isfile(fp):
                os.remove(fp)

        logger.info("Esperando botón Exportar (exportar.gif)…")
        wait.until(
            EC.element_to_be_clickable((By.XPATH, "//img[contains(@src,'exportar.gif')]"))
        ).click()

        inicio = datetime.now()
        archivo = esperar_descarga(ruta_op, extension=".xls", timeout=600)
        fin = datetime.now()

        logger.info(f"✅ Descarga completada: {archivo} ({(fin - inicio).total_seconds():.2f}s)")

    except Exception as e:
        logger.error(f"Error en descarga Conductores: {e}")
        guardar_html_error("error_page_conductores_terceros.html", driver, logger)
    finally:
        driver.quit()
        logger.info("Navegador cerrado (Conductores Terceros)")

    return op_nacional_exitosa