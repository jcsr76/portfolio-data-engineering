# orquestador.py
import os

from logger_config import configurar_logger
from utils_rutas import work_path

from excel_io import contar_registros
from avansat_login import login_avansat
from liquidaciones_manifiestos_avansat import procesar_cierres_y_facturacion
from liquidaciones_servicios_especiales import procesar_servicios_especiales
from prefacturas_avansat import procesar_prefacturas
from actualizar_factura import procesar_actualizar_facturas  # <-- NUEVO


def ejecutar(excel_path: str, usuario: str, clave: str, progress_cb=None, ver_navegador: bool = False) -> dict:
    """
    Ejecuta el flujo completo:
      1) Login AVANSAT
      2) Liquidaciones manifiestos
      3) Servicios especiales
      4) Prefacturas
      5) Actualizar factura (adición remesas)

    progress_cb esperado:
        progress_cb(done_global:int, total_global:int, etapa:str)

    Retorna un dict con ok/log_file/error (si aplica) para que la GUI pueda reaccionar.
    """
    # 1) Preparar carpetas de trabajo
    work_path("logs").mkdir(parents=True, exist_ok=True)
    work_path("debug").mkdir(parents=True, exist_ok=True)
    work_path("temp_folder").mkdir(parents=True, exist_ok=True)

    # 2) Logger único de corrida (sobrescribe cada vez)
    log_file = str(work_path("logs/run.log"))
    logger = configurar_logger("run", log_file)

    # 3) Carpeta de descargas de Chrome (Selenium)
    ruta_descarga = str(work_path("temp_folder"))
    os.makedirs(ruta_descarga, exist_ok=True)

    # 4) Total global (manifiestos + servicios especiales + prefacturas + actualizar_facturas)
    try:
        conteo = contar_registros(excel_path)
        total_global = (
            int(conteo["manifiestos"])
            + int(conteo["servicios_especiales"])
            + int(conteo["prefacturas"])
            + int(conteo.get("actualizar_facturas", 0))
        )
    except Exception as e:
        logger.error(f"No se pudo leer/validar el Excel para conteo: {e}")
        return {"ok": False, "log_file": log_file, "error": str(e)}

    done_global = 0
    last_done_mod = 0

    def progress_global(done_mod: int, total_mod: int, etapa: str):
        """
        Recibe progreso por módulo (done_mod reinicia en cada módulo).
        Lo transforma a progreso global acumulado.
        """
        nonlocal done_global, last_done_mod, total_global

        if done_mod >= last_done_mod:
            delta = done_mod - last_done_mod
        else:
            delta = done_mod
        last_done_mod = done_mod
        done_global += delta

        if progress_cb:
            progress_cb(done_global, total_global, etapa)

    driver = None
    try:
        logger.info("=== Orquestador AVANSAT ===")
        logger.info(f"Excel seleccionado: {excel_path}")
        logger.info(f"Total a procesar (global): {total_global}")

        if progress_cb:
            progress_cb(0, total_global, "Iniciando...")

        logger.info("Iniciando login AVANSAT...")
        driver, wait = login_avansat(
            ruta_descarga,
            usuario,
            clave,
            logger=logger,
            ver_navegador=ver_navegador
        )

        # ── MÓDULO 1 ─────────────────────────────────────────────────
        last_done_mod = 0
        logger.info("Iniciando módulo: Liquidaciones Manifiestos...")
        procesar_cierres_y_facturacion(
            driver,
            wait,
            excel_path=excel_path,
            logger=logger,
            progress_cb=progress_global,
        )

        # ── MÓDULO 2 ─────────────────────────────────────────────────
        last_done_mod = 0
        logger.info("Iniciando módulo: Servicios Especiales...")
        procesar_servicios_especiales(
            driver,
            wait,
            excel_path=excel_path,
            logger=logger,
            progress_cb=progress_global,
        )

        # ── MÓDULO 3 ─────────────────────────────────────────────────
        last_done_mod = 0
        logger.info("Iniciando módulo: Prefacturas...")
        procesar_prefacturas(
            driver,
            wait,
            excel_path=excel_path,
            logger=logger,
            progress_cb=progress_global,
        )

        # ── MÓDULO 4 ─────────────────────────────────────────────────
        last_done_mod = 0
        logger.info("Iniciando módulo: Actualizar Factura (Adición Remesas)...")
        procesar_actualizar_facturas(
            driver,
            wait,
            excel_path=excel_path,
            logger=logger,
            progress_cb=progress_global,
        )

        logger.info("Proceso completo finalizado.")
        if progress_cb:
            progress_cb(total_global, total_global, "Finalizado")

        return {"ok": True, "log_file": log_file}

    except Exception as e:
        logger.error(f"Fallo ejecución: {e}")
        return {"ok": False, "log_file": log_file, "error": str(e)}

    finally:
        try:
            if driver is not None:
                driver.quit()
                logger.info("Driver cerrado.")
        except Exception:
            pass


def main():
    # Solo para pruebas por consola (la GUI NO usará input())
    print("=== Orquestador AVANSAT (modo consola) ===\n")
    excel_path = input("Ruta del Excel: ").strip()
    usuario = input("Usuario AVANSAT: ").strip()
    clave = input("Contraseña AVANSAT: ").strip()

    def cb(done, total, etapa):
        pct = int((done / total) * 100) if total else 0
        print(f"[{pct:3d}%] {done}/{total} - {etapa}")

    resultado = ejecutar(excel_path, usuario, clave, progress_cb=cb, ver_navegador=False)
    print(resultado)


if __name__ == "__main__":
    main()
