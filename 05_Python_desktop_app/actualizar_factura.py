# actualizar_factura.py
import time
import os
import re
import pandas as pd

from logger_config import configurar_logger
from utils_rutas import work_path

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import Select, WebDriverWait
from selenium.common.exceptions import TimeoutException, ElementClickInterceptedException, NoSuchElementException, StaleElementReferenceException
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation



HOJA_EXCEL = "adicion remesas"


def _redondear_a_entero(valor) -> str:
    """
    Convierte un valor con miles/decimales (string o número) a entero redondeado (0 decimales),
    retornado como string sin separadores.
    """
    if valor is None:
        return ""
    s = str(valor).strip()
    if not s or s.lower() == "nan":
        return ""

    s = s.replace("$", "").replace(" ", "")

    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    else:
        if "," in s:
            parts = s.split(",")
            if len(parts) == 2 and len(parts[1]) in (1, 2):
                s = s.replace(",", ".")
            else:
                s = s.replace(",", "")
        if "." in s:
            parts = s.split(".")
            if len(parts) == 2 and len(parts[1]) in (1, 2):
                pass
            else:
                s = s.replace(".", "")

    try:
        d = Decimal(s)
    except InvalidOperation:
        return ""

    entero = d.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return str(int(entero))



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


def _normalizar_numero_entero(valor) -> str:
    if valor is None:
        return ""
    s = str(valor).strip()
    if not s or s.lower() == "nan":
        return ""
    s = s.replace(".", "").replace(",", "").replace("$", "").replace(" ", "")
    s = re.sub(r"[^\d]", "", s)
    return s


def esperar_overlay(driver, logger=None, timeout=60) -> bool:
    try:
        WebDriverWait(driver, timeout).until(
            EC.invisibility_of_element_located((By.CSS_SELECTOR, "#holdon-overlay, .holdon-overlay"))
        )
        return True
    except TimeoutException:
        if logger:
            logger.warning("Timeout esperando overlay (holdon-overlay).")
        return False


def _click_seguro(driver, wait, logger, by_locator, desc="elemento", timeout_overlay=90, intentos=3):
    last_err = None
    for n in range(1, intentos + 1):
        try:
            esperar_overlay(driver, logger, timeout=timeout_overlay)

            el = wait.until(EC.element_to_be_clickable(by_locator))
            try:
                driver.execute_script("arguments[0].scrollIntoView({block:'center'});", el)
            except Exception:
                pass

            el.click()
            return el

        except ElementClickInterceptedException as e:
            last_err = e
            if logger:
                logger.warning(f"Click interceptado en {desc} (intento {n}/{intentos}). Reintentando...")
            esperar_overlay(driver, logger, timeout=timeout_overlay)
            time.sleep(0.5)

        except TimeoutException as e:
            last_err = e
            if logger:
                logger.warning(f"Timeout esperando {desc} clickable (intento {n}/{intentos}). Reintentando...")
            time.sleep(0.5)

    if last_err:
        raise last_err
    raise RuntimeError(f"No se pudo hacer click en {desc}.")


def _aceptar_alerta_js_si_aparece(driver, logger, timeout=10) -> bool:
    try:
        alert = WebDriverWait(driver, timeout).until(EC.alert_is_present())
        txt = alert.text
        logger.info(f"Alerta JS detectada: {txt}")
        alert.accept()
        logger.info("Alerta JS aceptada (OK).")
        time.sleep(0.5)
        return True
    except TimeoutException:
        return False


from selenium.common.exceptions import StaleElementReferenceException

def _click_sweetalert_si(driver, logger, timeout=20, pre_click_delay=1.0) -> bool:
    try:
        btn_si = WebDriverWait(driver, timeout).until(
            EC.visibility_of_element_located((By.CSS_SELECTOR, "button.confirm"))
        )
        time.sleep(pre_click_delay)  # tiempo para que el popup termine de cargar/animar
        logger.info("SweetAlert: popup cargado, clic en 'Si'...")
        try:
            btn_si.click()
        except ElementClickInterceptedException:
            driver.execute_script("arguments[0].click();", btn_si)
        return True
    except TimeoutException:
        logger.info("SweetAlert: no apareció botón 'Si'.")
        return False






