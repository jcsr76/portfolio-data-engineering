-- ////////////////////////// Creación de BD P&P y tablas //////////////////////////
CREATE DATABASE IF NOT EXISTS pypdb;
USE pypdb;

-- Tabla Paises
CREATE TABLE IF NOT EXISTS paises(
	pais_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20)
);

-- Tabla Departamentos Pais
CREATE TABLE IF NOT EXISTS departamentos_col (
    departamento_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(250) NOT NULL,
    pais_id INT NOT NULL,
    
    CONSTRAINT fk_pais FOREIGN KEY (pais_id) REFERENCES paises(pais_id) 
);

-- Creación tabla ciudades
CREATE TABLE IF NOT EXISTS ciudades (
    id_ciudad INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    id_departamento INT NOT NULL,
    iata_abreviatura VARCHAR(5),
    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,
    
    CONSTRAINT fk_ciudad_depto FOREIGN KEY (id_departamento) REFERENCES departamentos_col(departamento_id) ON DELETE CASCADE
);

-- ////////////////////////// Creación tablas Compras //////////////////////////

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    contacto VARCHAR(100),
    telefono VARCHAR(20),
    email VARCHAR(100),
    descripcion VARCHAR(255)
);

-- /////////////////////// Creación de la tabla Bancos (ubicada acá para evitar errores al ejecutar el Script) //////////////////
CREATE TABLE IF NOT EXISTS bancos (
	banco_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_banco VARCHAR(250) NOT NULL
);

-- ////////////////////////// Creación tablas Talento Humano //////////////////////////

-- Creación tabla centro de costos
CREATE TABLE IF NOT EXISTS centro_costos (
	id_centro_costo INT AUTO_INCREMENT PRIMARY KEY,
    centro_costo VARCHAR(100) NOT NULL
);

-- Creación tabla departamentos o Áreas de PYP (Relación N:1 con colaboradores)
CREATE TABLE IF NOT EXISTS departamentos (
    departamento_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

-- Creación tabla roles
CREATE TABLE IF NOT EXISTS roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    cargo VARCHAR(100) NOT NULL,
    rol ENUM('Administrativa', 'Operativa') NOT NULL
);

-- Creación tabla Bases  REVISAR SI ESTA TABLA SE NECESITA
CREATE TABLE IF NOT EXISTS bases (
    id_base INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ciudad INT NOT NULL,
    tipo ENUM('Propia', 'En misión') NOT NULL,
    
    CONSTRAINT fk_ciudad_refermcia FOREIGN KEY (ciudad) REFERENCES ciudades(id_ciudad) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Creación tabla colaboradores
CREATE TABLE IF NOT EXISTS colaboradores (
    id_colaborador INT AUTO_INCREMENT PRIMARY KEY,
    tipo_id ENUM('CC', 'TI', 'CE', 'PA', 'PEP', 'PPT') NOT NULL,
    id_cc VARCHAR(20) NOT NULL UNIQUE,
    lugar_expedicion INT,
    fecha_expedicion DATE,
    primer_nombre VARCHAR(100) NOT NULL,
    segundo_nombre VARCHAR(100),
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100) NOT NULL,
    formacion_academica ENUM('Primaria', 'Bachillerato', 'Tecnico', 'Tecnologo', 'Pregrado', 'Especializacion', 'Postgrado', 'Maestria', 'Doctorado', 'No Disponible'),
    estado_formacion_academica ENUM('Termino', 'En curso', 'Incompleta', 'No Disponible'),
    fecha_nacimiento DATE,
    sexo VARCHAR(10),
    grupo_sanguineo ENUM('A', 'B', 'AB', 'O', 'N/D'),
    rh ENUM('+', '-', 'N/D'),
    estado_civil ENUM('soltero(a)', 'casado(a)', 'union libre', 'viudo(a)', 'divorciado(a)', 'No Disponible'),
    direccion VARCHAR(255),
    barrio VARCHAR(200),
    estrato VARCHAR(10),
    ciudad_nacimiento INT,
    departamento_nacimiento INT,
    pais_nacimiento INT,
    estatus_colaborador ENUM('Activo', 'Inactivo', 'Retirado') NOT NULL DEFAULT 'Activo',
    departamento INT,
    cargo INT,
    sede INT,
    planta VARCHAR(20),
    id_jefe INT,
    fecha_emo DATE,
    fecha_proximo_emo DATE NULL,
    fecha_elaboracion_carnet DATE NULL,
    ruta_induccion TINYINT DEFAULT 0,
    contacto_emergencia VARCHAR(150),
    telefono_contacto_emergencia VARCHAR(150),
    
    CONSTRAINT fk_colaboradores_departamento FOREIGN KEY (departamento)
        REFERENCES departamentos (departamento_id)
        ON DELETE SET NULL,
        
    CONSTRAINT fk_colaboradores_cargo FOREIGN KEY (cargo)
        REFERENCES roles (id_rol)
        ON DELETE SET NULL,
        
    CONSTRAINT fk_colaboradores_sede FOREIGN KEY (sede)
        REFERENCES ciudades (id_ciudad)
        ON DELETE SET NULL,
        
    CONSTRAINT fk_colaboradores_jefe FOREIGN KEY (id_jefe)
        REFERENCES colaboradores (id_colaborador)
        ON DELETE SET NULL,
        
    CONSTRAINT fk_colaboradores_lugar_expedicion FOREIGN KEY (lugar_expedicion)
        REFERENCES ciudades (id_ciudad)
        ON DELETE SET NULL,
        
    CONSTRAINT fk_colaboradores_ciudad_nacimiento FOREIGN KEY (ciudad_nacimiento)
        REFERENCES ciudades (id_ciudad)
        ON DELETE SET NULL
);

-- Creación tabla incapacidades
CREATE TABLE IF NOT EXISTS incapacidades (
    incapacidad_id INT PRIMARY KEY AUTO_INCREMENT,
    id_colaborador INT,
    fecha_inicio_incapacidad DATE NOT NULL,
    fecha_fin_incapacidad DATE NOT NULL,
    tipo_tratamiento ENUM('Origen común', 'Origen laboral') NOT NULL,
    
    CONSTRAINT fk_incapacidad FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador) ON DELETE CASCADE
);

-- Tabla Datos Bancarios Colaboradores
CREATE TABLE IF NOT EXISTS cuentas_bancarias_colaboradores (
	cuenta_id INT PRIMARY KEY AUTO_INCREMENT,
    id_colaborador INT NOT NULL,
    banco_id INT NOT NULL,
    tipo_cuenta ENUM ('Ahorros', 'Corriente'),
    num_cuenta VARCHAR(100) NOT NULL,
    cta_contable_banco VARCHAR(50),
    
    CONSTRAINT fk_banco FOREIGN KEY (banco_id) REFERENCES bancos(banco_id),
    
    CONSTRAINT fk_colaborador_ban FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
);

