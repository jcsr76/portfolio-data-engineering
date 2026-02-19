# prefacturas_avansat.py

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
from selenium.common.exceptions import TimeoutException, ElementClickInterceptedException
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation


HOJA_EXCEL = "prefacturas"


def _redondear_a_entero(valor) -> str:
    """
    Lee un valor que puede venir como:
    - número (int/float)
    - string con miles y decimales (ej: '6,213.000', '6.213,50', '$ 1 234,56')
    Devuelve entero redondeado (0 decimales) como string, sin separadores.
    """
    if valor is None:
        return ""
    s = str(valor).strip()
    if not s or s.lower() == "nan":
        return ""

    # limpiar moneda/espacios
    s = s.replace("$", "").replace(" ", "")

    # Heurística simple:
    # si hay ',' y '.', asumimos que el último separador es decimal
    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            # '1.234,56' -> miles '.' ; decimal ','
            s = s.replace(".", "").replace(",", ".")
        else:
            # '1,234.56' -> miles ',' ; decimal '.'
            s = s.replace(",", "")
    else:
        # solo ',' -> puede ser decimal o miles; si hay 1-2 dígitos al final, tratar como decimal
        if "," in s:
            parts = s.split(",")
            if len(parts) == 2 and len(parts[1]) in (1, 2):
                s = s.replace(",", ".")   # '123,45' -> 123.45
            else:
                s = s.replace(",", "")    # '1,234' -> 1234
        # solo '.' -> idem: si hay 1-2 dígitos al final, tratar como decimal, si no, miles
        if "." in s:
            parts = s.split(".")
            if len(parts) == 2 and len(parts[1]) in (1, 2):
                pass  # decimal '.' ya está OK
            else:
                s = s.replace(".", "")

    try:
        d = Decimal(s)
    except InvalidOperation:
        return ""

    entero = d.quantize(Decimal("1"), rounding=ROUND_HALF_UP)  # redondeo a 0 decimales
    return str(int(entero))


def pausa_ui(driver, logger=None, timeout_overlay=30, sleep_s=0.5):
    """
    Pausa corta para estabilizar AVANSAT entre acciones.
    - Si existe holdon-overlay, espera a que desaparezca.
    - Luego duerme 0.5s para que el DOM/frames terminen de redibujar.
    """
    try:
        esperar_overlay(driver, logger, timeout=timeout_overlay)
    except Exception:
        pass
    time.sleep(sleep_s)

def esperar_overlay(driver, logger=None, timeout=60) -> bool:
    """
    Espera a que desaparezca el overlay de HoldOn (holdon-overlay),
    que es lo que intercepta los clicks en AVANSAT.
    """
    try:
        WebDriverWait(driver, timeout).until(
            EC.invisibility_of_element_located((By.ID, "holdon-overlay"))
        )
        return True
    except TimeoutException:
        if logger:
            logger.warning("Timeout esperando holdon-overlay (sigue visible).")
        return False


def _click_seguro(driver, wait, logger, by_locator, desc="elemento", timeout_overlay=90, intentos=3):
    """
    Click robusto:
    - espera a que se vaya el overlay (si existe)
    - espera a que el elemento sea clickable
    - hace scroll al elemento
    - reintenta si hay ElementClickInterceptedException
    """
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
                logger.warning(f"Click interceptado en {desc} (intento {n}/{intentos}). Esperando overlay y reintentando...")
            esperar_overlay(driver, logger, timeout=timeout_overlay)
            time.sleep(0.3)

        except TimeoutException as e:
            last_err = e
            if logger:
                logger.warning(f"Timeout esperando {desc} clickable (intento {n}/{intentos}). Reintentando...")
            time.sleep(0.3)

    # si no pudo
    if last_err:
        raise last_err
    raise RuntimeError(f"No se pudo hacer click en {desc}.")


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


def _limpiar_input(input_el, max_intentos: int = 3):
    """
    Limpia input de forma robusta y verificable.
    Intenta: click + clear + CTRL+A + DELETE, y valida que value quede vacío.
    """
    for _ in range(max_intentos):
        try:
            input_el.click()
            time.sleep(0.05)

            try:
                input_el.clear()
            except Exception:
                pass

            input_el.send_keys(Keys.CONTROL + "a")
            input_el.send_keys(Keys.DELETE)
            time.sleep(0.05)

            val = (input_el.get_attribute("value") or "").strip()
            if val == "":
                return True
        except Exception:
            time.sleep(0.05)

    return False