def _to_menu_frame(driver, wait):
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))


def _to_central_frame(driver, wait):
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))


def navegar_actualizar_factura(driver, wait, logger):
    logger.info("Navegando: Facturacion > Por Facturar > Actualizar...")

    _to_menu_frame(driver, wait)
    wait.until(EC.element_to_be_clickable((By.ID, "430ID"))).click()
    time.sleep(1)
    wait.until(EC.element_to_be_clickable((By.ID, "52ID"))).click()
    time.sleep(1)
    wait.until(EC.element_to_be_clickable((By.ID, "20190107ID"))).click()
    time.sleep(1)

    _to_central_frame(driver, wait)
    esperar_overlay(driver, logger, timeout=90)


def seleccionar_cliente_latin(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "cod_clientID_chosen"),
                 desc="Chosen Cliente (cod_clientID_chosen)", timeout_overlay=60, intentos=3)

    _click_seguro(
        driver, wait, logger,
        (By.XPATH, "//div[@id='cod_clientID_chosen']//li[contains(@class,'active-result') and normalize-space()='LATIN LOGISTICS COLOMBIA S.A.S. ( 901147181 )']"),
        desc="Opción Cliente LATIN LOGISTICS",
        timeout_overlay=60, intentos=3
    )
    logger.info("Cliente seleccionado: LATIN LOGISTICS COLOMBIA S.A.S. (901147181)")
    time.sleep(0.5)


def seleccionar_tiporem_corriente_contado(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "ind_tipremID_chosen"),
                 desc="Chosen Tipo Remesa (ind_tipremID_chosen)", timeout_overlay=60, intentos=3)

    _click_seguro(
        driver, wait, logger,
        (By.XPATH, "//div[@id='ind_tipremID_chosen']//li[contains(@class,'active-result') and normalize-space()='Corriente/Contado']"),
        desc="Opción Corriente/Contado",
        timeout_overlay=60, intentos=3
    )
    logger.info("Tipo Remesa seleccionado: Corriente/Contado")
    time.sleep(0.5)


def set_fecha_factura(driver, wait, logger, fecha_factura: str):
    fecha_factura = str(fecha_factura).strip()
    if not _es_valido(fecha_factura):
        raise ValueError("FECHA FACTURA vacía/NaN.")

    inp = wait.until(EC.element_to_be_clickable((By.ID, "fec_inicioID")))
    inp.click()
    inp.clear()
    inp.send_keys(fecha_factura)
    inp.send_keys(Keys.TAB)
    time.sleep(0.5)
    logger.info(f"Fecha filtro seteada (fec_inicioID): {fecha_factura}")


def aplicar_filtros(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "aceptarID"),
                 desc="Aceptar filtros (aceptarID)", timeout_overlay=180, intentos=4)

    # 1) Esperar popup -> dar tiempo -> clic en Si
    _click_sweetalert_si(driver, logger, timeout=20, pre_click_delay=1.0)

    # 2) Esperar a que el control del siguiente paso exista/sea usable
    esperar_overlay(driver, logger, timeout=300)
    _to_central_frame(driver, wait)

    wait.until(EC.element_to_be_clickable((By.NAME, "tbl_novedaID_length")))
    time.sleep(0.9)




def grid_select_all(driver, wait, logger):
    combo = wait.until(EC.element_to_be_clickable((By.NAME, "tbl_novedaID_length")))
    Select(combo).select_by_value("-1")
    logger.info("Grid: seleccionado 'All' (tbl_novedaID_length=-1).")
    esperar_overlay(driver, logger, timeout=300)
    time.sleep(1)


