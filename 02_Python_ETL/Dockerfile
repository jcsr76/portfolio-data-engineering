FROM python:3.12-slim

WORKDIR /app

# 1) Instalar Chromium + ChromeDriver y librerías necesarias
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    ca-certificates \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# 2) Instalar dependencias Python
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# 3) Copiar tu aplicación
COPY . /app

# 4) Ejecutar ETL
CMD ["python", "ETL_Main.py"]