-- Creación de la tabla contratos
CREATE TABLE IF NOT EXISTS contratos (
    id_contrato INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    fecha_ingreso DATE NOT NULL,
    tipo_contrato ENUM('Indefinido','Obra o Labor','Aprendizaje','Termino fijo','Obra o Labor - Medio Tiempo', 'Aprendizaje - Medio Tiempo'),
    termino_meses DATE,
    forma_pago ENUM('Mensual','Quincenal','Semanal','Diario') NOT NULL,
    id_centro_costo INT NOT NULL,
    salario_base DECIMAL(12,2) NOT NULL,
    aux_alimentacion DECIMAL(12,2) DEFAULT 0.00,
    aux_transporte DECIMAL(12,2) DEFAULT 0.00,
    salario_integral TINYINT NOT NULL DEFAULT 0,
    rodamiento DECIMAL(12,2) DEFAULT 0.00,
    turno VARCHAR(50) NOT NULL,
    contrato TINYINT NOT NULL DEFAULT 0, 
    fecha_afiliacion_arl DATE,
    fecha_afiliacion_eps DATE,
    fecha_afiliacion_ccf DATE,
    num_ultimo_otro_si INT,
    contrato_vigente TINYINT NOT NULL DEFAULT 1,
    dias_pp  INT NULL DEFAULT NULL,

    CONSTRAINT fk_contratos_colaborador FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
    ON DELETE CASCADE 
    ON UPDATE CASCADE,

    CONSTRAINT fk_contratos_centro_costo FOREIGN KEY (id_centro_costo) REFERENCES centro_costos(id_centro_costo)
    ON DELETE CASCADE 
    ON UPDATE CASCADE
);

        
CREATE TABLE IF NOT EXISTS contactos_colaboradores (
    id_contacto INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    tipo ENUM('email_personal', 'email_corporativo', 'movil_personal', 
              'movil_corporativo', 'whatsapp', 'telefono_fijo') NOT NULL,
    valor VARCHAR(255) NOT NULL,
    
    CONSTRAINT fk_contacto_colaborador FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador) 
    ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS seguridad_social (
    id_seguridad INT AUTO_INCREMENT PRIMARY KEY,  -- Identificador único de la afiliación
    id_empleado INT NOT NULL,  -- Relación con la tabla empleados
    cesantias VARCHAR(100) NOT NULL,  -- Fondo de cesantías
    pension VARCHAR(100) NOT NULL,  -- Fondo de pensiones
    eps VARCHAR(100) NOT NULL,  -- Entidad de salud (EPS)
    arl VARCHAR(100) NOT NULL,  -- ARL asignada
    riesgo ENUM('I', 'II', 'III', 'IV', 'V') NOT NULL,  -- Nivel de riesgo laboral (1 al 5 según clasificación)
    ccf VARCHAR(100) NOT NULL,  -- Caja de compensación familiar

    -- Clave foránea para la relación con empleados
    CONSTRAINT fk_seguridad_social_empleado FOREIGN KEY (id_empleado) REFERENCES colaboradores(id_colaborador)
);


CREATE TABLE IF NOT EXISTS tallas_dotacion (
	id_talla INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    talla_pantalon VARCHAR(5),
    talla_camisa VARCHAR(5),
    talla_botas VARCHAR(5),
    
    CONSTRAINT fk_talla_empleado FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
);

-- Creación Tabla Inventario Dotación

CREATE TABLE IF NOT EXISTS inventario_dotacion (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('Pantalón', 'Camisa', 'Botas') NOT NULL,
    referencia VARCHAR(100) NOT NULL,
    talla VARCHAR(20),
    color VARCHAR(50),
    precio DECIMAL(10,2),
    proveedor INT,
    fecha_compra DATE,
    cantidad INT NOT NULL DEFAULT 0,
	lote VARCHAR(20),
    
    CONSTRAINT fk_proveedor FOREIGN KEY (proveedor) REFERENCES proveedores(id_proveedor)
);

-- Creacion tabla de entrega de dotación
CREATE TABLE IF NOT EXISTS dotacion (
    id_entrega INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    id_item INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    fecha_entrega DATE NOT NULL,
    entregado_por VARCHAR(100),
    observaciones TEXT,
    FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador),
    FOREIGN KEY (id_item) REFERENCES inventario_dotacion(id_item)
);

-- Tabla de Beneficiarios del colaborador
CREATE TABLE IF NOT EXISTS beneficiarios (
    id_beneficiario INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    genero ENUM('M', 'F', 'Otro') NOT NULL,
    fecha_nacimiento DATE,

    CONSTRAINT fk_beneficiario_empleado FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
);

-- Tabla de periodos de prueba
CREATE TABLE IF NOT EXISTS pp (
    id_pp INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    dias_pp INT NOT NULL,
    id_contrato INT NOT NULL,
    
	CONSTRAINT fk_pp_empleado FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
);

-- registro de retiro de Colaboradores
CREATE TABLE IF NOT EXISTS colaboradores_retirados (
    id_retiro INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    fecha_retiro DATE NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    detalles TEXT NULL,
    registrado_por VARCHAR(100) NOT NULL,  -- Almacena el usuario de MySQL que ejecuta la operación por procedimiento almacenado
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paz_salvo ENUM ('Paz y Salvo OK', 'Pendiente Paz y Salvo', 'Paz y Salvo no Encontrado', 'N/A', 'Informacion no Disponible'),
    
    CONSTRAINT fk_retirado_id FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador)
);


-- ////////////////////////// Creación tablas Mantenimiento //////////////////////////
-- Crecion Tabla tipo_operacion
CREATE TABLE IF NOT EXISTS tipo_operacion(
	tipo_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20)
);

