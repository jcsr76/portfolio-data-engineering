# buscar_y_extraer_tabla.py  (versión con limpieza + exportación a C:\temp)
import os, time
from datetime import datetime

from avansat_login import login_avansat
from bs4 import BeautifulSoup
from logger_config import configurar_logger
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
import pandas as pd           # pip install pandas beautifulsoup4 lxml html5lib openpyxl

# ────────────────────────────────────────────────────────────────
# 1.  Exportar siempre en C:\temp
# ────────────────────────────────────────────────────────────────
def guardar_df_en_c_temp(df, nombre_base="vehiculos"):
    ruta_temp = r"C:\temp"
    if not os.path.exists(ruta_temp):
        os.makedirs(ruta_temp)

    ts   = datetime.now().strftime("%Y%m%d_%H%M%S")
    ruta = os.path.join(ruta_temp, f"{nombre_base}_{ts}.xlsx")

    df.to_excel(ruta, index=False)     # engine=openpyxl por defecto
    print(f"Excel exportado en: {ruta}")
    return ruta

# ────────────────────────────────────────────────────────────────
# 2.  Limpiar DataFrame: quitar filas basura y usar encabezado real
# ────────────────────────────────────────────────────────────────
def limpiar_df_vehiculos(df_original):
    """
    El HTML trae:
      • 8 filas basura (“Resultado de la Consulta”, huecos…)
      • encabezados reales en la fila 9 (índice 8)
      • 1 fila vacía justo después de los encabezados
    """
    df = df_original.iloc[8:].copy()        # descarta las 8 primeras filas
    df = df.drop(df.index[1])               # elimina la fila vacía
    df.columns = df.iloc[0]                 # usa fila 0 como header
    df = df.drop(df.index[0]).reset_index(drop=True)
    df = df.replace('', pd.NA)              # normaliza vacíos
    return df

# ────────────────────────────────────────────────────────────────
# 3.  Configuración de log y Selenium
# ────────────────────────────────────────────────────────────────
logger       = configurar_logger("log_EXTRAER_TABLA")
carpeta_html = os.path.join(os.getcwd(), "vehiculos_html_completo")
os.makedirs(carpeta_html, exist_ok=True)

driver, wait = login_avansat(carpeta_html)
df = None
try:
    # Menú lateral: Recursos ➜ Vehículos ➜ Listar
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "menuFrame")))
    wait.until(EC.element_to_be_clickable((By.ID, "385ID"))).click(); time.sleep(1)
    wait.until(EC.element_to_be_clickable((By.ID, "715ID"))).click(); time.sleep(1)
    wait.until(EC.element_to_be_clickable((By.ID, "131ID"))).click()

    # centralFrame → Buscar → “Sí”
    driver.switch_to.default_content()
    wait.until(EC.frame_to_be_available_and_switch_to_it((By.NAME, "centralFrame")))
    wait.until(EC.element_to_be_clickable((By.ID, "buscarID"))).click()
    wait.until(EC.element_to_be_clickable(
        (By.XPATH, "//div[contains(@class,'sweet-alert') and contains(@class,'visible')]//button[text()='Si']"))
    ).click()

    # ── localizar tabla cuyo 1.º encabezado es “Placa”
    soup   = BeautifulSoup(driver.page_source, "lxml")
    tabla  = next(
        (t for t in soup.find_all("table")
         if (t.find("label") or t.find("th")) and "Placa" in (t.find("label") or t.find("th")).get_text()),
        None
    )
    if tabla is None:
        raise RuntimeError("No se halló la tabla con encabezado 'Placa'.")

    # ── convertir y LIMPIAR
    df_raw  = pd.read_html(str(tabla))[0]
    df      = limpiar_df_vehiculos(df_raw)
    logger.info(f"DataFrame final: {df.shape}")
    print(df.head())

finally:
    if df is not None:
        guardar_df_en_c_temp(df, "vehiculos")
    driver.quit()
    logger.info("Navegador cerrado")
