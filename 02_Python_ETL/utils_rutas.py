# utils_rutas.py
import sys
from pathlib import Path

def resource_path(relative_path: str = "") -> Path:
    """
    Devuelve la ruta absoluta a un recurso (ej: .env, carpetas de datos).
    Compatible con ejecución normal (.py) y con PyInstaller (.exe).
    """
    if getattr(sys, "frozen", False):
        # Si corre como .exe compilado
        base_path = Path(sys.executable).parent
    else:
        # Si corre como script .py en desarrollo
        base_path = Path(__file__).parent
    return base_path / relative_path