def _normalizar_numero_entero(valor) -> str:
    """
    Devuelve solo dígitos (para inputs que luego aplican BlurMoney).
    Ej: '6,213.000' -> '6213000', '6213' -> '6213'
    """
    if valor is None:
        return ""
    s = str(valor).strip()
    if not s or s.lower() == "nan":
        return ""
    s = s.replace(".", "").replace(",", "").replace("$", "").replace(" ", "")
    s = re.sub(r"[^\d]", "", s)
    return s


def navegar_a_prefacturas(driver, wait, logger):
    """
    Primera pantalla (grid):
      menuFrame: Facturacion (430ID) -> Por Facturar (52ID) -> Insertar (20190103ID)
      centralFrame:
        - click radio ind_tipfacRID (LoadClientGrid)
        - click label cod_factur4ID (NIT 901147181)   <-- (igual que manual)
        - click radio cod_tiprem4ID (frm_factur.submit)
    """
    logger.info("Navegando: Facturacion > Por Facturar > Insertar...")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))

    wait.until(EC.element_to_be_clickable((By.ID, "430ID"))).click()
    time.sleep(0.5)

    # En tu flujo manual NO usas "Por Facturar (52ID)" explícito, pero lo dejo como estaba.
    wait.until(EC.element_to_be_clickable((By.ID, "52ID"))).click()
    time.sleep(0.5)

    wait.until(EC.element_to_be_clickable((By.ID, "20190103ID"))).click()
    time.sleep(1)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    logger.info("Click en radio 'ind_tipfacRID' (LoadClientGrid)...")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    radio = wait.until(EC.presence_of_element_located((By.ID, "ind_tipfacRID")))
    driver.execute_script("arguments[0].scrollIntoView({block:'center'});", radio)

    # Click solo si no está seleccionado
    if not radio.is_selected():
        radio.click()

    # Pausa solicitada (0.5s + overlay si existe)
    pausa_ui(driver, logger, timeout_overlay=30, sleep_s=0.5)

    # Re-ubicar y verificar (a veces el DOM se redibuja)
    radio = wait.until(EC.presence_of_element_located((By.ID, "ind_tipfacRID")))
    seleccionado = radio.is_selected()
    checked_attr = radio.get_attribute("checked")

    logger.info(f"Radio ind_tipfacRID seleccionado? is_selected={seleccionado} | checked_attr={checked_attr}")

    if not seleccionado:
        logger.warning("Radio ind_tipfacRID NO quedó seleccionado. Reintentando con JS click...")
        driver.execute_script("arguments[0].click();", radio)

        pausa_ui(driver, logger, timeout_overlay=30, sleep_s=0.5)

        radio = wait.until(EC.presence_of_element_located((By.ID, "ind_tipfacRID")))
        logger.info(
            f"Re-check radio ind_tipfacRID: is_selected={radio.is_selected()} | checked_attr={radio.get_attribute('checked')}"
        )

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    # ===== AJUSTE ÚNICO: usar cod_factur4ID como en el paso manual =====
    logger.info("Seleccionando cliente (cod_factur4ID / NIT 901147181)...")
    wait.until(EC.element_to_be_clickable((By.ID, "cod_factur4ID"))).click()

    pausa_ui(driver, logger, timeout_overlay=60, sleep_s=0.5)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    logger.info("Click en radio 'cod_tiprem4ID' (frm_factur.submit)...")
    wait.until(EC.element_to_be_clickable((By.ID, "cod_tiprem4ID"))).click()

    pausa_ui(driver, logger, timeout_overlay=60, sleep_s=0.5)

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.ID, "DLFilter0")))
    logger.info("Listo: pantalla grid (DLFilter0 presente).")

    pausa_ui(driver, logger, timeout_overlay=60, sleep_s=0.5)