-- #################################################################################################
-- Creación tablas para tipos de vehiculos por grupo, categoría y tipología 
CREATE TABLE IF NOT EXISTS grupos_vehiculo (
    id_grupo INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS categorias_vehiculo (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_grupo INT NOT NULL,
    
    CONSTRAINT fk_grupo FOREIGN KEY (id_grupo) REFERENCES grupos_vehiculo(id_grupo)
);

CREATE TABLE IF NOT EXISTS tipologias_vehiculo (
    id_tipologia INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_categoria INT NOT NULL,
    
    CONSTRAINT fk_categoria FOREIGN KEY (id_categoria) REFERENCES categorias_vehiculo(id_categoria)
);

-- ######################################################################################################
-- creación de vehículos terceros
CREATE TABLE IF NOT EXISTS vehiculos_terceros (
    id_vehiculo INT AUTO_INCREMENT PRIMARY KEY,
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    anio INT NOT NULL,
    id_tipologia INT NOT NULL,
    id_base INT,
    capacidad DECIMAL(10,2),
    estado ENUM('Habilitado', 'No Habilitado') NOT NULL,
    fecha_vencimiento_soat DATE,
    registrado_por INT,
    fecha_creacion DATETIME,
    fecha_ultima_actualizacion DATETIME,  -- usar fecha de última actualizacion de manera automatica crear alarma por vencimiento de docuimentos o 6 meses de ultima actualizacion de datos
    ANS TINYINT NOT NULL DEFAULT 0,
    
    CONSTRAINT fk_tipologia FOREIGN KEY (id_tipologia) REFERENCES tipologias_vehiculo(id_tipologia),
    
    CONSTRAINT fk_bases_id FOREIGN KEY (id_base) REFERENCES ciudades(id_ciudad) 
    ON UPDATE CASCADE
    ON DELETE SET NULL
);

-- Creación tabla Proveedores_vehiculos_terceros
CREATE TABLE IF NOT EXISTS proveedores_vehiculos_terceros (
    id_persona INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    identificacion VARCHAR(20) UNIQUE NOT NULL,
    telefono1 VARCHAR(20),
    direccion VARCHAR(255),
    ciudad INT,
    estado ENUM('Habilitado', 'Deshabilitado') NOT NULL,
    registrado_por INT,
    fecha_creacion DATE,
    fecha_ultima_actualizacion DATE,
    
    CONSTRAINT fk_ciudad_tercero FOREIGN KEY (ciudad) REFERENCES ciudades(id_ciudad)
);

-- Tabla Intermediaria que relaciona personal tercero con vehículos terceros
CREATE TABLE IF NOT EXISTS vehiculo_persona (
	PRIMARY KEY (id_vehiculo, id_persona, roles),
    id_vehiculo INT,
    id_persona INT,
    roles ENUM('Propietario', 'Tenedor', 'Conductor') NOT NULL,
    
    CONSTRAINT fk_vehiculo_tercero FOREIGN KEY (id_vehiculo) REFERENCES vehiculos_terceros(id_vehiculo),
    
    CONSTRAINT fk_persona_tercero FOREIGN KEY (id_persona) REFERENCES proveedores_vehiculos_terceros(id_persona)
);


-- creación de tabla vehículos fidelizados No Avansat
-- Estos vehículo tipo motos o motocarros no se pueden crear en Avansat así que no entran en la categoría ni Propiaos ni Terceros
CREATE TABLE IF NOT EXISTS vehiculo_fidelizado (
    id_vehiculo INT AUTO_INCREMENT PRIMARY KEY,
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    anio INT NOT NULL,
    id_tipologia INT NOT NULL,
    id_base INT,
    capacidad DECIMAL(10,2),
    estado ENUM('Habilitado', 'No Habilitado') NOT NULL,
    fecha_vencimiento_soat DATE,
    registrado_por INT,
    fecha_creacion DATETIME,
    fecha_ultima_actualizacion DATETIME,
    ANS TINYINT NOT NULL DEFAULT 0,
    
    -- Se ha cambiado el nombre de la restricción para que sea única
    CONSTRAINT fk_vehiculo_fidelizado_tipologia FOREIGN KEY (id_tipologia) REFERENCES tipologias_vehiculo(id_tipologia),
    
    CONSTRAINT fk_vehiculo_fidelizado_base FOREIGN KEY (id_base) REFERENCES ciudades(id_ciudad) 
    ON UPDATE CASCADE
    ON DELETE SET NULL
);


-- tabla para registrar el conjunto total de vehículos en condición especial Fidelizados, tabla auxilia
CREATE TABLE vehiculos_especiales (
    placa VARCHAR(10) PRIMARY KEY,
    tipo_proveedor ENUM ('FDZ1', 'FDZ2') NOT NULL,
    descripcion VARCHAR(255)
);


-- tabla motociclatas y motocarros terceros
CREATE TABLE IF NOT EXISTS motos_motocarros_terceros (
	id_vehiculo INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM ('MOTO', 'MOTOCARRO', 'BICICLETA'),
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    anio INT NOT NULL, 
    id_base INT,
    capacidad DECIMAL(10,2),
    estado ENUM('Habilitado', 'No Habilitado') NOT NULL,
    fecha_vencimiento_soat DATE,
    registrado_por INT,
    fecha_creacion DATETIME,
    fecha_ultima_actualizacion DATETIME,
    ANS TINYINT NOT NULL DEFAULT 0,
    
    CONSTRAINT fk_moto_fidelizado_base FOREIGN KEY (id_base) REFERENCES ciudades(id_ciudad) 
);

-- tabla auxiliar roles moto - motocarro tercero
CREATE TABLE IF NOT EXISTS moto_persona_tercero (
	PRIMARY KEY (id_vehiculo, id_persona, roles),
    id_vehiculo INT,
    id_persona INT,
    roles ENUM('Propietario', 'Tenedor', 'Conductor') NOT NULL,
    
    CONSTRAINT fk_moto_tercero FOREIGN KEY (id_vehiculo) REFERENCES motos_motocarros_terceros(id_vehiculo)
);


CREATE TABLE IF NOT EXISTS proveedores_motos_terceros (
    id_persona INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    identificacion VARCHAR(20) UNIQUE NOT NULL,
    telefono1 VARCHAR(20),
    direccion VARCHAR(255),
    ciudad INT,
    estado ENUM('Habilitado', 'Deshabilitado') NOT NULL,
    registrado_por INT,
    fecha_creacion DATE,
    fecha_ultima_actualizacion DATE,
    
    CONSTRAINT fk_ciudad_moto_tercero FOREIGN KEY (ciudad) REFERENCES ciudades(id_ciudad)
);

-- #################################################################################################

-- Creación tabla vehículos de Flota propia PYP
CREATE TABLE IF NOT EXISTS vehiculos_propios (
  id_vehiculo       INT               NOT NULL AUTO_INCREMENT,
  placa             VARCHAR(10)       NOT NULL,
  id_tipologia      INT               NOT NULL,
  marca             VARCHAR(50)       NOT NULL,
  modelo            VARCHAR(50)       NOT NULL,
  kilometraje   	FLOAT 			  NULL,
  fecha_ult_med		DATETIME		  NULL,
  anio              INT               NOT NULL,
  tipo_combustible  VARCHAR(100)      NULL,
  max_km_diario     DECIMAL(10,2)     NULL,
  prom_km_diario    DECIMAL(10,2)     NULL,
  id_base           INT               NULL,
  centro_costo      VARCHAR(100)      NULL,
  vin               VARCHAR(100)      NULL,
  propietario       VARCHAR(255)      NULL,
  motor             VARCHAR(100)      NULL,
  capacidad         DECIMAL(10,2)     NULL,
  num_chasis        VARCHAR(100)      NULL,
  num_serial        VARCHAR(100)      NULL,
  fecha_compra      DATE              NULL,
  costo             DECIMAL(20,2)     NULL,
  fecha_creacion    DATETIME          NULL,
  creado_por        VARCHAR(100)      NULL,

  PRIMARY KEY (id_vehiculo),
  UNIQUE KEY uq_vehiculos_propios_placa (placa),

  CONSTRAINT fk_topologia_propio
    FOREIGN KEY (id_tipologia)
    REFERENCES tipologias_vehiculo(id_tipologia),

  CONSTRAINT fk_base
    FOREIGN KEY (id_base)
    REFERENCES ciudades(id_ciudad)
) ;




-- ////////////////////////// Creación tablas Operaciones //////////////////////////

-- Creación tabla rutas (Relacionada con envios)
CREATE TABLE IF NOT EXISTS rutas (
    ruta_id INT PRIMARY KEY AUTO_INCREMENT,
    origen INT NOT NULL,
	destino INT NOT NULL,
    distancia_km DECIMAL(10,2) NOT NULL,
    tiempo_estimado TIME NOT NULL,
    
    CONSTRAINT fk_ciudad_origen FOREIGN KEY (origen) REFERENCES ciudades(id_ciudad),
	
    CONSTRAINT fk_ciudad_destino FOREIGN KEY (destino) REFERENCES ciudades(id_ciudad)
);

-- Creación tabla clientes (Relación 1:N con envios)
CREATE TABLE IF NOT EXISTS clientes (
    id_cliente INT PRIMARY KEY AUTO_INCREMENT,
    nit VARCHAR(100),
    nombre VARCHAR(150) NOT NULL,
    contacto VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS envios (
    id_envio INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_envio DATETIME NOT NULL,
    destino VARCHAR(255) NOT NULL,
    carga TEXT,
    tipo_vehiculo ENUM('propio', 'tercero') NOT NULL,
    placa VARCHAR(20) NOT NULL,
    
    CONSTRAINT fk_cliente_id FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

-- Creación tabla conductores (Subcategoría de colaboradores, Relación 1:N con envios)
CREATE TABLE IF NOT EXISTS conductores (
    id_conductor INT AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT UNIQUE NOT NULL,
    tipo_licencia enum('A1','A2','B1','B2','B3','C1','C2','C3') NOT NULL,
    fecha_vencimiento_lic date NOT NULL,
    observaciones_restricciones VARCHAR(255),
    
     CONSTRAINT fk_conductor_id FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador) 
     ON DELETE CASCADE
);


-- ////////////////////////// Creación tablas administrativas //////////////////////////
-- Creación tabla de auditoría para registrar eventos en la base de datos
CREATE TABLE IF NOT EXISTS auditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100) NOT NULL,
    evento ENUM('Conexion', 'Desconexion', 'Inserción', 'Actualización', 'Eliminación') NOT NULL,
    tabla_afectada VARCHAR(100),
    registro_id VARCHAR(50),
    campo_afectado VARCHAR(100),
    valor_anterior TEXT,
    valor_nuevo TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auditoria_backup (
	id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100) NOT NULL,
    evento ENUM('Conexion', 'Desconexion', 'Inserción', 'Actualización', 'Eliminación') NOT NULL,
    tabla_afectada VARCHAR(100),
    registro_id VARCHAR(50),
    campo_afectado VARCHAR(100),
    valor_anterior TEXT,
    valor_nuevo TEXT,
    fecha DATE
);

