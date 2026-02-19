# 🛡️ Sistema de Control de Tráfico y Seguridad (Access VBA)

## 📋 Descripción General
Este aplicativo está especializado en la gestión de **Riesgos y Seguridad Patrimonial**. Permite al equipo de Seguridad monitorear la flota, gestionar dispositivos de rastreo satelital y registrar novedades críticas durante los desplazamientos de la carga.

Su función principal es servir como "Torre de Control", centralizando la información de monitoreo de vehículos propios y terceros, y gestionando alertas de seguridad (botones de pánico, paradas no autorizadas, apertura de candados satelitales).

## 🏗️ Integración
Se integra directamente con el ecosistema P&P:
- **Base de Datos:** Lee y escribe en MySQL (`pypdb`).
- **Vinculación:** Se alimenta de los datos de despacho generados en el módulo de **Operaciones**.

## 📂 Componentes Principales

### 1. 🛰️ Gestión de Rastreo y Activos
- **Candados Satelitales:**
  - `Form_Candados_Satelitales.cls`: Inventario y asignación de candados electrónicos a vehículos.
- **Botones de Pánico:**
  - `Form_Botones_Panico.cls`: Registro y gestión de alertas emitidas por conductores.

### 2. 📝 Bitácora de Tráfico
- `Form_Bitacora_Trafico.cls`: Módulo central donde el analista de tráfico registra el seguimiento "Punto a Punto" (Checkpoints) de cada viaje, documentando ubicación, estado y novedades.

### 3. 🏍️ Gestión de Terceros y Escoltas
- `Form_Vehiculos_Terceros.cls`: Validación de seguridad para vehículos externos antes de carga.
- `Form_Gestion_motos_Terceros.cls` y `Form_Dlg_AgregarPersonaAMoto.cls`: Administración de escoltas motorizados y vehículos acompañantes.
- `Form_Auxiliar_Tercero.cls`: Registro rápido de personal de apoyo.

### 4. 📊 Actividades y Reportes
- `Form_Actividades_Operacion.cls`: Registro de tareas de seguridad específicas por operación.
- `Form_Informe_Estatus_Planta.cls`: Reportes de disponibilidad de flota segura.

## 🚀 Flujo de Seguridad
1. **Validación:** Antes del despacho, Seguridad verifica antecedentes de vehículos terceros (`Form_Vehiculos_Terceros`).
2. **Asignación:** Se asignan elementos de seguridad como candados satelitales (`Form_Candados_Satelitales`).
3. **Monitoreo:** Durante el viaje, se registran reportes de puesto de control en la `Bitacora_Trafico`.
4. **Reacción:** Si se activa una alerta, se gestiona desde `Botones_Panico`.

## ⚙️ Requisitos Técnicos
- Access 2016+
- Conexión ODBC a MySQL.
- Acceso a bases de datos de proveedores de GPS (Si aplica integración directa).

---
**Desarrollado por:** Juan Saavedra