def seleccionar_mostrar_todo_en_grid(driver, wait, logger):
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.NAME, "tbl_novedaID_length")))

    combo = wait.until(EC.element_to_be_clickable((By.NAME, "tbl_novedaID_length")))
    Select(combo).select_by_value("-1")
    logger.info("Combo de filas cambiado a 'All' (tbl_novedaID_length=-1). Esperando carga del grid...")

    # 1) Esperar overlay (si AVANSAT lo usa al redibujar)
    esperar_overlay(driver, logger, timeout=120)

    # 2) Esperar a que el input de filtro sea realmente interactuable
    wait.until(EC.element_to_be_clickable((By.ID, "DLFilter0")))

    # 3) Esperar a que el grid tenga filas (AJAX terminó)
    wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, "#tbl_novedaID tbody tr")) > 0)

    logger.info("Grid cargado: filas disponibles y filtro listo (DLFilter0).")



def seleccionar_remesa_en_grid(driver, wait, logger, remesa: str) -> bool:
    remesa = str(remesa).strip()
    if not _es_valido(remesa):
        raise ValueError("Remesa vacía/NaN, no se puede filtrar.")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    # (1) esperar overlay por si está calculando algo de selección anterior
    esperar_overlay(driver, logger, timeout=60)

    filtro = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter0")))

    ok_clear = _limpiar_input(filtro, max_intentos=4)
    if not ok_clear:
        logger.warning("No se pudo limpiar DLFilter0 de forma verificable; se intenta escribir igual.")

    filtro.send_keys(remesa)
    time.sleep(0.7)  # grid auto-refresh

    td_remesa = wait.until(EC.presence_of_element_located((By.XPATH, f"//td[normalize-space()='{remesa}']")))
    tr = td_remesa.find_element(By.XPATH, "./ancestor::tr[1]")

    ok_imgs = tr.find_elements(By.XPATH, ".//img[contains(@src,'/check.png') or contains(@src,'check.png')]")
    err_imgs = tr.find_elements(By.XPATH, ".//img[contains(@src,'/error2.png') or contains(@src,'error2.png')]")

    if err_imgs and not ok_imgs:
        logger.warning(f"⛔ Remesa {remesa}: NO radicada (error2.png). Se omite y NO se selecciona.")
        return False

    if ok_imgs:
        chk = tr.find_element(By.XPATH, ".//input[@type='checkbox']")
        if not chk.is_selected():
            # click seguro (usa el WebElement, no locator)
            for intento in range(1, 4):
                try:
                    esperar_overlay(driver, logger, timeout=60)
                    driver.execute_script("arguments[0].scrollIntoView({block:'center'});", chk)
                    chk.click()
                    time.sleep(0.2)
                    break
                except ElementClickInterceptedException:
                    logger.warning(f"Click interceptado en checkbox de {remesa} (intento {intento}/3). Reintentando...")
                    esperar_overlay(driver, logger, timeout=60)
                    time.sleep(0.3)

        logger.info(f"✅ Remesa seleccionada (radicada OK): {remesa}")
        return True

    logger.warning(f"⚠️ Remesa {remesa}: estado de radicación no reconocido (sin check.png ni error2.png). Se omite.")
    return False


def limpiar_filtro_remesa(driver, wait):
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    filtro = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter0")))
    _limpiar_input(filtro)
    time.sleep(0.2)


def seleccionar_origen_destino_global(driver, wait, logger, ciudad_origen: str, ciudad_destino: str):
    """
    Origen  -> select id=DLFilter9
    Destino -> select id=DLFilter10
    """
    ciudad_origen = str(ciudad_origen).strip()
    ciudad_destino = str(ciudad_destino).strip()

    if not _es_valido(ciudad_origen):
        raise ValueError("CIUDAD ORIGEN vacía/NaN.")
    if not _es_valido(ciudad_destino):
        raise ValueError("CIUDAD DESTINO vacía/NaN.")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    sel_origen = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter9")))
    Select(sel_origen).select_by_visible_text(ciudad_origen)
    time.sleep(0.3)

    sel_destino = wait.until(EC.element_to_be_clickable((By.ID, "DLFilter10")))
    Select(sel_destino).select_by_visible_text(ciudad_destino)
    time.sleep(0.3)

    logger.info(f"Origen/Destino global seleccionado: Origen={ciudad_origen} | Destino={ciudad_destino}")