CREATE TABLE IF NOT EXISTS log_conexiones (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100) NOT NULL,
    ip_origen VARCHAR(45),
    mac_origen VARCHAR(45),
    fecha_conexion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_errores_etl (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    operacion VARCHAR(50),
    descripcion_error TEXT,
    datos_fallidos TEXT
);


-- ////////////////////////// Creación de la tabla usuarios de la BD //////////////////////////
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(50) NOT NULL,
    contraseña VARCHAR(50) NOT NULL,
    departamento INT,
    id_colaborador INT UNIQUE NOT NULL,
    
    CONSTRAINT fk_departamento FOREIGN KEY (departamento) REFERENCES departamentos(departamento_id) ON DELETE SET NULL,
    
    CONSTRAINT fk_colaborador_userid FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador) ON DELETE CASCADE
);

-- Creación de permisos de acceso a vistas según departamento
CREATE TABLE IF NOT EXISTS permisos_departamento_lectura_vistas (
    departamento_id INT,
    vista_nombre VARCHAR(255),
    PRIMARY KEY (departamento_id, vista_nombre)
);


-- ////////////////////////// Tabla de apoyo datos //////////////////////////
CREATE TABLE IF NOT EXISTS dias_festivos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL
);

-- ////////////////////////// Creación tablas para  Operaciones //////////////////////////

-- Creción Bases Deprisa
CREATE TABLE IF NOT EXISTS bases_deprisa(
	base_id INT AUTO_INCREMENT PRIMARY KEY,
    bases VARCHAR(5) UNIQUE NOT NULL,
    direccion TEXT,
    ciudad INT,
    coordinador_base VARCHAR(100),
    regional VARCHAR(20),
    
    CONSTRAINT fk_ciudad_id FOREIGN KEY (ciudad) REFERENCES ciudades(id_ciudad)
);


-- Creación subtabla servicio
CREATE TABLE IF NOT EXISTS servicio (
	servicio_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80)
);


-- Creación subtabla Driver
CREATE TABLE IF NOT EXISTS driver (
    driver_id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    
    CONSTRAINT fk_servicio_ids FOREIGN KEY (servicio_id) REFERENCES servicio(servicio_id)
);


-- Creación subtabla sectores_deprisa
CREATE TABLE IF NOT EXISTS sectores_deprisa (
	sector_id INT AUTO_INCREMENT PRIMARY KEY,
    base_id INT,
    sector VARCHAR(50) UNIQUE,
    contrato TEXT,
    modelo VARCHAR(15),
    concepto TEXT,
    metodo_pago VARCHAR(50),
    vehiculo    ENUM('CM','VN','MT'),
    
    CONSTRAINT fk_bases_deprisa FOREIGN KEY (base_id) REFERENCES bases_deprisa(base_id)
);


-- Creación tabla de ingreso de datos Operaciones
CREATE TABLE IF NOT EXISTS operaciones (
	operacion_id INT AUTO_INCREMENT PRIMARY KEY,
	servicio INT,
	driver INT,
	vehiculo ENUM('CAMION', 'MOTO', 'VAN'),
    estacion INT,
    fecha date,
    proveedor ENUM('PYP', 'TCR', 'FDZ1', 'FDZ2'),
    tonelaje INT,
    sector VARCHAR(50),
    placa VARCHAR(10),
    hora_inicio TIME,
    hora_final TIME,
    horas_no_operativas FLOAT,
    nombre_ruta TEXT,
    clasificacion_uso_PxH ENUM('1. Solo UM', '2. Solo PM', '3. Mixto (UM-PM)', '4. Vehiculo circular', '5. Aeropuerto', '6. Vehiculo dedicado cliente'),
    cc_conductor VARCHAR(20),
    cc_aux_1 VARCHAR(20),
	cc_aux_2 VARCHAR(20),
    cantidad_envios INT,
    cantidad_devoluciones INT,
    cantidad_recolecciones INT,
    cantidad_no_recogidos INT,
    km_inicial FLOAT,
    km_final FLOAT,
	tipo_pago ENUM('MENSUAL', 'CAJA MENOR', 'TRANS PRONTO PAGO', 'NO', 'APOYO'),
    remesa VARCHAR(20) UNIQUE,
    manifiesto VARCHAR(20) UNIQUE,
    cierre_dia_siguiente TINYINT(1) NOT NULL DEFAULT 0,
    validacion_cumplido_liquidado BOOLEAN DEFAULT 0,
    validacion_prefactura BOOLEAN DEFAULT 0,
    
	CONSTRAINT fk_servicio_id FOREIGN KEY (servicio) REFERENCES servicio(servicio_id),
    
	CONSTRAINT fk_driver_id FOREIGN KEY (driver) REFERENCES driver(driver_id),
    
    CONSTRAINT fk_estacion_base FOREIGN KEY (estacion) REFERENCES bases_deprisa(base_id),
    
    CONSTRAINT fk_sector_deprisa FOREIGN KEY (sector) REFERENCES sectores_deprisa(sector)
);


-- Creación Tabla caja_menor_operaciones
CREATE TABLE IF NOT EXISTS caja_menor_operaciones (
	transaccion_id INT AUTO_INCREMENT PRIMARY KEY,
    operacion_id INT,
    consecutivo VARCHAR(200),
    valor DECIMAL(10, 2), 
    
    CONSTRAINT fk_caja_menor_operacion FOREIGN KEY (operacion_id) REFERENCES operaciones(operacion_id)
);


CREATE TABLE IF NOT EXISTS ordenes_trabajo_vehiculo (
    ot_id INT AUTO_INCREMENT PRIMARY KEY,
    operacion_id INT NOT NULL,                -- FK hacia la tabla operaciones
    numero_ot VARCHAR(30) NOT NULL,           -- Número de orden de trabajo asignado por el cliente
    
    CONSTRAINT fk_ot_operacion FOREIGN KEY (operacion_id) REFERENCES operaciones(operacion_id)
);


CREATE TABLE IF NOT EXISTS backoffice (
	backoffice_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
    estacion INT,
    servicio INT,
    driver INT,
    tipo_pago VARCHAR(20),
    proveedor ENUM('PYP', 'TCR'),
    backof_1 VARCHAR(20),
    hora_inicial TIME,
    hora_final TIME,
    
    CONSTRAINT fk_estacion_back_of FOREIGN KEY (estacion) REFERENCES bases_deprisa (base_id),
    
    CONSTRAINT fk_servcio_back_of FOREIGN KEY (servicio) REFERENCES servicio (servicio_id),
    
    CONSTRAINT fk_driver_back_of FOREIGN KEY (driver) REFERENCES driver (driver_id)
);

-- Tabla auxiliar para el campo observaciones de la seccion otros formulario Back_Office
CREATE TABLE IF NOT EXISTS observaciones_otros(
	observaciones_id INT AUTO_INCREMENT PRIMARY KEY,
    backoffice_id INT NOT NULL,
    observacion TEXT,
    
    CONSTRAINT fk_backoffice FOREIGN KEY (backoffice_id) REFERENCES backoffice (backoffice_id)
);


