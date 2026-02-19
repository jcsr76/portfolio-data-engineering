# liquidaciones_servicios_especiales.py

import time
import os
import re
import pandas as pd

from logger_config import configurar_logger
from utils_rutas import work_path

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import TimeoutException, NoSuchElementException

HOJA_EXCEL = "servicios especiales"

# --- NUEVO (manejo bug consecutivo duplicado) ---
XPATH_MSG_YA_REGISTRADO = (
    "//*[contains(translate(normalize-space(.),"
    "'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),"
    "'YA SE ENCUENTRA REGISTRADO')]"
)
XPATH_BTN_VERIFICAR = "//input[@type='button' and @value='Verificar']"
XPATH_BTN_ACEPTAR = "//input[@type='button' and @value='Aceptar']"


def guardar_html_error(nombre_archivo, driver, logger):
    try:
        error_file = work_path(f"debug/{nombre_archivo}")
        error_file.parent.mkdir(parents=True, exist_ok=True)
        with open(error_file, "w", encoding="utf-8") as f:
            f.write(driver.page_source)
        logger.info(f"HTML de error guardado en: {error_file}")
    except Exception:
        logger.warning("No se pudo guardar el HTML de error.")


def _es_valido(valor) -> bool:
    v = str(valor).strip()
    return bool(v) and v.lower() != "nan"


# --- NUEVO (helper para detección sin romper flujo) ---
def _exists(driver, by, sel) -> bool:
    try:
        driver.find_element(by, sel)
        return True
    except NoSuchElementException:
        return False


# --- NUEVO (recuperación automática del bug "YA SE ENCUENTRA REGISTRADO") ---
def manejar_consecutivo_duplicado_si_aparece(driver, wait, logger, timeout_backid=5) -> bool:
    """
    Maneja el caso en el que AVANSAT muestra el mensaje:
    "EL SERVICIO ESPECIAL XXXXX YA SE ENCUENTRA REGISTRADO, SE TOMA EL SIGUIENTE CONSECUTIVO."
    y deja disponibles nuevamente los botones Verificar y Aceptar.

    Estrategia:
      1) Espera backID por 'timeout_backid' segundos (si aparece, todo OK).
      2) Si no aparece, confirma el estado del error con:
         - texto "YA SE ENCUENTRA REGISTRADO" y/o
         - presencia de botones Verificar/Aceptar
      3) Ejecuta Verificar -> Aceptar -> aceptar alerta
      4) Verifica que backID quede disponible.
    """
    # Asegurar frame central
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    # 1) Si backID aparece rápido, no hay nada que recuperar
    try:
        WebDriverWait(driver, timeout_backid).until(EC.presence_of_element_located((By.ID, "backID")))
        return False
    except TimeoutException:
        pass

    # 2) Confirmar señales del duplicado (mismo frame)
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    hay_texto_dup = _exists(driver, By.XPATH, XPATH_MSG_YA_REGISTRADO)
    hay_verificar = _exists(driver, By.XPATH, XPATH_BTN_VERIFICAR)
    hay_aceptar = _exists(driver, By.XPATH, XPATH_BTN_ACEPTAR)

    if not (hay_texto_dup or (hay_verificar and hay_aceptar)):
        logger.warning("No apareció backID en 5s, pero no se confirma 'YA SE ENCUENTRA REGISTRADO'.")
        return False

    logger.warning("Detectado caso 'YA SE ENCUENTRA REGISTRADO'. Intentando recuperación automática...")

    # 3) Recuperación
    btn_verificar = wait.until(EC.element_to_be_clickable((By.XPATH, XPATH_BTN_VERIFICAR)))
    btn_verificar.click()
    time.sleep(0.3)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    btn_aceptar = wait.until(EC.element_to_be_clickable((By.XPATH, XPATH_BTN_ACEPTAR)))
    btn_aceptar.click()
    time.sleep(0.5)

    aceptar_alerta_si_aparece(driver, logger, timeout=8)

    # 4) Confirmar que ya quedó disponible backID
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.ID, "backID")))

    logger.info("Recuperación aplicada: backID disponible nuevamente.")
    return True


def aceptar_alerta_si_aparece(driver, logger, timeout=8):
    """
    Acepta una alerta JS (confirm/alert) si aparece.
    """
    try:
        alert = WebDriverWait(driver, timeout).until(EC.alert_is_present())
        logger.info(f"Alerta detectada: {alert.text}")
        alert.accept()
        time.sleep(1)
        return True
    except TimeoutException:
        return False