def filtrar_y_abrir_factura(driver, wait, logger, factura: str):
    factura = str(factura).strip()
    if not _es_valido(factura):
        raise ValueError("FACTURA vacía/NaN.")

    esperar_overlay(driver, logger, timeout=420)

    filtro = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter0")))
    filtro.click()
    filtro.send_keys(Keys.CONTROL + "a")
    filtro.send_keys(Keys.DELETE)
    filtro.send_keys(factura)
    filtro.send_keys(Keys.ENTER)

    time.sleep(1)

    link = wait.until(EC.element_to_be_clickable((By.XPATH, f"//a[normalize-space()='{factura}']")))
    logger.info(f"Abrir factura: clic en hyperlink {factura}...")
    link.click()

    esperar_overlay(driver, logger, timeout=180)
    time.sleep(1)


def abrir_popup_anadir_remesas(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "agregarID"),
                 desc="Añadir Remesas (agregarID)", timeout_overlay=120, intentos=3)

    wait.until(EC.presence_of_element_located((By.ID, "agregarNuevasRemesasID")))
    logger.info("Popup de remesas detectado (agregarNuevasRemesasID presente).")
    time.sleep(0.5)


def seleccionar_remesa_popup(driver, wait, logger, remesa: str) -> bool:
    remesa = str(remesa).strip()
    if not _es_valido(remesa):
        return False

    esperar_overlay(driver, logger, timeout=180)

    # OJO: agregarNuevasRemesasID sirve para confirmar que el modal abrió,
    # pero el grid real (DLCell*/DLCheckOp*) puede estar fuera de ese div.
    wait.until(EC.presence_of_element_located((By.ID, "agregarNuevasRemesasID")))

    # 1) Esperar que aparezcan celdas del grid (columna 0 = Nro. Remesa)
    #    Ejemplo real: <td class="celda" id="DLCell54-0">PYP41353</td>
    try:
        WebDriverWait(driver, 40).until(
            lambda d: len(d.find_elements(By.XPATH, "//td[contains(@id,'DLCell') and substring(@id, string-length(@id)-1)='-0']")) > 0
        )
    except TimeoutException:
        logger.warning(f"Popup: timeout esperando grid (DLCell*-0) para buscar remesa {remesa}.")
        return False

    # 2) Buscar la remesa SOLO en la columna Nro. Remesa (id termina en -0)
    #    Evita falsos positivos si el mismo texto aparece en otra columna.
    try:
        td = driver.find_element(
            By.XPATH,
            f"//td[contains(@id,'DLCell') and substring(@id, string-length(@id)-1)='-0' and normalize-space()='{remesa}']"
        )
    except NoSuchElementException:
        logger.warning(f"Popup: remesa no encontrada en columna Nro. Remesa (-0): {remesa}")
        return False

    td_id = td.get_attribute("id") or ""
    # td_id esperado: DLCell54-0  => idx = 54
    m = re.search(r"DLCell(\d+)-0", td_id)
    if not m:
        logger.warning(f"Popup: no se pudo extraer índice desde id de celda: {td_id} (remesa {remesa})")
        return False

    idx = m.group(1)
    chk_id = f"DLCheckOp{idx}"

    # 3) Marcar el checkbox correspondiente
    try:
        chk = driver.find_element(By.ID, chk_id)
    except NoSuchElementException:
        logger.warning(f"Popup: no se encontró checkbox {chk_id} para remesa {remesa}")
        return False

    try:
        driver.execute_script("arguments[0].scrollIntoView({block:'center'});", chk)
    except Exception:
        pass

    try:
        if not chk.is_selected():
            try:
                chk.click()
            except ElementClickInterceptedException:
                esperar_overlay(driver, logger, timeout=180)
                driver.execute_script("arguments[0].click();", chk)
    except StaleElementReferenceException:
        # Reintento si el grid refresca
        return seleccionar_remesa_popup(driver, wait, logger, remesa)

    logger.info(f"Popup: remesa seleccionada: {remesa} (chk={chk_id}, td={td_id})")
    return True