-- ////////////////////////// Tablas Despachos //////////////////////////
CREATE TABLE IF NOT EXISTS operaciones_avansat (
    manifiesto VARCHAR(20),
    fecha_manifiesto DATE,
    placa VARCHAR(10),
    remolque VARCHAR(10),
    configuracion VARCHAR(20),
    tipo_vinculacion VARCHAR(50),
    orden_cargue VARCHAR(255),
    remesa VARCHAR(255),
    remision VARCHAR(255),
    fecha_remesa DATE,
    fecha_salida_despacho DATE,
    fecha_llegada_despacho DATE,
    cumplida DATE,
    fecha_llegada_cargue DATETIME,
    fecha_salida_cargue DATETIME,
    fecha_llegada_descargue DATETIME,
    fecha_salida_descargue DATETIME,
    factura VARCHAR(20),
    fecha_factura DATE,
    fecha_vencimiento DATE,
    val_inicial_remesa DECIMAL(18,2),
    val_facturado_separado DECIMAL(18,2),
    val_facturado_remesa DECIMAL(18,2),
    val_declarado_remesa DECIMAL(18,2),
    nombre_ser_especial TEXT,
    val_servicios DECIMAL(18,2),
    val_produccion DECIMAL(18,2),
    cantidad_facturada INT,
    costo_unitario DECIMAL(18,2),
    retefuente_factura DECIMAL(18,2),
    ica_factura DECIMAL(18,2),
    iva_factura DECIMAL(18,2),
    facturado_a VARCHAR(100),
    sede VARCHAR(150),
    agencia_despacho VARCHAR(150),
    remitente VARCHAR(150),
    empaque VARCHAR(100),
    unidad_servicio VARCHAR(100),
    tn_pedido INT,
    tn_o_cargue INT,
    tn_remesa INT,
    tn_cumplido INT,
    pendiente INT,
    cantidad_cumplida INT,
    flete_manifiesto DECIMAL(18,2),
    retefuente_manifiesto DECIMAL(18,2),
    ica_manifiesto DECIMAL(18,2),
    usuario_cumplido_manifiesto VARCHAR(50),
    fecha_cumplido_manifiesto DATETIME,
    anticipo DECIMAL(18,2),
    nro_anticipos INT,
    nro_comprob VARCHAR(255),
    valor_flete_liquidacion DECIMAL(18,2),
    valor_liquidado DECIMAL(18,2),
    retefuente_liquid DECIMAL(18,2),
    ica_liquid DECIMAL(18,2),
    cree_liquid DECIMAL(18,2),
    fecha_liquid DATE,
    nro_comprob1 VARCHAR(255),
    faltantes_liquidacion INT,
    valor_descontar DECIMAL(18,2),
    servicio_integral INT,
    nombre_ser_especial2 TEXT,
    ser_especial_manifiesto INT,
    valor_pagado DECIMAL(18,2),
    fecha_pago DATE,
    nro_comprob2 VARCHAR(255),
    banco VARCHAR(255),
    cuenta_bancaria VARCHAR(255),
    nro_cheque VARCHAR(255),
    tipo_pago VARCHAR(255),
    origen VARCHAR(255),
    destino VARCHAR(255),
    producto VARCHAR(255),
    conductor VARCHAR(255),
    cc_conductor VARCHAR(255),
    celular VARCHAR(255),
    poseedor VARCHAR(255),
    cc_nit_poseedor VARCHAR(255),
    nro_pedido INT,
    observacion_llegada TEXT,
    vlr_tarifa_cotizacion_cliente DECIMAL(18,2),
    descripcion_tarifa TEXT,
    fecha_recaudo DATE,
    nro_comprobante_recaudo INT,
    creado_por VARCHAR(255),
    estado VARCHAR(255),
    documento_destinatario VARCHAR(255),
    destinatario TEXT,
    costo_produccion DECIMAL(18,2),
    prorrateo_costo_estimado_propio DECIMAL(18,2),
    prorrateo_costo_estimado_tercero DECIMAL(18,2),
    prorrateo_utilidad_estimada DECIMAL(18,2),
    fecha_hora_entrada_cargue DATETIME,
    fecha_hora_entrada_descargue DATETIME,
    -- índice único
    UNIQUE KEY idx_operacion_unica (manifiesto, fecha_manifiesto, placa, remesa)
);


CREATE TABLE IF NOT EXISTS remesas (
	remesa VARCHAR(100),
    remision VARCHAR(100),
    nro_factura VARCHAR(100),
    estado_manifiesto VARCHAR(100),
    clientes VARCHAR(200),
    agencai VARCHAR(100),
    fecha_remesa DATE,
    fecha_facturacion DATETIME,
    facturado VARCHAR(200),
    fecha_cump DATETIME,
    peso_cump INT,
    usuario_cump VARCHAR(50),
    v_facturado DECIMAL(10,2),
    v_declarado DECIMAL(10,2),
    v_remesa DECIMAL(10,2),
    porc_seguro DECIMAL(5,3),
    v_seguro DECIMAL(10,2),
    v_servicio DECIMAL(10,2),
    placa VARCHAR(10),
    conductor VARCHAR(200),
    cantidad INT,
    vol INT,
    Peso_remesa_tn INT,
    remitente TEXT,
    destinatario TEXT,
    origen VARCHAR(100),
    destino VARCHAR(100),
    manifiesto VARCHAR(10),
    pedido VARCHAR(10),
    estado VARCHAR(50),
    contenido TEXT,
    observacion_transportador TEXT,
    observaciones_adicionales TEXT,
    archivo_gestion_documental VARCHAR(10),
    cumplido_inicial_cargue VARCHAR(10),
    cumplido_inicial_descargue VARCHAR(10),
    d_producto TEXT
);

