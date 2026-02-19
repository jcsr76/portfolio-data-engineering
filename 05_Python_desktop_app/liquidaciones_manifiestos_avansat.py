# liquidaciones_manifiestos_avansat.py

import time
import pandas as pd
import os

# Importaciones de tus módulos
from logger_config import configurar_logger
from utils_rutas import work_path

# Importaciones de Selenium
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.keys import Keys

# ── Configuración ───────────────────────────────────────────────────────────
HOJA_EXCEL = "liquidaciones"


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


def procesar_cierres_y_facturacion(driver, wait, excel_path: str, logger=None, progress_cb=None):
    """
    Procesa cierres y facturación de manifiestos en AVANSAT.

    Parámetros:
        driver: instancia de Selenium WebDriver ya autenticada en AVANSAT.
        wait:   instancia de WebDriverWait asociada al driver.
        excel_path: ruta completa al archivo Excel seleccionado por el usuario.
        logger: logger central (un solo run.log para toda la corrida).
        progress_cb: callback opcional progress_cb(done:int, total:int, etapa:str)
    """
    # 1) Logger central (inyectado por orquestador/GUI)
    if logger is None:
        logger = configurar_logger("run", str(work_path("logs/run.log")))

    # 2) Validar ruta de Excel
    if not excel_path or not os.path.exists(excel_path):
        logger.error(f"No se encuentra el archivo Excel: {excel_path}")
        return

    # 3) Cargar Excel
    try:
        df = pd.read_excel(excel_path, sheet_name=HOJA_EXCEL, dtype=str)
        df.columns = df.columns.str.strip()

        if df.empty:
            logger.warning("Hoja 'liquidaciones' sin registros; no se procesará nada.")
            return

    except Exception as e:
        logger.error(f"Error leyendo Excel: {e}")
        return

    # 4) Preparar conteo para progreso (solo filas con Manifiesto válido)
    if "Manifiesto" not in df.columns:
        logger.error("La hoja 'liquidaciones' no tiene la columna requerida: 'Manifiesto'.")
        return

    total = int(df["Manifiesto"].apply(_es_valido).sum())
    done = 0

    if progress_cb:
        progress_cb(done, total, "Listo para procesar manifiestos")

    try:
        # 5) Navegación inicial (solo para llegar al módulo)
        logger.info("Iniciando navegación al menú...")
        driver.switch_to.default_content()
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))

        wait.until(EC.element_to_be_clickable((By.ID, "425ID"))).click()
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.XPATH, "//a[contains(text(), 'Por Liquidar')]"))).click()
        time.sleep(1)
        wait.until(EC.element_to_be_clickable((By.ID, "4ID"))).click()
        time.sleep(2)

        # 6) Bucle transaccional
        for index, row in df.iterrows():
            manifiesto = str(row.get("Manifiesto", "")).strip()
            tipo_vehiculo = str(row.get("Tipo Vehiculo", "")).strip().upper()
            es_propio = "PROPIO" in tipo_vehiculo

            if not _es_valido(manifiesto):
                continue

            done += 1
            if progress_cb:
                progress_cb(done, total, f"Procesando Manifiesto {manifiesto}")

            logger.info(f"--- Procesando Fila {index + 1}: Manifiesto {manifiesto} | Tipo: {tipo_vehiculo} ---")

            try:
                # ────────────────────────────────────────────────────────
                # PASO 0: ASEGURAR ENTORNO Y RADIO BUTTON (CRUCIAL)
                # ────────────────────────────────────────────────────────
                driver.switch_to.default_content()
                wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))

                try:
                    radio_check = wait.until(EC.element_to_be_clickable((By.ID, "ind_tipliqRID")))
                    radio_check.click()
                    time.sleep(2)
                except Exception as e_radio:
                    logger.warning(
                        f"No se pudo clickear radio button inicial (puede que ya esté seleccionado): {e_radio}"
                    )

                # ────────────────────────────────────────────────────────
                # PASO 1: MANIFIESTO Y VALIDACIÓN DE BLOQUEO (Mensaje Naranja)
                # ────────────────────────────────────────────────────────
                campo_manifiesto = wait.until(EC.element_to_be_clickable((By.ID, "num_documeID")))
                campo_manifiesto.clear()
                campo_manifiesto.send_keys(manifiesto)
                campo_manifiesto.send_keys(Keys.TAB)
                time.sleep(3)

                msgs_bloqueo = driver.find_elements(By.XPATH, "//div[contains(text(), 'no se puede Liquidar')]")
                if msgs_bloqueo and msgs_bloqueo[0].is_displayed():
                    texto_error = msgs_bloqueo[0].text
                    logger.warning(f"⚠️ SALTO: Manifiesto {manifiesto} tiene problemas: '{texto_error}'")
                    guardar_html_error(f"bloqueo_{manifiesto}.html", driver, logger)
                    logger.info("Saltando al siguiente registro...")
                # ────────────────────────────────────────────────────────
                # PASO: CÁLCULO DE VALOR (Hoist)
                # ────────────────────────────────────────────────────────
                raw_valor_turno = str(row.get("Suma de Total Turno P Tercero", "0")).strip()
                try:
                    val_int = int(round(float(raw_valor_turno)))
                    valor_turno_final = str(val_int)
                except Exception:
                    valor_turno_final = raw_valor_turno

                # ────────────────────────────────────────────────────────
                # PASO: DETECCION Y MANEJO DE "SERVICIO ESPECIAL" (POPUP) - AHORA PRIMERO
                # ────────────────────────────────────────────────────────
                try:
                    # Buscar link parcial "Insertar Servicio Especial"
                    link_servicio = driver.find_elements(By.XPATH, "//a[contains(text(), 'Insertar Servicio Especial')]")
                    
                    if link_servicio and link_servicio[0].is_displayed():
                        logger.info("LINK 'Insertar Servicio Especial' DETECTADO. Iniciando flujo popup PREVIO...")
                        
                        main_window = driver.current_window_handle
                        link_servicio[0].click()
                        time.sleep(3)
                        
                        # Cambiar a nueva ventana
                        all_windows = driver.window_handles
                        new_window = [w for w in all_windows if w != main_window]
                        if new_window:
                            driver.switch_to.window(new_window[0])
                            logger.info("Switched to 'Servicio Especial' window.")
                            
                            try:
                                # 1. Checkbox "31" (Fletes Propios en Popup)
                                chk_fletes = wait.until(EC.element_to_be_clickable((By.XPATH, "//input[@value='31']")))
                                if not chk_fletes.is_selected():
                                    chk_fletes.click()
                                
                                # 2. Valor (valuniven[15])
                                inp_valor = driver.find_element(By.NAME, "valuniven[15]")
                                inp_valor.clear()
                                inp_valor.send_keys(valor_turno_final)
                                
                                # 3. Verificar
                                btn_verificar = driver.find_element(By.CSS_SELECTOR, "input[value='Verificar']")
                                btn_verificar.click()
                                time.sleep(3)
                                
                                # 4. Aceptar
                                btn_aceptar = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "input[value='Aceptar']")))
                                btn_aceptar.click()
                                time.sleep(2)
                                
                                # 5. Alerta confirmación
                                WebDriverWait(driver, 5).until(EC.alert_is_present())
                                driver.switch_to.alert.accept()
                                logger.info("Confirmación 'Esta Seguro' aceptada.")
                                time.sleep(2)

                            except Exception as e_pop:
                                logger.error(f"Error dentro del popup: {e_pop}")
                                driver.close() # Asegurar cierre si falla

                            # Regreso a ventana principal
                            driver.switch_to.window(main_window)
                            driver.switch_to.default_content()
                            wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
                            logger.info("Regreso a ventana principal exitoso. Continuando flujo estándar...")

                        else:
                            logger.warning("No se encontró nueva ventana para el popup.")
                    else:
                        logger.info("Link 'Servicio Especial' NO detectado. Continuando.")

                except Exception as e_dyn:
                    logger.warning(f"Error en lógica dinámica/popup: {e_dyn}")

                # ────────────────────────────────────────────────────────
                # PASO 2 a 10: LÓGICA COMÚN
                # ────────────────────────────────────────────────────────
                combo_tipo = wait.until(EC.element_to_be_clickable((By.ID, "cod_tipliqID")))
                Select(combo_tipo).select_by_value("1")
                time.sleep(2)

                combo_calculo = wait.until(EC.element_to_be_clickable((By.ID, "ind_calcul0")))
                Select(combo_calculo).select_by_value("2")
                time.sleep(2)

                # Valor ya calculado arriba (hoisted)

                logger.info(f"Escribiendo VALOR TURNO: {valor_turno_final}")
                campo_turno = wait.until(EC.element_to_be_clickable((By.ID, "val_unitar0")))
                campo_turno.clear()
                campo_turno.send_keys(Keys.CONTROL + "a")
                campo_turno.send_keys(Keys.DELETE)
                campo_turno.send_keys(valor_turno_final)
                time.sleep(0.5)
                campo_turno.send_keys(Keys.TAB)
                time.sleep(1)

                # ────────────────────────────────────────────────────────
                # PASO: CANTIDADES (can_mercan0 y can_descar0) -> DEFAULT 1
                # ────────────────────────────────────────────────────────
                try:
                    # 1. Campo Cantidad Mercancia (can_mercan0)
                    caja_mercan = driver.switch_to.active_element 
                    # Intento robusto de asegurar que estamos en el campo correcto, si no buscar por ID
                    if caja_mercan.get_attribute("id") != "can_mercan0":
                         caja_mercan = driver.find_element(By.ID, "can_mercan0")
                    
                    val_mercan = caja_mercan.get_attribute("value").strip()
                    if val_mercan in ["0", "0.000", ""]:
                        caja_mercan.clear()
                        caja_mercan.send_keys("1")
                    
                    caja_mercan.send_keys(Keys.TAB)
                    time.sleep(0.5)

                    # 2. Campo Cantidad Descargada (can_descar0)
                    # User instruction: FORCE to 1
                    caja_descar = driver.switch_to.active_element
                    if caja_descar.get_attribute("id") != "can_descar0":
                         caja_descar = driver.find_element(By.ID, "can_descar0")

                    caja_descar.clear()
                    caja_descar.send_keys("1")
                    caja_descar.send_keys(Keys.TAB)
                    time.sleep(0.5)
                except Exception as e_cant:
                    logger.warning(f"Error ajustando cantidades a 1: {e_cant}")

                # ────────────────────────────────────────────────────────
                # PASO: BOTÓN TOTAL INICIAL
                # ────────────────────────────────────────────────────────
                try:
                    boton_total = wait.until(EC.element_to_be_clickable((By.ID, "btn_totalx")))
                    boton_total.click()
                    logger.info("Clic en 'Total a Pagar' (Inicial)")
                except Exception:
                    logger.warning("No se pudo clickear btn_totalx por ID, intentando TAB...")
                    driver.switch_to.active_element.send_keys(Keys.TAB) 
                    time.sleep(0.5)
                    driver.switch_to.active_element.click()

                time.sleep(2)
                try:
                    WebDriverWait(driver, 5).until(EC.alert_is_present())
                    driver.switch_to.alert.accept()
                    logger.info("✅ Alerta nativa aceptada.")
                    time.sleep(2)
                except Exception:
                    pass

                # ────────────────────────────────────────────────────────
                # PASO: LIMPIEZA DE CONCEPTOS OPCIONALES (Peajes, Cargue, Cruce)
                # ────────────────────────────────────────────────────────
                # IDs a desmarcar SIEMPRE (Propios y Terceros):
                # 1=Peajes, 2=Cargue/Des, 3=Cruce
                conceptos_ids = ["ind_concep1ID", "ind_concep2ID", "ind_concep3ID"]
                
                for c_id in conceptos_ids:
                    try:
                        chk_opt = driver.find_elements(By.ID, c_id)
                        if chk_opt and chk_opt[0].is_displayed():
                            if chk_opt[0].is_selected():
                                chk_opt[0].click()
                                logger.info(f"Checkbox opcional {c_id} DESMARCADO.")
                                time.sleep(1) # Retardo solicitado
                    except Exception:
                        pass
                
                # ────────────────────────────────────────────────────────
                # PASO: Validar Póliza (ind_concep4ID) si valor es 0 en Excel
                # ────────────────────────────────────────────────────────
                try:
                    # Log para depuración
                    raw_poliza = str(row.get("Suma de Poliza Politrayecto", "0")).strip().lower() # Convertir a minúsculas una vez
                    logger.info(f"DEBUG: Valor 'Suma de Poliza Politrayecto' en Excel (raw): '{raw_poliza}'")
                    
                    es_cero = False
                    
                    # 1. Chequeo directo de nulos/vacíos
                    if not raw_poliza or raw_poliza in ["nan", "none", "", "null"]:
                        es_cero = True
                    else:
                        # 2. Chequeo numérico
                        try:
                            val_float = float(raw_poliza)
                            if val_float == 0:
                                es_cero = True
                        except ValueError:
                            pass # No es número ni es nulo conocido (ej: "texto"), asumimos valor presente (no 0)

                    if es_cero:
                        chk_poliza = driver.find_elements(By.ID, "ind_concep4ID")
                        if chk_poliza:
                            # Asegurar visibilidad (Scroll)
                            driver.execute_script("arguments[0].scrollIntoView(true);", chk_poliza[0])
                            time.sleep(1)

                            # Esperar a que sea clicleable
                            chk_clickable = wait.until(EC.element_to_be_clickable((By.ID, "ind_concep4ID")))
                            
                            if chk_clickable.is_selected():
                                logger.info("Detectado Póliza seleccionado y valor 0. Desmarcando...")
                                chk_clickable.click()
                                time.sleep(1)
                                
                                # Verificación
                                if chk_clickable.is_selected():
                                    logger.warning("El checkbox Póliza sigue marcado tras el clic. Intentando de nuevo...")
                                    chk_clickable.click()
                                    time.sleep(1)
                                else:
                                    logger.info("Checkbox Póliza (ind_concep4ID) DESMARCADO exitosamente.")
                            else:
                                logger.info("Checkbox Póliza ya estaba desmarcado.")
                        else:
                            logger.warning("No se encontró elemento 'ind_concep4ID' en el DOM.")
                    else:
                        logger.info(f"NO se desmarca Póliza porque valor no es 0 (Valor: {raw_poliza})")

                except Exception as e_pol:
                    logger.warning(f"Error verificando póliza: {e_pol}")

                # ────────────────────────────────────────────────────────
                # PASO 13: Verificación Saldo Final (DIFERENCIADO)
                # ────────────────────────────────────────────────────────
                saldo_ok = False
                try:
                    time.sleep(2)
                    if es_propio:
                        val_tot = driver.find_element(By.ID, "tot_liquidID").get_attribute("value")
                        saldo_final = float(val_tot.replace(",", "").replace("$", "").strip())
                        if abs(saldo_final) <= 10:
                            saldo_ok = True
                            logger.info("✅ Saldo OK (Cero).")
                        else:
                            logger.warning(f"⚠️ Saldo irregular: {saldo_final}")
                    else:
                        logger.info("Vehículo TERCERO: Omitiendo validación de saldo cero.")
                        saldo_ok = True
                except Exception:
                    logger.error("Error leyendo saldo final.")
                    if not es_propio:
                        saldo_ok = True

                # ────────────────────────────────────────────────────────
                # PASO 14: Guardar y manejo de bloqueo modal
                # ────────────────────────────────────────────────────────
                if saldo_ok:
                    logger.info("Guardando liquidación (Clic en Aceptar)...")
                    try:
                        boton_aceptar = wait.until(
                            EC.element_to_be_clickable((By.CSS_SELECTOR, "input[value='Aceptar'].styleButton_"))
                        )
                        boton_aceptar.click()

                        modal_alerta = wait.until(
                            EC.visibility_of_element_located((By.CSS_SELECTOR, "div.sweet-alert.showSweetAlert"))
                        )

                        try:
                            titulo_modal = modal_alerta.find_element(By.TAG_NAME, "h2").text
                        except Exception:
                            titulo_modal = ""

                        if "Imposible Continuar" in titulo_modal:
                            try:
                                mensaje_error = modal_alerta.find_element(By.TAG_NAME, "p").text
                            except Exception:
                                mensaje_error = "Mensaje no legible"

                            logger.warning(f"⛔ BLOQUEO DETECTADO: {mensaje_error}")

                            boton_ok = modal_alerta.find_element(By.CSS_SELECTOR, "button.confirm")
                            boton_ok.click()
                            time.sleep(2)

                            logger.info("Clic en 'Volver' para intentar siguiente registro...")
                            try:
                                boton_volver = wait.until(
                                    EC.element_to_be_clickable(
                                        (By.CSS_SELECTOR, "input[value='Volver'].styleButton_")
                                    )
                                )
                                boton_volver.click()
                                time.sleep(3)
                            except Exception as e_volver_err:
                                logger.error(f"Error al volver tras bloqueo: {e_volver_err}")

                            continue
                        else:
                            logger.info("Modal de confirmación detectado.")
                            boton_si = modal_alerta.find_element(By.CSS_SELECTOR, "button.confirm")
                            time.sleep(2)
                            boton_si.click()
                            logger.info("✅ Confirmado 'Si'. Esperando...")
                            time.sleep(4)

                            logger.info("Buscando botón 'Volver'...")
                            try:
                                boton_volver = wait.until(
                                    EC.element_to_be_clickable(
                                        (By.CSS_SELECTOR, "input[value='Volver'].styleButton_")
                                    )
                                )
                                time.sleep(2)
                                boton_volver.click()
                                logger.info("Clic en 'Volver' exitoso.")
                                time.sleep(3)
                            except Exception as e_volver:
                                logger.error(f"No se pudo volver: {e_volver}")

                    except Exception as e_save:
                        logger.error(f"Error en proceso de guardado/modal: {e_save}")
                        guardar_html_error("error_save_modal.html", driver, logger)
                else:
                    logger.warning(f"⛔ Manifiesto {manifiesto} NO se guardó por saldo incorrecto (Solo Propios).")

            except Exception as e_row:
                logger.error(f"Error procesando fila {index}: {e_row}")
                guardar_html_error(f"error_general_{manifiesto}.html", driver, logger)

    finally:
        logger.info("Finalizando proceso de liquidaciones (driver permanece abierto para otros módulos).")