def ir_a_formulario_facturacion(driver, wait, logger):
    """
    Click Aceptar en la pantalla de selección de remesas y espera el siguiente formulario:
    - Espera que aparezca cod_sedexxID en centralFrame.
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    logger.info("Clic en Aceptar (SendRemesas) para cargar formulario de facturación...")
    _click_seguro(
        driver,
        wait,
        logger,
        (By.XPATH, "//input[@type='button' and @value='Aceptar']"),
        desc="Aceptar SendRemesas",
        timeout_overlay=90,
        intentos=3
    )

    # Esperar el formulario siguiente
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.ID, "cod_sedexxID")))
    logger.info("Formulario de facturación cargado (cod_sedexxID presente).")


def configurar_encabezado_factura(driver, wait, logger, agencia_facturacion: str):
    """
    En formulario siguiente:
      1) cod_sedexxID -> LATIN LOGISTICS COLOMBIA S.A.S.
      2) cod_agenciID -> agencia_facturacion (texto visible)
      3) cod_tipcomID -> COMPROBANTE DE FACTURACION
    """
    agencia_facturacion = str(agencia_facturacion).strip()
    if not _es_valido(agencia_facturacion):
        raise ValueError("AGENCIA FACTURACION vacía/NaN.")

    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.presence_of_element_located((By.ID, "cod_sedexxID")))

    sel_sede = wait.until(EC.element_to_be_clickable((By.ID, "cod_sedexxID")))
    Select(sel_sede).select_by_visible_text("LATIN LOGISTICS COLOMBIA S.A.S.")
    time.sleep(0.5)

    sel_agencia = wait.until(EC.element_to_be_clickable((By.ID, "cod_agenciID")))
    Select(sel_agencia).select_by_visible_text(agencia_facturacion)
    time.sleep(0.8)  # dispara LoadTipcom / cargar impuestos

    sel_tipcom = wait.until(EC.element_to_be_clickable((By.ID, "cod_tipcomID")))
    Select(sel_tipcom).select_by_visible_text("COMPROBANTE DE FACTURACION")
    time.sleep(0.5)

    logger.info(
        f"Encabezado factura listo: Sede=LATIN LOGISTICS COLOMBIA S.A.S. | Agencia={agencia_facturacion} | Tipo=COMPROBANTE DE FACTURACION"
    )


def setear_detalle_por_remesa(driver, wait, logger, remesa_to_valor: dict):
    """
    Recorre filas del detalle en el formulario:
      - Detecta remesa por el texto del <a> (PYPxxxxx)
      - setea U.Servicio (cod_uniser{i}ID) a Viaje
      - setea Vr.Unitario (val_cosuni{i}ID) al valor del Excel para esa remesa
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    wait.until(EC.presence_of_element_located((By.ID, "cod_uniser0ID")))

    idx = 0
    actualizados = 0
    while True:
        sel_id = f"cod_uniser{idx}ID"
        val_id = f"val_cosuni{idx}ID"

        selects = driver.find_elements(By.ID, sel_id)
        if not selects:
            break

        sel_el = selects[0]
        tr = sel_el.find_element(By.XPATH, "./ancestor::tr[1]")
        links = tr.find_elements(By.XPATH, ".//a[normalize-space()]")
        remesa_fila = links[0].text.strip() if links else ""

        if remesa_fila and remesa_fila in remesa_to_valor:
            Select(sel_el).select_by_visible_text("Viaje")
            time.sleep(0.1)

            inp_list = tr.find_elements(By.ID, val_id)
            if not inp_list:
                inp_list = tr.find_elements(By.XPATH, ".//input[starts-with(@id,'val_cosuni')]")

            if inp_list:
                inp = inp_list[0]
                _limpiar_input(inp)
                inp.send_keys(remesa_to_valor[remesa_fila])
                time.sleep(0.1)
                actualizados += 1
                logger.info(
                    f"Detalle OK: Remesa={remesa_fila} | U.Servicio=Viaje | Vr.Unitario={remesa_to_valor[remesa_fila]}"
                )
            else:
                logger.warning(f"No se encontró input Vr.Unitario para Remesa={remesa_fila} (idx={idx}).")
        else:
            logger.warning(f"Remesa en formulario no encontrada en Excel o vacía (idx={idx}): '{remesa_fila}'")

        idx += 1

    logger.info(f"Detalle procesado. Filas detectadas={idx} | Filas actualizadas={actualizados}")