def asegurar_modo_empresarial(driver, wait, logger):
    """
    En Insertar, fuerza el radio:
      <input type="radio" name="tipo" value="E" onclick="form_orden.submit()">
    y espera el listado (DLFilter0).
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    radio_tipo_e = wait.until(
        EC.element_to_be_clickable((By.XPATH, "//input[@type='radio' and @name='tipo' and @value='E']"))
    )
    radio_tipo_e.click()
    time.sleep(1)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.ID, "DLFilter0")))

    logger.info("Modo Empresarial (tipo=E) listo; listado disponible (DLFilter0).")


def filtrar_y_seleccionar_remesa(driver, wait, logger, remesa: str):
    """
    1) Escribe remesa en DLFilter0
    2) ENTER
    3) clic DLLink0-0
    4) espera que cargue formulario (label Origen)
    """
    remesa = str(remesa).strip()
    if not _es_valido(remesa):
        raise ValueError("Remesa vacía/NaN, no se puede filtrar.")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    filtro = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter0")))
    filtro.click()
    time.sleep(0.2)
    filtro.send_keys(Keys.CONTROL + "a")
    filtro.send_keys(Keys.DELETE)
    time.sleep(0.2)

    logger.info(f"Filtrando por remesa en DLFilter0: {remesa}")
    filtro.send_keys(remesa)
    filtro.send_keys(Keys.TAB)
    time.sleep(1)

    link_primero = wait.until(EC.element_to_be_clickable((By.ID, "DLLink0-0")))
    texto_link = link_primero.text.strip()
    logger.info(f"Primer resultado (DLLink0-0): {texto_link}")

    if texto_link != remesa:
        logger.warning(f"⚠️ El link no coincide con la remesa objetivo. Esperado={remesa} | Visto={texto_link}")

    logger.info("Clic en hipervínculo DLLink0-0...")
    link_primero.click()

    wait.until(EC.presence_of_element_located((By.XPATH, "//b[normalize-space()='Origen']")))


def seleccionar_origen_desde_formulario(driver, wait, logger):
    """
    Lee ciudad Origen del formulario (celda junto al label Origen) y la selecciona en <select name="origen">
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    origen_td = wait.until(
        EC.visibility_of_element_located(
            (
                By.XPATH,
                "//b[normalize-space()='Origen']/ancestor::td[contains(@class,'etiqueta')]/"
                "following-sibling::td[contains(@class,'celda')][1]",
            )
        )
    )
    ciudad_origen = origen_td.text.strip()
    logger.info(f"Ciudad origen detectada en formulario: {ciudad_origen}")

    if not ciudad_origen:
        raise ValueError("No se pudo leer la ciudad Origen (celda vacía).")

    combo = wait.until(EC.element_to_be_clickable((By.NAME, "origen")))
    Select(combo).select_by_visible_text(ciudad_origen)
    time.sleep(0.5)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.element_to_be_clickable((By.NAME, "origen")))

    logger.info(f"Origen seleccionado en combo: {ciudad_origen}")
    return ciudad_origen


def aplicar_servicio_apoyo_operativo(driver, wait, logger, valor_pxq: str):
    """
    - Click checkbox: name="asigna[0]" value="58"
    - Input: name="valuniven[0]" = valor_pxq
    - Click Verificar, luego Aceptar
    - Aceptar alerta JS si aparece
    """
    if valor_pxq is None:
        raise ValueError("valor_pxq viene None")
    valor_pxq = str(valor_pxq).strip()
    if not _es_valido(valor_pxq):
        raise ValueError("valor_pxq vacío/NaN")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    chk = wait.until(EC.element_to_be_clickable((By.NAME, "asigna[0]")))
    if not chk.is_selected():
        chk.click()
    time.sleep(0.3)

    inp = wait.until(EC.element_to_be_clickable((By.NAME, "valuniven[0]")))
    inp.click()
    inp.send_keys(Keys.CONTROL + "a")
    inp.send_keys(Keys.DELETE)
    inp.send_keys(valor_pxq)
    time.sleep(0.3)

    btn_verificar = wait.until(
        EC.element_to_be_clickable((By.XPATH, "//input[@type='button' and @value='Verificar']"))
    )
    btn_verificar.click()

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.XPATH, "//input[@type='button' and @value='Aceptar']")))

    btn_aceptar = wait.until(EC.element_to_be_clickable((By.XPATH, "//input[@type='button' and @value='Aceptar']")))
    btn_aceptar.click()
    time.sleep(0.5)

    aceptar_alerta_si_aparece(driver, logger, timeout=8)

    # --- NUEVO (si backID no aparece en 5s, intentar recuperación del consecutivo duplicado) ---
    manejar_consecutivo_duplicado_si_aparece(driver, wait, logger, timeout_backid=5)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    logger.info(f"Servicio apoyo operativo aplicado con valor PXQ: {valor_pxq}")


