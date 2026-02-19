# excel_io.py
import os
import pandas as pd

HOJA_MANIFIESTOS = "liquidaciones"
HOJA_SERVICIOS = "servicios especiales"
HOJA_PREFACTURAS = "prefacturas"

COL_MANIFIESTO = "Manifiesto"
COL_REMESA = "Remesa"

HOJA_ADICION_REMESAS = "adicion remesas"
COL_FACTURA = "FACTURA"
COL_FECHA_FACTURA = "FECHA FACTURA"
COL_REMESA_ADICION = "REMESA"


def _es_valido(valor) -> bool:
    v = str(valor).strip()
    return bool(v) and v.lower() != "nan"


def contar_registros(excel_path: str) -> dict:
    """
    Retorna la cantidad de registros procesables:
      - manifiestos: filas con columna 'Manifiesto' válida en hoja 'liquidaciones'
      - servicios_especiales: filas con columna 'Remesa' válida en hoja 'servicios especiales'
      - prefacturas: filas con columna 'Remesa' válida en hoja 'prefacturas'
      - actualizar_facturas: cantidad de grupos (FACTURA, FECHA FACTURA) en hoja 'adicion remesas'
    """
    if not excel_path or not os.path.exists(excel_path):
        raise FileNotFoundError(f"No existe el Excel: {excel_path}")

    # --- Manifiestos ---
    df_m = pd.read_excel(excel_path, sheet_name=HOJA_MANIFIESTOS, dtype=str)
    df_m.columns = df_m.columns.str.strip()

    if COL_MANIFIESTO not in df_m.columns:
        raise ValueError(f"Falta columna '{COL_MANIFIESTO}' en hoja '{HOJA_MANIFIESTOS}'")

    manifiestos = int(df_m[COL_MANIFIESTO].apply(_es_valido).sum())

    # --- Servicios especiales ---
    df_s = pd.read_excel(excel_path, sheet_name=HOJA_SERVICIOS, dtype=str)
    df_s.columns = df_s.columns.str.strip()

    if COL_REMESA not in df_s.columns:
        raise ValueError(f"Falta columna '{COL_REMESA}' en hoja '{HOJA_SERVICIOS}'")

    servicios_especiales = int(df_s[COL_REMESA].apply(_es_valido).sum())

    # --- Prefacturas ---
    df_p = pd.read_excel(excel_path, sheet_name=HOJA_PREFACTURAS, dtype=str)
    df_p.columns = df_p.columns.str.strip()

    if COL_REMESA not in df_p.columns:
        raise ValueError(f"Falta columna '{COL_REMESA}' en hoja '{HOJA_PREFACTURAS}'")

    prefacturas = int(df_p[COL_REMESA].apply(_es_valido).sum())

    # --- Actualizar factura (adicion remesas) ---
    actualizar_facturas = 0
    try:
        df_a = pd.read_excel(excel_path, sheet_name=HOJA_ADICION_REMESAS, dtype=str)
        df_a.columns = df_a.columns.str.strip()

        for col in (COL_FACTURA, COL_FECHA_FACTURA, COL_REMESA_ADICION):
            if col not in df_a.columns:
                raise ValueError(f"Falta columna '{col}' en hoja '{HOJA_ADICION_REMESAS}'")

        df_a = df_a[df_a[COL_FACTURA].apply(_es_valido) &
                    df_a[COL_FECHA_FACTURA].apply(_es_valido) &
                    df_a[COL_REMESA_ADICION].apply(_es_valido)]

        actualizar_facturas = int(df_a.groupby([COL_FACTURA, COL_FECHA_FACTURA]).ngroups)

    except ValueError as e:
        # Si la hoja no existe o el engine lanza ValueError, se deja en 0 para no romper el flujo.
        # Si quieres hacerlo estricto (obligar a que exista), elimina este try/except.
        actualizar_facturas = 0

    return {
        "manifiestos": manifiestos,
        "servicios_especiales": servicios_especiales,
        "prefacturas": prefacturas,
        "actualizar_facturas": actualizar_facturas,
    }