def verificar_y_aceptar_factura(driver, wait, logger, observaciones: str):
    """
    1) click ind_roundID
    2) click Verificar (Calculos)
    3) si observaciones: llenar obs_facturID
    4) esperar overlay
    5) click Aceptar (Submitfactur)
    6) si aparece confirmación JS "¿Está seguro de insertar la Factura?" -> Aceptar
    """
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

    chk_round = wait.until(EC.element_to_be_clickable((By.ID, "ind_roundID")))
    if not chk_round.is_selected():
        chk_round.click()
    time.sleep(0.3)

    logger.info("Clic en Verificar (Calculos)...")
    _click_seguro(
        driver,
        wait,
        logger,
        (By.XPATH, "//input[@type='button' and @value='Verificar']"),
        desc="Botón Verificar",
        timeout_overlay=90,
        intentos=3
    )

    # IMPORTANTÍSIMO: esperar a que termine (overlay se quita cuando acaba de calcular)
    esperar_overlay(driver, logger, timeout=120)

    observaciones = "" if observaciones is None else str(observaciones).strip()
    if _es_valido(observaciones):
        txt = wait.until(EC.element_to_be_clickable((By.ID, "obs_facturID")))
        txt.click()
        txt.clear()
        txt.send_keys(observaciones)
        time.sleep(0.2)
        logger.info("Observaciones ingresadas en obs_facturID.")

        # a veces al escribir vuelve a disparar cálculo/overlay
        esperar_overlay(driver, logger, timeout=60)

    logger.info("Clic en Aceptar (Submitfactur) para finalizar prefactura...")
    _click_seguro(
        driver,
        wait,
        logger,
        (By.XPATH, "//input[@type='button' and @value='Aceptar' and contains(@onclick,'Submitfactur')]"),
        desc="Aceptar Submitfactur",
        timeout_overlay=120,
        intentos=4
    )

    # NUEVO: si aparece confirmación JS, aceptarla para evitar "unexpected alert open"
    try:
        alerta = WebDriverWait(driver, 8).until(EC.alert_is_present())
        texto = alerta.text
        logger.info(f"Alerta confirmación detectada: {texto}")
        alerta.accept()
        logger.info("Alerta aceptada (OK).")
    except TimeoutException:
        pass

    # esperar post-submit (si aparece overlay otra vez)
    esperar_overlay(driver, logger, timeout=120)
    time.sleep(1.5)