def click_insertar_otro_servicio(driver, wait, logger):
    """
    Click en backID y deja el sistema listo para la siguiente remesa:
    vuelve a pantalla Insertar y fuerza tipo=E para que aparezca DLFilter0.
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    btn_back = wait.until(EC.element_to_be_clickable((By.ID, "backID")))
    logger.info("Clic en 'Insertar Otro Servicio Especial' (backID)...")
    btn_back.click()
    time.sleep(1)

    asegurar_modo_empresarial(driver, wait, logger)


def procesar_servicios_especiales(driver, wait, excel_path: str, logger=None, progress_cb=None):
    """
    Procesa Servicios Especiales (remesas) en AVANSAT.

    Parámetros:
        driver: instancia de Selenium WebDriver ya autenticada en AVANSAT.
        wait:   instancia de WebDriverWait asociada al driver.
        excel_path: ruta completa al archivo Excel seleccionado por el usuario.
        logger: logger central (un solo run.log para toda la corrida).
        progress_cb: callback opcional progress_cb(done:int, total:int, etapa:str)
    """
    if logger is None:
        logger = configurar_logger("run", str(work_path("logs/run.log")))

    if not excel_path or not os.path.exists(excel_path):
        logger.error(f"No se encuentra el archivo Excel: {excel_path}")
        return

    try:
        df = pd.read_excel(excel_path, sheet_name=HOJA_EXCEL, dtype=str)
        df.columns = df.columns.str.strip()

        if df.empty:
            logger.warning("Hoja 'servicios especiales' sin registros; no se procesará nada.")
            return

    except Exception as e:
        logger.error(f"Error leyendo Excel de Servicios Especiales: {e}")
        return

    if "Remesa" not in df.columns:
        logger.error("La hoja 'servicios especiales' no tiene la columna requerida: 'Remesa'.")
        return

    total = int(df["Remesa"].apply(_es_valido).sum())
    done = 0
    if progress_cb:
        progress_cb(done, total, "Listo para procesar servicios especiales")

    try:
        logger.info("Navegando a Servicios Especiales > Insertar...")

        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))

        wait.until(EC.element_to_be_clickable((By.ID, "411ID"))).click()
        time.sleep(0.5)
        wait.until(EC.element_to_be_clickable((By.ID, "720ID"))).click()
        time.sleep(1)

        asegurar_modo_empresarial(driver, wait, logger)

        for index, row in df.iterrows():
            remesa = str(row.get("Remesa", "")).strip()
            if not _es_valido(remesa):
                logger.warning(f"Fila {index + 1}: Remesa vacía. Saltando.")
                continue

            done += 1
            if progress_cb:
                progress_cb(done, total, f"Procesando Remesa {remesa}")

            raw_pxq = str(row.get("Suma de Reserva 90%   PXQ", "0")).strip()
            raw_pxq = raw_pxq.replace(",", "")

            try:
                val_int = int(round(float(raw_pxq)))
                valor_pxq = str(val_int)
            except Exception:
                valor_pxq = str(row.get("Suma de Reserva 90%   PXQ", "")).strip()

            logger.info(f"--- Procesando fila {index + 1} | Remesa Excel: {remesa} ---")

            try:
                asegurar_modo_empresarial(driver, wait, logger)

                filtrar_y_seleccionar_remesa(driver, wait, logger, remesa)
                seleccionar_origen_desde_formulario(driver, wait, logger)
                aplicar_servicio_apoyo_operativo(driver, wait, logger, valor_pxq)
                click_insertar_otro_servicio(driver, wait, logger)

            except Exception as e_row:
                logger.error(f"Error procesando fila {index}: {e_row}")
                guardar_html_error(f"error_serv_esp_{index + 1}.html", driver, logger)

    finally:
        logger.info("Finalizando módulo de Servicios Especiales (driver se mantiene para otros procesos).")