def confirmar_agregar_remesas_popup(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "agregarNuevasRemesasID"),
                 desc="Agregar Remesas (popup)", timeout_overlay=180, intentos=3)

    _aceptar_alerta_js_si_aparece(driver, logger, timeout=12)
    esperar_overlay(driver, logger, timeout=240)
    time.sleep(1)


def _idx_por_remesa(driver, remesa: str):
    """
    De <a id="det_remesa_8">PYP42713</a> extrae 8.
    """
    links = driver.find_elements(By.XPATH, f"//a[starts-with(@id,'det_remesa_') and normalize-space()='{remesa}']")
    if not links:
        return None
    id_attr = links[0].get_attribute("id") or ""
    m = re.match(r"det_remesa_(\d+)", id_attr)
    return int(m.group(1)) if m else None


def setear_viaje_y_valor_por_remesa(driver, wait, logger, remesa_to_valor: dict):
    """
    Usa IDs exactos:
      - select: cod_uniser_{idx}ID
      - input : val_cosuni_{idx}ID
    """
    for remesa, valor in remesa_to_valor.items():
        remesa = str(remesa).strip()
        valor = _redondear_a_entero(valor)

        if not (_es_valido(remesa) and _es_valido(valor) and valor.lstrip("-").isdigit()):
            continue

        esperar_overlay(driver, logger, timeout=180)

        idx = _idx_por_remesa(driver, remesa)
        if idx is None:
            logger.warning(f"Formulario: no se encontró det_remesa_* para remesa {remesa}")
            continue

        sel_id = f"cod_uniser_{idx}ID"
        val_id = f"val_cosuni_{idx}ID"

        # U.Servicio -> Viaje
        try:
            sel = wait.until(EC.presence_of_element_located((By.ID, sel_id)))
            try:
                Select(sel).select_by_visible_text("Viaje")
                time.sleep(0.5)
            except Exception:
                Select(sel).select_by_value("1")
        except Exception as e:
            logger.warning(f"No se pudo setear U.Servicio=Viaje en {sel_id} para {remesa}: {e}")

        # Vr.Unitario -> valor
        try:
            inp = wait.until(EC.element_to_be_clickable((By.ID, val_id)))
            inp.click()
            inp.send_keys(Keys.CONTROL + "a")
            inp.send_keys(Keys.DELETE)
            inp.send_keys(valor)
            inp.send_keys(Keys.TAB)
            time.sleep(0.8)
            logger.info(f"Valor actualizado: Remesa={remesa} | idx={idx} | Vr.Unitario={valor}")
        except Exception as e:
            logger.error(f"Error seteando Vr.Unitario en {val_id} para Remesa={remesa}: {e}")


def verificar_y_aceptar(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.XPATH, "//input[@type='button' and @value='Verificar']"),
                 desc="Verificar (realizarCalculos)", timeout_overlay=240, intentos=3)

    esperar_overlay(driver, logger, timeout=240)
    time.sleep(1)

    _click_seguro(driver, wait, logger, (By.ID, "okButtonID"),
                 desc="Aceptar (okButtonID)", timeout_overlay=240, intentos=3)

    _aceptar_alerta_js_si_aparece(driver, logger, timeout=12)
    esperar_overlay(driver, logger, timeout=240)

    try:
        WebDriverWait(driver, 12).until(
            EC.presence_of_element_located(
                (By.XPATH, "//*[contains(.,'Transaccion Exitosa') or contains(.,'Transacción Exitosa')]")
            )
        )
        logger.info("AVANSAT: Transaccion Exitosa detectada.")
    except TimeoutException:
        logger.info("No se detectó texto 'Transaccion Exitosa' (puede variar el mensaje).")

    time.sleep(1)


