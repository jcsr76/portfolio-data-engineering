# conexion_mysql.py

import os
import socket
import time
import uuid
import subprocess
from pathlib import Path

import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv

from logger_config import configurar_logger


BASE_DIR = Path(__file__).parent.resolve()
DOTENV_PATH = BASE_DIR / "python" / ".env"

load_dotenv(DOTENV_PATH, override=True)


def obtener_ip_local():
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "Desconocida"


def obtener_mac_local():
    try:
        mac = uuid.getnode()
        return ":".join(["{:02x}".format((mac >> i) & 0xFF) for i in range(40, -8, -8)])
    except Exception:
        return "Desconocida"


def _tcp_check(host: str, port: int, timeout_s: int = 3) -> bool:
    """Prueba rápida de alcance TCP a host:port."""
    try:
        with socket.create_connection((host, port), timeout=timeout_s):
            return True
    except Exception:
        return False


def _ping_once_windows(host: str, timeout_ms: int = 1200) -> bool:
    """
    Ping 1 paquete en Windows.
    -n 1 = un eco
    -w timeout(ms) = tiempo de espera por respuesta [web:422]
    """
    try:
        cmd = ["ping", "-n", "1", "-w", str(timeout_ms), host]
        p = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return p.returncode == 0
    except Exception:
        return False


def _wakeup_ping(host: str, logger, intentos: int = 12, espera_s: int = 2, timeout_ms: int = 1200):
    """
    Wakeup con ping:
    - Se detiene al primer OK (prioriza velocidad).
    - Loguea cuántos intentos tomó obtener el primer OK.
    - Si ninguno responde, también lo deja en logs (pero NO aborta aquí).
    """
    primer_ok_en = None

    for i in range(1, intentos + 1):
        ping_ok = _ping_once_windows(host, timeout_ms=timeout_ms)
        logger.info(f"Wakeup ping {i}/{intentos}: {'OK' if ping_ok else 'FAIL'}")

        if ping_ok:
            primer_ok_en = i
            break

        if i < intentos:
            time.sleep(espera_s)

    if primer_ok_en is None:
        logger.info(f"Wakeup ping resumen: 0/{intentos} OK (host={host})")
    else:
        logger.info(f"Wakeup ping resumen: primer OK en intento {primer_ok_en}/{intentos} (host={host})")


def conectar_mysql(logger_name="log_general"):
    """
    Establece y retorna una conexión a MySQL usando variables del .env.
    También define @usuario_actual y registra IP/MAC en log_conexiones.

    Flujo:
    0) Wakeup ping (rápido; se detiene al primer OK).
    1) Precheck TCP 3306 con reintentos (gate real).
    2) Conexión MySQL con connection_timeout y reintentos. [web:241][web:238]
    """
    logger = configurar_logger(logger_name)

    host = os.getenv("MYSQL_HOST")
    port_raw = os.getenv("MYSQL_PORT")
    user = os.getenv("MYSQL_USER")
    db = os.getenv("MYSQL_DB")
    pwd = os.getenv("MYSQL_PASS")

    if not host or not port_raw or not user or not db:
        logger.error(
            "❌ Variables MySQL incompletas. Verifica python/.env. "
            f"MYSQL_HOST={host} MYSQL_PORT={port_raw} MYSQL_USER={user} MYSQL_DB={db} "
            f"(DOTENV_PATH={DOTENV_PATH})"
        )
        return None

    try:
        port = int(port_raw)
    except ValueError:
        logger.error(f"❌ MYSQL_PORT inválido: {port_raw} (DOTENV_PATH={DOTENV_PATH})")
        return None

    logger.info(f"MySQL destino => host={host} port={port} db={db} user={user}")

    # ------------------------------------------------------------
    # 0) Wakeup ping (NO determinante)
    # ------------------------------------------------------------
    _wakeup_ping(host, logger, intentos=12, espera_s=2, timeout_ms=1200)

    # ------------------------------------------------------------
    # 1) Precheck TCP (determinante)
    # ------------------------------------------------------------
    max_intentos_tcp = 8
    for intento in range(1, max_intentos_tcp + 1):
        tcp_ok = _tcp_check(host, port, timeout_s=3)
        if tcp_ok:
            logger.info(f"✅ Precheck TCP OK: {host}:{port} (intento {intento}/{max_intentos_tcp})")
            break

        logger.warning(f"⚠️ Precheck TCP falló: {host}:{port} (intento {intento}/{max_intentos_tcp})")
        if intento < max_intentos_tcp:
            time.sleep(5)
    else:
        logger.error(f"❌ No hay alcance TCP hacia {host}:{port}. Abortando conexión MySQL.")
        return None

    # ------------------------------------------------------------
    # 2) Conexión MySQL con reintentos
    # ------------------------------------------------------------
    delays = [0, 5, 15]
    last_err = None

    for idx, delay_s in enumerate(delays, start=1):
        if delay_s:
            logger.warning(f"Reintentando conexión MySQL en {delay_s}s (intento {idx}/{len(delays)})...")
            time.sleep(delay_s)

        try:
            logger.info("Estableciendo Conexión a MySQL...")

            conexion = mysql.connector.connect(
                host=host,
                port=port,
                user=user,
                password=pwd,
                database=db,
                connection_timeout=10,  # evita “pegues” [web:241][web:238]
            )

            if not conexion.is_connected():
                logger.error("❌ mysql.connector.connect() devolvió conexión no activa.")
                last_err = "is_connected()=False"
                continue

            logger.info("✅ Conexión exitosa a MySQL")

            usuario_actual = user
            ip_origen = obtener_ip_local()
            mac_origen = obtener_mac_local()
            logger.info(f"📡 IP: {ip_origen}, MAC: {mac_origen}")

            cursor = conexion.cursor()

            cursor.execute("SELECT DATABASE()")
            db_real = cursor.fetchone()[0]
            logger.info(f"MySQL DATABASE() => {db_real}")

            cursor.execute("SET @usuario_actual = %s", (usuario_actual,))
            cursor.callproc("registrar_log_conexion", (usuario_actual, ip_origen, mac_origen))
            conexion.commit()
            cursor.close()

            return conexion

        except Error as e:
            last_err = e
            logger.error(f"❌ Error al conectar a MySQL (intento {idx}/{len(delays)}): {e}")

    logger.error(f"❌ No fue posible conectar a MySQL tras {len(delays)} intentos. Último error: {last_err}")
    return None
