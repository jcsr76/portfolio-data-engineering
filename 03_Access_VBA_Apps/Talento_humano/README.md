# 👔 Sistema de Gestión de Talento Humano (Access VBA)

## 📋 Descripción General
Esta aplicación de escritorio, desarrollada en **Microsoft Access con VBA (Visual Basic for Applications)**, sirve como interfaz de usuario (Front-End) para la gestión integral del departamento de Talento Humano. 

El sistema permite la administración del ciclo de vida de los colaboradores, desde su ingreso y contratación hasta el control de novedades, dotación y reportes. Se conecta a una base de datos externa (MySQL) para persistir la información, asegurando centralización y seguridad de los datos.

## 🏗️ Arquitectura del Proyecto

El proyecto sigue una arquitectura **Cliente-Servidor**:
- **Front-End:** Microsoft Access (Formularios e Informes + Lógica VBA).
- **Back-End:** MySQL (Alojado en servidor, esquema `pypdb`).
- **Conexión:** ODBC / ADO (Gestionado por módulos VBA).

## 📂 Estructura del Código

El código fuente exportado se organiza en Clases (Lógica de Formularios) y Módulos Estándar.

### 1. 🖥️ Formularios Principales (Lógica de UI)
Los archivos `Form_*.cls` contienen la lógica de eventos y validaciones de las interfaces de usuario:

- **Gestión de Colaboradores:**
  - `Form_Registrar_Ingreso_Colaborador.cls`: Pantalla principal para nuevas contrataciones.
  - `Form_Actualizar_Datos_Colaborador.cls`: Edición de información existente.
  - `Form_Control_Estatus_Colaborador.cls`: Gestión de estados (Activo, Retirado, Vacaciones).
  - `Form_Registrar_Beneficiarios_Colaborador.cls`: Administración del núcleo familiar.

- **Contratación y Nómina:**
  - `Form_Registro_Contrato_Colaborador.cls`: Detalles contractuales.
  - `Form_Registro_DatosBancarios_Colaborador.cls`: Cuentas para dispersión de nómina.
  - `Form_Parametros_Nomina.cls`: Configuración de variables globales de liquidación.

- **Dotación e Inventario:**
  - `Form_Registro_Tallas_Colaborador.cls`: Tallas de uniforme por empleado.
  - `Form_Registrar_Entrega_Dotacion.cls` y `Form_Registrar_Ingreso_Inv_Dotacion.cls`: Control de stock y asignaciones.

- **Reportes e Informes:**
  - `Form_Informe_Planta_PYP.cls` y `Form_Informe_Estatus_Planta.cls`: Generación de listados de personal y métricas.
  - `Form_Reportes.cls`: Menú centralizado de informes.

### 2. 🧩 Subformularios (Componentes Reutilizables)
Componentes integrados en formularios principales para mostrar listas o detalles relacionados:
- `Form_subform_DatosPersonales.cls`
- `Form_subform_ContratoColaborador_NUEVO.cls`
- `Form_subform_SeguridadSocial.cls`
- `Form_subform_DatosContacto.cls`

### 3. 🛠️ Módulos Estándar (Lógica Compartida)
Archivos `*.bas` con funciones transversales:

- **`Globales.bas`**: Variables de aplicación, usuario actual, permisos y constantes del sistema.
- **`modEntornoServerMySQL.bas`**: Cadenas de conexión y configuración para el acceso a la base de datos MySQL.
- **`modControlInterfaz.bas`**: Funciones para manipular la UI (ocultar/mostrar menús, estilos visuales, navegación).
- **`modUtils.bas`**: Funciones auxiliares genéricas (formato de fechas, validaciones de texto, cálculos simples).
- **`modFuncionesHoras.bas`**: Cálculos específicos para gestión de tiempos.

## 🚀 Funcionalidades Clave
1. **Hoja de Vida Digital:** Centraliza datos personales, contacto, seguridad social y bancarios.
2. **Control de Dotación:** Kardex de inventario y registro de entregas por talla.
3. **Gestión Contractual:** Histórico de contratos y actualizaciones.
4. **Reportes en Tiempo Real:** Visualización directa de la data operativa almacenada en MySQL.

## ⚙️ Requisitos para Ejecución
- Microsoft Access 2016 o superior (32/64 bits según driver ODBC).
- Controlador ODBC para MySQL instalado en la máquina cliente.
- Acceso de red al servidor de base de datos MySQL.

---
**Desarrollado por:** Juan Saavedra