def procesar_prefacturas(driver, wait, excel_path: str, logger=None, progress_cb=None):
    """
    Flujo completo integrado:
      Pantalla 1 (selección):
        1) Navegar
        2) All
        3) Seleccionar remesas del Excel (radicadas)
        4) Limpiar filtro
        5) Seleccionar Origen/Destino global
        6) Aceptar (SendRemesas) -> cargar Pantalla 2

      Pantalla 2 (facturación):
        7) cod_sedexxID = LATIN LOGISTICS COLOMBIA S.A.S.
        8) cod_agenciID = AGENCIA FACTURACION (Excel)
        9) cod_tipcomID = COMPROBANTE DE FACTURACION
        10) Para cada remesa cargada: U.Servicio=Viaje + Vr.Unitario (Excel: Suma de Cobro sin Auxiliar)
        11) ind_roundID + Verificar + (OBSERVACIONES si hay) + Aceptar
    """
    if logger is None:
        logger = configurar_logger("run", str(work_path("logs/run.log")))

    if not excel_path or not os.path.exists(excel_path):
        logger.error(f"No se encuentra el archivo Excel: {excel_path}")
        return

    # 1) Cargar Excel
    try:
        df = pd.read_excel(excel_path, sheet_name=HOJA_EXCEL, dtype=str)
        df.columns = df.columns.str.strip()

        if df.empty:
            logger.warning("Hoja 'prefacturas' sin registros; no se procesará nada.")
            return
    except Exception as e:
        logger.error(f"Error leyendo Excel de Prefacturas: {e}")
        return

    # 2) Validar columnas
    columnas_requeridas = [
        "Remesa",
        "Suma de Cobro sin Auxiliar",
        "CIUDAD ORIGEN",
        "CIUDAD DESTINO",
        "AGENCIA FACTURACION",
    ]
    faltantes = [c for c in columnas_requeridas if c not in df.columns]
    if faltantes:
        logger.error(f"La hoja 'prefacturas' no tiene columnas requeridas: {faltantes}")
        return

    df_valid = df[df["Remesa"].apply(_es_valido)].copy()
    if df_valid.empty:
        logger.warning("No hay remesas válidas en hoja 'prefacturas'.")
        return

    origen_global = str(df_valid.iloc[0].get("CIUDAD ORIGEN", "")).strip()
    destino_global = str(df_valid.iloc[0].get("CIUDAD DESTINO", "")).strip()
    orig_distintos = set(df_valid["CIUDAD ORIGEN"].astype(str).str.strip().tolist())
    dest_distintos = set(df_valid["CIUDAD DESTINO"].astype(str).str.strip().tolist())
    if len(orig_distintos) > 1 or len(dest_distintos) > 1:
        logger.warning(
            f"Se detectaron múltiples Origen/Destino en Excel; se usará el primero. "
            f"Origen distintos={sorted(orig_distintos)} | Destino distintos={sorted(dest_distintos)}"
        )

    agencia_global = str(df_valid.iloc[0].get("AGENCIA FACTURACION", "")).strip()
    ag_distintas = set(df_valid["AGENCIA FACTURACION"].astype(str).str.strip().tolist())
    if len(ag_distintas) > 1:
        logger.warning(f"Se detectaron múltiples AGENCIA FACTURACION; se usará la primera: {sorted(ag_distintas)}")

    obs_vals = []
    if "OBSERVACIONES" in df_valid.columns:
        obs_vals = [str(x).strip() for x in df_valid["OBSERVACIONES"].tolist() if _es_valido(x)]
    observaciones_global = " | ".join(sorted(set(obs_vals)))[:320] if obs_vals else ""

    remesa_to_valor = {}
    for _, row in df_valid.iterrows():
        r = str(row.get("Remesa", "")).strip()
        v = _redondear_a_entero(row.get("Suma de Cobro sin Auxiliar", ""))

        if not (_es_valido(r) and _es_valido(v)):
            logger.warning(f"Remesa/valor inválido. Remesa='{r}' Valor='{v}'. Se omite.")
            continue

        # v debe ser entero sin separadores
        if not v.isdigit():
            logger.warning(f"Valor no entero para remesa {r}: '{v}'. Se omite.")
            continue

        remesa_to_valor[r] = v

    total = int(df["Remesa"].apply(_es_valido).sum())
    done = 0
    if progress_cb:
        progress_cb(done, total, "Listo para procesar prefacturas")

    try:
        # ── PANTALLA 1: SELECCIÓN ─────────────────────────────────────
        navegar_a_prefacturas(driver, wait, logger)
        seleccionar_mostrar_todo_en_grid(driver, wait, logger)

        for index, row in df.iterrows():
            remesa = str(row.get("Remesa", "")).strip()
            if not _es_valido(remesa):
                logger.warning(f"Fila {index + 1}: Remesa vacía. Saltando.")
                continue

            done += 1
            if progress_cb:
                progress_cb(done, total, f"Seleccionando Remesa {remesa}")

            logger.info(f"--- Prefacturas | Selección | Fila {index + 1} | Remesa {remesa} ---")
            try:
                seleccionar_remesa_en_grid(driver, wait, logger, remesa)
            except Exception as e_row:
                logger.error(f"Error seleccionando remesa fila {index + 1} (remesa={remesa}): {e_row}")
                guardar_html_error(f"error_prefact_sel_{index + 1}.html", driver, logger)

        limpiar_filtro_remesa(driver, wait)
        seleccionar_origen_destino_global(driver, wait, logger, origen_global, destino_global)
        ir_a_formulario_facturacion(driver, wait, logger)

        # ── PANTALLA 2: FACTURACIÓN ───────────────────────────────────
        configurar_encabezado_factura(driver, wait, logger, agencia_global)
        setear_detalle_por_remesa(driver, wait, logger, remesa_to_valor)
        verificar_y_aceptar_factura(driver, wait, logger, observaciones_global)

    except Exception as e:
        logger.error(f"Fallo en módulo Prefacturas: {e}")
        guardar_html_error("error_prefacturas_general.html", driver, logger)
        raise

    finally:
        logger.info("Finalizando módulo de Prefacturas (driver se mantiene para otros procesos).")