CREATE TABLE IF NOT EXISTS tarifas_transporte (
    id_tarifa INT AUTO_INCREMENT PRIMARY KEY,
    id_ciudad INT NOT NULL,
    tipo_tarifa ENUM('MERCADO', 'SICETAC') NOT NULL,
    valor_tarifa DECIMAL(15,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE DEFAULT NULL,
    activo BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT fk_tarifa_ciudad FOREIGN KEY (id_ciudad) REFERENCES ciudades(id_ciudad)
);


-- ////////////////////////// Tabla de uso común Operaciones - despachos //////////////////////////
CREATE TABLE IF NOT EXISTS ld_despacho (
	despacho_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
    placa VARCHAR(10),
    origen INT,
    destino INT,
    opera BOOLEAN DEFAULT TRUE,
    tonelaje INT,
    concepto ENUM('Round_Trip', 'One_Way'),
    driver ENUM('Recurrente', 'Spot'),
    linea ENUM('1era Linea', '2da Linea', '3era Linea', '4ta Linea', '5ta Linea'),
    viaje_ot VARCHAR(10),
    pago DECIMAL(10,2),
    anticipo DECIMAL(10,2),
    manifiesto VARCHAR(10),
    CC VARCHAR (20),
    nombre_conductor VARCHAR(100),
    
    CONSTRAINT fk_origen_ciudad FOREIGN KEY (origen) REFERENCES ciudades(id_ciudad),
    
    CONSTRAINT fk_destino_ciudad FOREIGN KEY (destino) REFERENCES ciudades(id_ciudad)
);

CREATE TABLE IF NOT EXISTS otros_costos (
	otro_costo_id INT AUTO_INCREMENT PRIMARY KEY,
    despacho_id INT,
    concepto TEXT,
    valor DECIMAL(10,2),
    
    CONSTRAINT fk_otro_costo_despacho FOREIGN KEY (despacho_id) REFERENCES ld_despacho(despacho_id)
);

CREATE TABLE IF NOT EXISTS observacion_ld_despachos (
	observacion_id INT AUTO_INCREMENT PRIMARY KEY,
    despacho_id INT,
    observacion TEXT,
    
    CONSTRAINT fk_observacion_despacho FOREIGN KEY (despacho_id) REFERENCES ld_despacho(despacho_id)
);

CREATE TABLE IF NOT EXISTS reglas_tarifas (
    id_regla INT AUTO_INCREMENT PRIMARY KEY,
    id_origen INT NOT NULL,                                
    id_destino INT NOT NULL,
    driver ENUM('Recurrente', 'Spot') NOT NULL,
    concepto ENUM('Round_Trip', 'One_Way') NOT NULL,
    tonelaje VARCHAR(50) NOT NULL,
    regla VARCHAR(100) NOT NULL UNIQUE,
    
    CONSTRAINT fk_origen_regla FOREIGN KEY (id_origen) REFERENCES ciudades(id_ciudad),
    
    CONSTRAINT fk_destino_regla FOREIGN KEY (id_destino) REFERENCES ciudades(id_ciudad)
);

CREATE TABLE IF NOT EXISTS tarifas (
    id_tarifa INT AUTO_INCREMENT PRIMARY KEY,
    id_regla INT NOT NULL,
    valor_tarifa DECIMAL(10,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE DEFAULT NULL,
    activo BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT fk_regla_tarifa FOREIGN KEY (id_regla) REFERENCES reglas_tarifas(id_regla)
);

-- ////////////////////////// Creación tablas Seguridad //////////////////////////

CREATE TABLE IF NOT EXISTS botones_panico (
	id_prueba INT AUTO_INCREMENT PRIMARY KEY,
    fecha	DATE,
    hora_solicitud_activacion TIME,
    tiempo_respuesta INT,
    placa_vehiculo VARCHAR(6),
    empresa_satelital VARCHAR(50),
    tipo_flota ENUM('Propia', 'Tercero'),
    ubicaciones_vehiculo TEXT,
    novedades ENUM('No Reporta', 'Si Reporta'),
    observaciones TEXT,
    gestion TEXT,
    fecha_cierre_novedad DATE,
    controlador INT,
    
    CONSTRAINT fk_controlador_colaborador FOREIGN KEY (controlador) REFERENCES colaboradores(id_colaborador)
);

CREATE TABLE IF NOT EXISTS candados_satelitales (
	candado_id INT AUTO_INCREMENT PRIMARY KEY,
    numero_candado VARCHAR(5) NOT NULL UNIQUE,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    estatus ENUM ('EN OPERACION', 'FUERA DE OPERACION', 'MANTENIMIENTO', 'RETIRO DEFINITIVO')
);

CREATE TABLE IF NOT EXISTS movimiento_candados (
	id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    candado_id INT NOT NULL,
    fecha DATE NOT NULL,
    ubicacion VARCHAR(150),
    placa_asignada VARCHAR(6),
    estatus_operativo ENUM('ASIGNADO', 'PEND RETORNO A BOGOTA', 'PEND QUE CONDUCTOR RECLAME', 'DISPONIBLE'),
    observaciones TEXT,
    
    CONSTRAINT fk_candados_activos FOREIGN KEY (candado_id) REFERENCES candados_satelitales(candado_id)
);

CREATE TABLE IF NOT EXISTS bitacora_operacion_trafico (
	entrada_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
    turno ENUM('06:00-18:00', '18:00-06:00'),
    controlador_entrega INT,
    controlador_recibe INT,
    
    CONSTRAINT fk_controlador_entrega FOREIGN KEY (controlador_entrega) REFERENCES colaboradores(id_colaborador),
    
    CONSTRAINT fk_controlador_recibe FOREIGN KEY (controlador_recibe) REFERENCES colaboradores(id_colaborador),
    
    CONSTRAINT unique_fecha_turno UNIQUE (fecha, turno)
);

-- creacxión sub tablas para bitácora operaciones trafico

CREATE TABLE IF NOT EXISTS trafico_avansat (
	detalle_id INT AUTO_INCREMENT PRIMARY KEY,
    entrada_id INT NOT NULL,
	cliente VARCHAR(100),
    cant_vehiculos INT,
    
    CONSTRAINT fk_entrada_bitacora FOREIGN KEY (entrada_id) REFERENCES bitacora_operacion_trafico(entrada_id)
);


CREATE TABLE IF NOT EXISTS no_planillados_avansat (
	no_planillado_id INT AUTO_INCREMENT PRIMARY KEY, 
    entrada_id INT NOT NULL,
    placa VARCHAR(6),
    detalle TEXT,
    
    CONSTRAINT fk_entrada_no_planillados FOREIGN KEY (entrada_id) REFERENCES bitacora_operacion_trafico(entrada_id)
);

CREATE TABLE IF NOT EXISTS novedades_observaciones (
	novedad_id INT AUTO_INCREMENT PRIMARY KEY,
    entrada_id INT NOT NULL,
    detalle TEXT,
    
    CONSTRAINT fk_entrada_novedades FOREIGN KEY (entrada_id) REFERENCES bitacora_operacion_trafico(entrada_id)
);

CREATE TABLE IF NOT EXISTS escoltas (
	novedad_escolta_id INT AUTO_INCREMENT PRIMARY KEY,
    entrada_id INT NOT NULL,
    detalle TEXT,
    
    CONSTRAINT fk_entrada_escoltas FOREIGN KEY (entrada_id) REFERENCES bitacora_operacion_trafico(entrada_id)
);


CREATE TABLE IF NOT EXISTS pausas_acivas (
	pausa_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
    hora TIME,
    tiempo_conduccion DECIMAL(10,2),
    pausa_real BOOLEAN,
    origen INT,
    destino INT,
    placa VARCHAR (6),
    novedad BOOLEAN DEFAULT FALSE,
    observaciones TEXT,
    fecha_reporte DATE,
    controlador INT,
    
    CONSTRAINT fk_controlador FOREIGN KEY (controlador) REFERENCES colaboradores(id_colaborador)
);

CREATE TABLE IF NOT EXISTS pernocte_flota_propia (
	pernocte_id INT AUTO_INCREMENT PRIMARY KEY,
	fecha DATE,
    placa VARCHAR(20),
    lugar_pernocte TEXT,
    controlador INT
);


CREATE TABLE IF NOT EXISTS auxiliares_terceros (
	auxiliar_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NULL,
    tipo_documento ENUM('CC', 'TI', 'CE', 'PA', 'PEP', 'PPT') NOT NULL,
    documento VARCHAR(20) NOT NULL UNIQUE,
    fecha_nacimiento DATE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    grupo_sanguineo enum('A','B','AB','O','N/D') NOT NULL,
	rh enum('+','-','N/D') NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    ciudad INT NOT NULL,
    eps VARCHAR(200) NOT NULL,
    arl VARCHAR(200) NOT NULL,
    estatus ENUM ('Activo', 'Inactivo') NOT NULL DEFAULT 'Inactivo',
    fecha_nuevo_estatus DATE NULL,
    
    CONSTRAINT fk_ciudades_auxiliares_terceros FOREIGN KEY (ciudad) REFERENCES ciudades (id_ciudad)
);

CREATE TABLE IF NOT EXISTS conductores_terceros_avansat (
	conductor_id INT AUTO_INCREMENT PRIMARY KEY,
    cc_id VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(200),
    estado ENUM ('Activo', 'Inactivo')
);

-- //////////////////////////Creación Tablas Contabilidad///////////////////////////////////////


CREATE TABLE IF NOT EXISTS conceptos (
	concepto_id INT AUTO_INCREMENT PRIMARY KEY,
    descripcion TEXT
);

CREATE TABLE IF NOT EXISTS cuentas_pyp (
	cuenta_id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
	descripcion VARCHAR(150),
    nombre TEXT,
    valor DECIMAL(10,2),
    documento VARCHAR(250),
    concepto INT,
    descripcion_2 TEXT,
    banco INT,
    
    CONSTRAINT fk_bancos FOREIGN KEY (banco) REFERENCES bancos(banco_id),
    
    CONSTRAINT fk_conceptos FOREIGN KEY (concepto) REFERENCES conceptos(concepto_id)
);

-- ////////////////////////// Tablas Clod Fleet //////////////////////////

-- Tabla para la asignación de accesos a vistas y a procedimientos almacendos específicos por departamento

CREATE TABLE IF NOT EXISTS permisos_departamento_objetos (
    departamento_id INT,
    tipo_objeto ENUM('VISTA', 'PROCEDIMIENTO'),
    nombre_objeto VARCHAR(100),
    tipo_permiso ENUM('SELECT', 'EXECUTE')
);



--  ////////////////////////////////// Tablas Tarifas ///////////////////////////////////////////

-- Tarifas Derisa

CREATE TABLE IF NOT EXISTS tarifas_deprisa_PXQ (
	tarifa_id INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM ('CM', 'VN', 'MT') NOT NULL,
    estructura ENUM ('PXQ Camion Urbano',
					'PXQ Poblaciones',
                    'PXQ Van Urbano',
                    'PXQ Moto Urbano',
                    'PXQ Moto Poblacion'
                    ) NOT NULL,
    modelo ENUM ('PXQ URB', 'PXQ POB') NOT NULL,
    base INT NOT NULL,
    base_corta VARCHAR(4) NOT NULL,
    poblacion INT,
    entrega DECIMAL(10, 2),
    recoleccion DECIMAL(10, 2),
    vigencia INT NOT NULL,
    
    CONSTRAINT fk_base_derisa FOREIGN KEY (base) REFERENCES ciudades(id_ciudad),
    
    CONSTRAINT fk_base_poblacion FOREIGN KEY (poblacion) REFERENCES ciudades(id_ciudad)
);


CREATE TABLE IF NOT EXISTS tarifas_deprisa_PXH (
	tarifa_id INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM ('CM', 'VN', 'MT') NOT NULL,
    estructura ENUM ('PXH Camion Urbano',
					'PXH Poblacion Sabana',
                    'PXH Van Urbano',
                    'MENSUALIDAD'
                    ) NOT NULL,
	modelo ENUM ('ATO', 'PXH ESP', 'PXH POB', 'PXH URB') NOT NULL,
    base INT NOT NULL,
    tonelaje INT NOT NULL,
    valor DECIMAL(10, 2),
    auxiliar INT NOT NULL,
    vigencia INT NOT NULL,
    
    CONSTRAINT fk_base_derisa_2 FOREIGN KEY (base) REFERENCES ciudades(id_ciudad)
);



CREATE TABLE IF NOT EXISTS historico_operaciones (
	historico_id INT AUTO_INCREMENT PRIMARY KEY,
    disponible VARCHAR(20),
    festivo VARCHAR(3),
    tipo_ruta VARCHAR(20),
    concepto_largo VARCHAR(100),
    servicio_excel VARCHAR(20),
    servicio INT,
    driver_excel VARCHAR(20),
    driver INT,
    vehiculo ENUM('CAMION', 'MOTO', 'VAN'),
    estacion_excel VARCHAR(5),
    estacion INT,
    fecha Date,
    mes_facturacion VARCHAR(20),
    regional VARCHAR(20),
    autorizacion VARCHAR(20),
    proveedor_deprisa VARCHAR (5),
    tonelaje INT,
    numero_auxiliares INT,
    ot_viaje VARCHAR(100),
    sector VARCHAR(100),
    placa VARCHAR(10),
    hora_inicio TIME,
    hora_final TIME,
    horas_no_operativas FLOAT,
    horas_totales FLOAT,
    nombre_ruta VARCHAR(255),
    clasificacion_uso_pxh VARCHAR(100),
    proveedor ENUM('PYP', 'TCR', 'FDZ1', 'FDZ2'),
    vehiculo_concepto_corto ENUM('CM', 'MT', 'VN'),
    cc_conductor VARCHAR(50),
    nombre_conductor VARCHAR(255),
    cc_aux1 VARCHAR(50),
    nombre_aux1 VARCHAR(255),
	cc_aux2 VARCHAR(50),
    nombre_aux2 VARCHAR(255),
    envios INT,
    envios_efectivos INT,
    dev INT,
    num_recolecciones INT,
    recolecciones_efectivas INT,
	recolecciones_no_efectivas INT,
    km_inicial INT,
    km_final INT,
    tipo_pago VARCHAR (50),
    valor_consecutivo VARCHAR (255),
    pedido VARCHAR(50),
    orden_cargue VARCHAR (50),
    remesa VARCHAR (50),
    manifiesto VARCHAR (50),
    horas_reales FLOAT,
    base VARCHAR(5),
    km_dia FLOAT,
    llv_conductor VARCHAR(50),
    llv_auxiliar VARCHAR(50),
    nomina_conductor DECIMAL(12,3),
    nomina_auxiliar DECIMAL(12,3),
    total_nomina DECIMAL(12,3),
    horas_extra FLOAT,
    llv_de_cobro VARCHAR(255),
    valor_unitario_horapxh_enviopxq DECIMAL(16,6),
    totalpxq_entregas_totalpxh DECIMAL(16,6),
    valor_unitario_rec_pxq DECIMAL(12,6),
    total_pxq_entregas DECIMAL(12,6),
    total_cobro DECIMAL(12,2),
    metodo_pago VARCHAR(50),
    llv_metodo_pago	VARCHAR(50),
    llv_pago_1 VARCHAR(50),
    llv_pago_2 VARCHAR(50),
    ton_pago FLOAT,
    valor_unitario DECIMAL(12,2),
    valor_turno DECIMAL(12,2),
    valor_he DECIMAL(12,2),
    total_he DECIMAL(12,2),
    total_turno DECIMAL(12,2),
    horas_aut_productividad INT,
    total_env_y_rec INT,
    cobro_auxiliar DECIMAL(12,2),
    cobro_sin_auxiliar DECIMAL(12,2),
    ret_porcentaje FLOAT,
    prodcutividad FLOAT,
    llv_mde VARCHAR(10),
    llv_ato DECIMAL(36,16),
    dias_habiles_mes DECIMAL(16,12),
    anio INT,
    llv_ut_flota FLOAT,
    variacion_pesos DECIMAL(12,2),
    variacion_porcentaje DECIMAL(5,2),
    mes INT,
    llv_conteo_placa VARCHAR(20),
    dias_habiles_t INT,
    poblacion VARCHAR(5)
);

-- Tabla para almacenar valores de parámetros (número de horas mensuales de trabajo)
CREATE TABLE parametros_empresa (
    id_parametro INT AUTO_INCREMENT PRIMARY KEY,
    nombre_parametro VARCHAR(100) NOT NULL UNIQUE,
    valor_parametro DECIMAL(10,2) NOT NULL,
    descripcion TEXT NULL,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);


-- tabla de referencia de parametros de tiempo para la empresa
CREATE TABLE IF NOT EXISTS parametro_recargo_nocturno (
    id_parametro      TINYINT     PRIMARY KEY CHECK (id_parametro = 1),
    hora_inicio       TIME        NOT NULL,
    hora_fin          TIME        NOT NULL,
    descripcion       VARCHAR(200),
    actualizado_el    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);



-- ////////////////////////// Creación de la tablas Metodos de Pago y Fletes //////////////////////////
CREATE TABLE IF NOT EXISTS metodo_pago (
	id_metodo INT AUTO_INCREMENT PRIMARY KEY,
    id_ciudad INT,
    sector VARCHAR(50),
    modelo VARCHAR(50),
    concepto VARCHAR(50),
    metodo_pago VARCHAR(20),
    vehiculo VARCHAR(5),
    
    CONSTRAINT fk_ciudad_poblacion FOREIGN KEY (id_ciudad) REFERENCES ciudades(id_ciudad),
    
    CONSTRAINT fk_sector_met FOREIGN KEY (sector) REFERENCES sectores_deprisa(sector)
    
);
  

CREATE TABLE IF NOT EXISTS fletes (
	id_flete INT AUTO_INCREMENT PRIMARY KEY,
    metodo_pago VARCHAR(50),
    proveedor VARCHAR(5),
    tonelaje INT,
    valor DECIMAL(19,2),
    hora_extra DECIMAL(19,2),
    base_corta VARCHAR(50),
    ciudad_poblacion INT,
    turno DECIMAL(19,2),
    sub_tipo VARCHAR(10),
    
    CONSTRAINT fk_ciudad_poblacion_flete FOREIGN KEY (ciudad_poblacion) REFERENCES ciudades(id_ciudad)
);


CREATE TABLE IF NOT EXISTS pago_hora (
	regla_id INT AUTO_INCREMENT PRIMARY KEY,
	rango_ini_h      DECIMAL(4,2),
    rango_fin_h      DECIMAL(4,2), 
	pct_pago         DECIMAL(5,2),   -- 1.00 = 100 %, 0.70 = 70 %
    desc_almuerzo    TINYINT(1) 
);

CREATE TABLE IF NOT EXISTS  prod_tarifa (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    vehiculo_tipo  	 VARCHAR(10),            
    tonelaje         DECIMAL(4,1) NOT NULL,
    piezas_ini          SMALLINT NOT NULL,     -- rango inicio (entregas + recolecciones)
    piezas_fin          SMALLINT NOT NULL,     -- rango fin (inclusive)
    horas_a_pagar    DECIMAL(4,2) NOT NULL -- horas que se pagarán
);

CREATE TABLE IF NOT EXISTS  entrega (
	id							INT AUTO_INCREMENT PRIMARY KEY,
    vehiculo_tipo  	 			VARCHAR(10),
    estructura_modelo_PXQ		VARCHAR(100),
    modelo						VARCHAR(15),
    estacion					INT,
    ciudad_poblacion			INT,
    cobro_entrega				DECIMAL(19,2),
    cobro_recoleccion			DECIMAL(19,2),
    pago_entrega				DECIMAL(19,2),
    pago_recoleccion			DECIMAL(19,2),
    
    CONSTRAINT fk_ciudad_poblacion_entrega FOREIGN KEY (ciudad_poblacion) REFERENCES ciudades(id_ciudad),
    CONSTRAINT fk_estacion_entrega FOREIGN KEY (estacion) REFERENCES bases_deprisa(base_id)
    
);

CREATE TABLE IF NOT EXISTS tarifas_mensuales (
	id							INT AUTO_INCREMENT PRIMARY KEY,
    sector						VARCHAR(10),
    estacion					INT,
    ciudad_poblacion			INT,
    valor_cobro					DECIMAL(19,2),
	valor_pago					DECIMAL(19,2),
	
    CONSTRAINT fk_ciudad_poblacion_tarifa_mensual FOREIGN KEY (ciudad_poblacion) REFERENCES ciudades(id_ciudad),
    CONSTRAINT fk_estacion_tarifa_mensual FOREIGN KEY (estacion) REFERENCES bases_deprisa(base_id)
);

CREATE TABLE IF NOT EXISTS contratos_modificaciones (
    id_modificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato INT NOT NULL,
    fecha_modificacion DATE NOT NULL,
    tipo_modificacion ENUM('Otro Si', 'Terminación', 'Corrección') NOT NULL,
    observaciones TEXT NOT NULL, -- Aquí va la razón del cambio
    -- Campos específicos que cambiaron (útil para reportes)
    cambio_salario DECIMAL(12,2) DEFAULT NULL,
    cambio_cargo INT DEFAULT NULL,
    cambio_fecha_fin DATE DEFAULT NULL,
    FOREIGN KEY (id_contrato) REFERENCES contratos(id_contrato),
    CONSTRAINT fk_modificaciones_rol FOREIGN KEY (cambio_cargo) REFERENCES roles(id_rol)
);

--  Tabla de Inactividades de Colaboradores, esta tabla sirve para registrar vacaciones, permisos, incapacidades etc
CREATE TABLE IF NOT EXISTS tbl_inactividades (
    id_inactividad INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_colaborador INT NOT NULL,
    tipo_inactividad ENUM('Incapacidad', 'Vacaciones', 'Permiso/Licencia') NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,
    observaciones TEXT NULL,
    registrado_por INT NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    stado_actual TINYINT UNSIGNED NOT NULL DEFAULT 1
    COMMENT '0 = Cerrada, 1 = Abierta',
    
    -- FOREIGN KEY hacia la tabla colaboradores (id_colaborador)
    CONSTRAINT fk_tbl_inactividades_colaborador 
        FOREIGN KEY (id_colaborador) 
        REFERENCES colaboradores(id_colaborador)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    -- FOREIGN KEY hacia la tabla colaboradores (registrado_por)
    CONSTRAINT fk_tbl_inactividades_registrador 
        FOREIGN KEY (registrado_por) 
        REFERENCES colaboradores(id_colaborador)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    -- ÍNDICES para mejorar búsquedas
    INDEX idx_id_colaborador (id_colaborador),
    INDEX idx_registrado_por (registrado_por),
    INDEX idx_fecha_inicio (fecha_inicio),
    INDEX idx_fecha_fin (fecha_fin),
    INDEX idx_tipo_inactividad (tipo_inactividad)
);



-- ////////////////////////// Tablas Clod Fleet //////////////////////////

-- ////////////////////////// Tablas para Staginig //////////////////////////

-- crear la tabla staging_operaciones_avansat

CREATE TABLE IF NOT EXISTS staging_operaciones_avansat LIKE operaciones_avansat;

CREATE TABLE IF NOT EXISTS staging_vehiculos_propios LIKE vehiculos_propios;

CREATE TABLE IF NOT EXISTS staging_vehiculos_terceros LIKE vehiculos_terceros;

CREATE TABLE IF NOT EXISTS staging_proveedores_vehiculos_terceros LIKE proveedores_vehiculos_terceros;

CREATE TABLE IF NOT EXISTS staging_vehiculo_persona LIKE vehiculo_persona;

-- 1. STAGING VEHÍCULOS (Datos crudos tal cual vienen del Excel/Python)
DROP TABLE IF EXISTS staging_vehiculos_avansat;
CREATE TABLE staging_vehiculos_avansat (
    placa VARCHAR(20),
    marca VARCHAR(50),
    linea VARCHAR(100),            -- Se usará para 'modelo'
    modelo VARCHAR(10),            -- Se usará para 'anio'
    ciudad_conductor_txt VARCHAR(100), -- Nombre ciudad (para buscar ID después)
    capacidad VARCHAR(50),
    estado_vehiculo VARCHAR(50),
    nombre_conductor VARCHAR(150),
    cc_conductor VARCHAR(20),
    celular_conductor VARCHAR(50),
    direccion_conductor VARCHAR(255)
);

-- 2. STAGING CONDUCTORES (Reporte 2 - Espejo simple)
DROP TABLE IF EXISTS staging_conductores_avansat;
CREATE TABLE staging_conductores_avansat (
    cc_id VARCHAR(20),
    nombre_completo VARCHAR(200),
    estado VARCHAR(50)
);