def actualizar_otra_factura(driver, wait, logger):
    _click_seguro(driver, wait, logger, (By.ID, "backID"),
                 desc="Actualizar Otra Factura (backID)", timeout_overlay=180, intentos=3)
    esperar_overlay(driver, logger, timeout=180)
    time.sleep(1)


def procesar_actualizar_facturas(driver, wait, excel_path: str, logger=None, progress_cb=None):
    """
    Lee hoja 'adicion remesas' con:
      FACTURA | FECHA FACTURA | REMESA | VALOR

    Agrupa por (FACTURA, FECHA FACTURA) y actualiza cada factura.
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
            logger.warning("Hoja 'adicion remesas' sin registros; no se procesará nada.")
            return
    except Exception as e:
        logger.error(f"Error leyendo Excel (hoja '{HOJA_EXCEL}'): {e}")
        return

    cols_req = ["FACTURA", "FECHA FACTURA", "REMESA", "VALOR"]
    faltantes = [c for c in cols_req if c not in df.columns]
    if faltantes:
        logger.error(f"La hoja '{HOJA_EXCEL}' no tiene columnas requeridas: {faltantes}")
        return

    df2 = df.copy()
    for c in cols_req:
        df2[c] = df2[c].astype(str).str.strip()

    df2 = df2[df2["FACTURA"].apply(_es_valido) &
              df2["FECHA FACTURA"].apply(_es_valido) &
              df2["REMESA"].apply(_es_valido)]

    if df2.empty:
        logger.warning("No hay filas válidas en 'adicion remesas'.")
        return

    grupos = list(df2.groupby(["FACTURA", "FECHA FACTURA"]))
    total = len(grupos)
    done = 0
    if progress_cb:
        progress_cb(done, total, "Listo para actualizar facturas")

    try:
        navegar_actualizar_factura(driver, wait, logger)

        for (factura, fecha), g in grupos:
            done += 1
            if progress_cb:
                progress_cb(done, total, f"Actualizando factura {factura}")

            logger.info(f"=== Actualizar factura: {factura} | Fecha: {fecha} | Remesas: {len(g)} ===")

            _to_central_frame(driver, wait)

            # filtros
            seleccionar_cliente_latin(driver, wait, logger)
            seleccionar_tiporem_corriente_contado(driver, wait, logger)
            set_fecha_factura(driver, wait, logger, fecha)
            aplicar_filtros(driver, wait, logger)

            _to_central_frame(driver, wait)
            grid_select_all(driver, wait, logger)

            # buscar factura y abrir
            filtrar_y_abrir_factura(driver, wait, logger, factura)

            _to_central_frame(driver, wait)

            # popup + seleccionar remesas
            abrir_popup_anadir_remesas(driver, wait, logger)

            remesas = g["REMESA"].tolist()
            remesa_to_valor = dict(zip(g["REMESA"], g["VALOR"]))

            seleccionadas = 0
            for rem in remesas:
                try:
                    if seleccionar_remesa_popup(driver, wait, logger, rem):
                        seleccionadas += 1
                except Exception as e:
                    logger.error(f"Popup: error procesando remesa {rem}: {e}")
                    continue
            logger.info(f"Popup: remesas seleccionadas {seleccionadas}/{len(remesas)} para factura {factura}")

            confirmar_agregar_remesas_popup(driver, wait, logger)

            _to_central_frame(driver, wait)

            # set valores
            setear_viaje_y_valor_por_remesa(driver, wait, logger, remesa_to_valor)

            # verificar + aceptar
            verificar_y_aceptar(driver, wait, logger)

            # volver
            actualizar_otra_factura(driver, wait, logger)

        logger.info("Finalizó módulo actualizar_factura.py")

    except Exception as e:
        logger.error(f"Fallo en módulo Actualizar Factura: {e}")
        guardar_html_error("error_actualizar_factura_general.html", driver, logger)
        raise

    finally:
        logger.info("Finalizando módulo Actualizar Factura (driver se mantiene para otros procesos).")
