# utils_rutas.py
import sys
from pathlib import Path

def resource_path(relative_path: str = "") -> Path:
    if getattr(sys, "frozen", False):
        base_path = Path(sys.executable).parent
    else:
        base_path = Path(__file__).parent
    return base_path / relative_path

def work_path(relative_path: str = "") -> Path:
    # por ahora igual que resource_path (luego en GUI se hace configurable)
    if getattr(sys, "frozen", False):
        base_path = Path(sys.executable).parent
    else:
        base_path = Path(__file__).parent
    return base_path / relative_path


