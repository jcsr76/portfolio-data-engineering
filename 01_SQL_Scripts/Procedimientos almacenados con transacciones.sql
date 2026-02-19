-- Procedimiento y transacción para mover datos de auditoria a auditoria_backup
DELIMITER //

CREATE PROCEDURE MoverAuditoriaBackup()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Si ocurre un error, hacemos rollback
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en la transacción';
    END;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- Mover registros de más de 30 días a auditoria_backup
    INSERT INTO auditoria_backup 
    SELECT * FROM auditoria WHERE fecha < NOW() - INTERVAL 30 DAY;
    
    -- Eliminar los registros movidos
    DELETE FROM auditoria WHERE fecha < NOW() - INTERVAL 30 DAY;
    
    -- Confirmar la transacción
    COMMIT;
    
    -- Optimizar la tabla auditoria fuera de la transacción
    OPTIMIZE TABLE auditoria;
END //

DELIMITER ;


-- Procedimiento y transacción para limpiar auditoria_backup después del backup mensual
DELIMITER //

CREATE PROCEDURE LimpiarAuditoriaBackup()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Si ocurre un error, hacemos rollback
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en la transacción';
    END;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- Eliminar todos los registros de auditoria_backup
    DELETE FROM auditoria_backup;
    
    -- Confirmar la transacción
    COMMIT;
    
    -- Optimizar la tabla fuera de la transacción
    OPTIMIZE TABLE auditoria_backup;
END //

DELIMITER ;


-- Procedimiento Insertar Nuevo Colaborador con transacción de manejo de errores
DELIMITER //

CREATE PROCEDURE InsertarColaborador(
    IN p_tipo_id ENUM('CC','TI','CE','PA','PEP','PPT'),
    IN p_id_cc VARCHAR(20),
    IN p_lugar_expedicion INT,
    IN p_fecha_expedicion DATE,
    IN p_primer_nombre VARCHAR(100),
    IN p_segundo_nombre VARCHAR(100),
    IN p_primer_apellido VARCHAR(100),
    IN p_segundo_apellido VARCHAR(100),
    IN p_formacion_academica ENUM('primaria','bachillerato','pregrado','especializacion','postgrado','maestria','doctorado'),
    IN p_estado_formacion_academica ENUM('Termino','En curso','Incompleta'),
    IN p_fecha_nacimiento DATE,
    IN p_sexo VARCHAR(10),
    IN p_grupo_sanguineo ENUM('A', 'B', 'AB', 'O'),
    IN p_rh ENUM('+', '-'),
    IN p_estado_civil ENUM('soltero(a)','casado(a)','union libre','viudo(a)','divorciado(a)'),
    IN p_direccion VARCHAR(255),
    IN p_barrio VARCHAR(200),
    IN p_estrato VARCHAR(10),
    IN p_ciudad_nacimiento INT,
    IN p_estatus_colaborador ENUM('Activo','Inactivo','Retirado'),
    IN p_departamento INT,
    IN p_cargo INT,
    IN p_sede INT,
    IN p_planta VARCHAR(20),
    IN p_id_jefe INT,
    IN p_fecha_emo DATE,
    IN p_contacto_emergencia VARCHAR(150),
    IN p_telefono_contacto_emergencia VARCHAR(150)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error en procedimiento InsertarColaborador: fallo al insertar en tabla colaboradores';
    END;

    START TRANSACTION;

    INSERT INTO colaboradores (
        tipo_id, id_cc, lugar_expedicion, fecha_expedicion,
        primer_nombre, segundo_nombre, primer_apellido, segundo_apellido,
        formacion_academica, estado_formacion_academica, fecha_nacimiento,
        sexo, grupo_sanguineo, rh, estado_civil,
        direccion, barrio, estrato, ciudad_nacimiento,
        estatus_colaborador, departamento, cargo, sede,
        planta, id_jefe, fecha_emo,
        contacto_emergencia, telefono_contacto_emergencia
    ) VALUES (
        p_tipo_id, p_id_cc, p_lugar_expedicion, p_fecha_expedicion,
        p_primer_nombre, p_segundo_nombre, p_primer_apellido, p_segundo_apellido,
        p_formacion_academica, p_estado_formacion_academica, p_fecha_nacimiento,
        p_sexo, p_grupo_sanguineo, p_rh, p_estado_civil,
        p_direccion, p_barrio, p_estrato, p_ciudad_nacimiento,
        p_estatus_colaborador, p_departamento, p_cargo, p_sede,
        p_planta, p_id_jefe, p_fecha_emo,
        p_contacto_emergencia, p_telefono_contacto_emergencia
    );

    COMMIT;
END //

DELIMITER ;


-- Procedimiento almacenado para insertar usuarios en la tabla usuarios (con transacción y control de errores)

DELIMITER //

CREATE PROCEDURE InsertarUsuarios()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Error: No se pudieron insertar los usuarios' AS mensaje;
    END;

    START TRANSACTION;

    INSERT INTO usuarios (id_colaborador, usuario, departamento, contraseña)
    SELECT 
        id_colaborador,
        LOWER(CONCAT(remove_accents(primer_apellido), LEFT(remove_accents(primer_nombre), 1))),
        departamento_id,
        '123456'
    FROM vista_info_colaboradores
    WHERE id_rol NOT IN (9, 12, 13, 15, 16, 17, 24, 38, 40, 44, 51, 55, 58)
    ON DUPLICATE KEY UPDATE usuario = VALUES(usuario);

    COMMIT;
    SELECT 'Usuarios insertados correctamente' AS mensaje;
END //

DELIMITER ;


-- Procedimiento almacenado para generar los usuarios en la BD a partir de la tabla usuarios

DROP PROCEDURE IF EXISTS CrearUsuariosMySQL;


DELIMITER //
CREATE PROCEDURE CrearUsuariosMySQL()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE v_usuario VARCHAR(50);
  DECLARE v_contraseña VARCHAR(50);

  DECLARE cur CURSOR FOR SELECT usuario, contraseña FROM usuarios;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  START TRANSACTION;
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_usuario, v_contraseña;
    IF done THEN LEAVE read_loop; END IF;

    SET @sql=CONCAT(
      "CREATE USER IF NOT EXISTS '", v_usuario,
      "'@'192.168.0.%' IDENTIFIED BY '", v_contraseña,
      "' PASSWORD EXPIRE;"
    );
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @sql=CONCAT(
      "CREATE USER IF NOT EXISTS '", v_usuario,
      "'@'192.168.100.%' IDENTIFIED BY '", v_contraseña,
      "' PASSWORD EXPIRE;"
    );
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @sql=CONCAT(
      "CREATE USER IF NOT EXISTS '", v_usuario,
      "'@'192.168.101.%' IDENTIFIED BY '", v_contraseña,
      "' PASSWORD EXPIRE;"
    );
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

  END LOOP;
  CLOSE cur;
  COMMIT;
  -- opción: FLUSH PRIVILEGES;
END//
DELIMITER ;












-- Procedimiento almacenado para asignar permisos de lectura a los usuarios de las vistas asignadas según departamento
-- Este procedimiento debe ser ajustado una vez la BD esté desplegada en el servidor devuelve las sentencias SQL para cargarlas manualmente 
-- o automatizando con Python ya que MySQl no permite usar sentencias GRANT con procesos automatizados por seguridad
-- Se debe implementar automatización con python usando el resultado de esta consulta
DELIMITER //

CREATE PROCEDURE asignar_permisos_lectura()
SQL SECURITY INVOKER
BEGIN
    SELECT 
        CONCAT('GRANT SELECT ON pypdb.', p.vista_nombre, ' TO \'', u.usuario, '\'@\'%\';') AS grant_stmt
    FROM pypdb.usuarios u
    JOIN pypdb.permisos_departamento_lectura_vistas p
        ON u.departamento = p.departamento_id
    WHERE EXISTS (
        SELECT 1 FROM mysql.user WHERE user = u.usuario AND host = 'localhost'
    );
END //

DELIMITER ;




-- Procedimiento almacenado para ingreso de datos a tabla incapacidadesb  REVISAR POR COMPLEJIDAD EN PK
DELIMITER //
CREATE PROCEDURE insert_incapacidad (
    IN p_id_colaborador INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_diagnostico VARCHAR(255),
    IN p_observaciones TEXT
)
BEGIN
    DECLARE next_id INT;
    DECLARE new_incapacidad_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Si hay un error, revierte la transacción
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error al insertar incapacidad';
    END;

    START TRANSACTION;

    -- Obtener el siguiente consecutivo de manera segura
    SELECT COALESCE(MAX(CAST(SUBSTRING(incapacidad_id, 7, 3) AS UNSIGNED)), 0) + 1 
    INTO next_id
    FROM incapacidades 
    WHERE incapacidad_id LIKE CONCAT(YEAR(p_fecha_inicio),
                                     LPAD(MONTH(p_fecha_inicio), 2, '0'), '%')
    FOR UPDATE;  -- Bloquea estos registros para evitar concurrencia

    -- Generar el nuevo ID con formato YYYYMMXXX
    SET new_incapacidad_id = CONCAT(
        YEAR(p_fecha_inicio),
        LPAD(MONTH(p_fecha_inicio), 2, '0'),
        LPAD(next_id, 3, '0')
    );

    -- Insertar el nuevo registro en la tabla
    INSERT INTO incapacidades (
        incapacidad_id,
        id_colaborador,
        fecha_inicio_incapacidad,
        fecha_fin_incapacidad,
        diagnostico,
        observaciones
    ) VALUES (
        new_incapacidad_id,
        p_id_colaborador,
        p_fecha_inicio,
        p_fecha_fin,
        p_diagnostico,
        p_observaciones
    );

    COMMIT; -- Confirmar la transacción si todo está bien
END;
//
DELIMITER ;

-- Procedimiento almacenado para ingreso de datos a la tabla envíos  NO CREO QUE LO USE
DELIMITER //

CREATE PROCEDURE sp_insert_envio(
    IN p_guia_id VARCHAR(20),
    IN p_cliente_id INT,
    IN p_id_conductor INT,
    IN p_id_vehiculo INT,
    IN p_ruta_id INT,
    IN p_fecha_salida DATETIME,
    IN p_fecha_llegada DATETIME,
    IN p_estado ENUM('Pendiente', 'En tránsito', 'Entregado', 'Cancelado')
)
BEGIN
    DECLARE next_id INT;
    DECLARE new_envio_id VARCHAR(10);
    DECLARE retry INT DEFAULT 0;
    DECLARE exit_loop BOOLEAN DEFAULT FALSE;

    -- Iniciar la transacción
    START TRANSACTION;

    -- Verificar que la guía no esté duplicada
    IF EXISTS (SELECT 1 FROM envios WHERE guia_id = p_guia_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La guía ya existe';
    END IF;

    -- Validar claves foráneas
    IF p_cliente_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM clientes WHERE cliente_id = p_cliente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Cliente no encontrado';
    END IF;
    IF p_id_conductor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM conductores WHERE id_conductor = p_id_conductor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Conductor no encontrado';
    END IF;
    IF p_id_vehiculo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM vehiculos WHERE id_vehiculo = p_id_vehiculo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Vehículo no encontrado';
    END IF;
    IF p_ruta_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rutas WHERE ruta_id = p_ruta_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Ruta no encontrada';
    END IF;

    -- Intentar la inserción hasta 3 veces si hay concurrencia
    WHILE retry < 3 AND exit_loop = FALSE DO
        -- Obtener el siguiente ID sin bloquear filas
        SELECT COALESCE(MAX(CAST(SUBSTRING(envio_id, 7, 4) AS UNSIGNED)), 0) + 1 
        INTO next_id
        FROM envios
        WHERE envio_id LIKE CONCAT(YEAR(p_fecha_salida),
                                   LPAD(MONTH(p_fecha_salida), 2, '0'), '%');

        -- Generar el nuevo envio_id con formato YYYYMMXXXX
        SET new_envio_id = CONCAT(
            YEAR(p_fecha_salida),
            LPAD(MONTH(p_fecha_salida), 2, '0'),
            LPAD(next_id, 4, '0')
        );

        -- Intentar insertar
        INSERT IGNORE INTO envios (envio_id, guia_id, cliente_id, id_conductor, id_vehiculo, ruta_id, 
                                   fecha_salida, fecha_llegada, estado)
        VALUES (new_envio_id, p_guia_id, p_cliente_id, p_id_conductor, p_id_vehiculo, p_ruta_id, 
                p_fecha_salida, p_fecha_llegada, p_estado);

        -- Si la inserción fue exitosa, salir del bucle
        IF ROW_COUNT() > 0 THEN
            SET exit_loop = TRUE;
        ELSE
            -- Si falló por colisión, aumentar intento y repetir
            SET retry = retry + 1;
        END IF;
    END WHILE;

    -- Si después de 3 intentos no se pudo insertar, generar error
    IF exit_loop = FALSE THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Demasiados intentos de inserción por concurrencia';
    ELSE
        COMMIT;
    END IF;

END //

DELIMITER ;



-- Procedimiento almacenado para insertar vehículos terceros con verificación
DELIMITER $$
CREATE PROCEDURE InsertarVehiculoTercero(
    IN p_placa VARCHAR(20),
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(50),
    IN p_anio INT
)
BEGIN
    DECLARE vehiculo_existente INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Transacción revertida debido a un problema';
    END;
    
    START TRANSACTION;
    
    -- Verificar que la placa no exista en la tabla de vehículos propios
    SELECT COUNT(*) INTO vehiculo_existente FROM vehiculos_propios WHERE placa = p_placa;
    IF vehiculo_existente > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La placa ya existe en la tabla de vehículos propios';
    END IF;
    
    -- Insertar el vehículo en la tabla de vehículos terceros
    INSERT INTO vehiculos_terceros (placa, marca, modelo, anio)
    VALUES (p_placa, p_marca, p_modelo, p_anio);
    
    COMMIT;
END $$
DELIMITER ;

-- #####################################################################################################################################

-- Procedimientos almacenados para cargar los datos desde Access a la tabla operacion

DROP PROCEDURE IF EXISTS insertar_operacion_completa;
DELIMITER //

CREATE PROCEDURE insertar_operacion_completa (
    IN  p_servicio              INT,
    IN  p_driver                INT,
    IN  p_vehiculo              ENUM('CAMION','MOTO','VAN'),
    IN  p_estacion              INT,
    IN  p_fecha                 DATE,
    IN  p_proveedor             ENUM('PYP','TCR','FDZ1','FDZ2'),
    IN  p_tonelaje              INT,
    IN  p_sector                VARCHAR(50),
    IN  p_placa                 VARCHAR(10),
    IN  p_hora_inicio           TIME,
    IN  p_nombre_ruta           TEXT,
    IN  p_clasificacion_uso_PxH ENUM(
        '1. Solo UM','2. Solo PM','3. Mixto (UM-PM)',
        '4. Vehiculo circular','5. Aeropuerto',
        '6. Vehiculo dedicado cliente'
    ),
    IN  p_cc_conductor          VARCHAR(20),
    IN  p_cc_aux_1              VARCHAR(20),
    IN  p_cc_aux_2              VARCHAR(20),
    IN  p_cantidad_envios       INT,
    IN  p_km_inicial            FLOAT,
    IN  p_tipo_pago             ENUM('MENSUAL','CAJA MENOR','TRANS PRONTO PAGO','NO'),
    IN  p_remesa                VARCHAR(20),
    IN  p_manifiesto            VARCHAR(20),
    IN  p_ciudad_poblacion      INT, -- <<< PARÁMETRO NUEVO
    IN  p_cm_consecutivo        INT,
    IN  p_cm_valor              DECIMAL(10,2),
    IN  p_ot_list_json          LONGTEXT,
    IN  p_usuario               VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET @usuario_actual = p_usuario;
    START TRANSACTION;
    INSERT INTO operaciones (
        servicio, driver, vehiculo, estacion, fecha, proveedor, tonelaje,
        sector, placa, hora_inicio, nombre_ruta,
        clasificacion_uso_PxH, cc_conductor, cc_aux_1, cc_aux_2,
        cantidad_envios, km_inicial, tipo_pago,
        remesa, manifiesto, ciudad_poblacion -- <<< CAMPO NUEVO
    ) VALUES (
        p_servicio, p_driver, p_vehiculo, p_estacion, p_fecha, p_proveedor, p_tonelaje,
        p_sector, p_placa, p_hora_inicio, p_nombre_ruta,
        p_clasificacion_uso_PxH, p_cc_conductor, p_cc_aux_1, p_cc_aux_2,
        p_cantidad_envios, p_km_inicial, p_tipo_pago,
        p_remesa, p_manifiesto, p_ciudad_poblacion -- <<< VALOR NUEVO
    );
    SET @new_op = LAST_INSERT_ID();
    INSERT INTO ordenes_trabajo_vehiculo (operacion_id, numero_ot)
    SELECT @new_op, jt.ot
    FROM JSON_TABLE(
      p_ot_list_json,
      "$[*]" COLUMNS (ot VARCHAR(30) PATH "$")
    ) AS jt;
    IF p_cm_consecutivo IS NOT NULL AND p_cm_valor IS NOT NULL THEN
        INSERT INTO caja_menor_operaciones (
            operacion_id,
            consecutivo,
            valor,
            tipo_origen,
            backoffice_id
        ) VALUES (
            @new_op,
            p_cm_consecutivo,
            p_cm_valor,
            'operacion',
            NULL
        );
    END IF;
    COMMIT;
END//
DELIMITER ;





-- Procedimiento almacenado para el cierre del despacho

DROP PROCEDURE IF EXISTS completar_operacion;

DELIMITER //

CREATE PROCEDURE completar_operacion (
    IN  p_operacion_id              INT,
    IN  p_km_final                  FLOAT,
    IN  p_hora_final                TIME,
    IN  p_cantidad_devoluciones     INT,
    IN  p_cantidad_recolecciones    INT,
    IN  p_cantidad_no_recogidos     INT,
    IN  p_horas_no_operativas       FLOAT,
    IN  p_usuario                   VARCHAR(100),
    IN  p_cierre_dia_siguiente      TINYINT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Registrar el usuario
    SET @usuario_actual = p_usuario;

    START TRANSACTION;

    UPDATE operaciones
    SET km_final = p_km_final,
        hora_final = p_hora_final,
        cantidad_devoluciones = p_cantidad_devoluciones,
        cantidad_recolecciones = p_cantidad_recolecciones,
        cantidad_no_recogidos = p_cantidad_no_recogidos,
        horas_no_operativas = p_horas_no_operativas,
        cierre_dia_siguiente = p_cierre_dia_siguiente
    WHERE operacion_id = p_operacion_id;

    COMMIT;
END//

DELIMITER ;


-- Procedimiento almacenado para guardar el Log de conexiones de usuarios

DELIMITER //

CREATE PROCEDURE registrar_log_conexion (
    IN p_usuario     VARCHAR(100),
    IN p_ip_origen   VARCHAR(45),
    IN p_mac_origen  VARCHAR(45)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO log_conexiones (usuario, ip_origen, mac_origen)
    VALUES (p_usuario, p_ip_origen, p_mac_origen);

    COMMIT;
END //

DELIMITER ;


--  ######################################Procedimiento almacanado para Conciliación en Operaciones##########################################################################

DROP PROCEDURE IF EXISTS actualizar_operacion;

DELIMITER //

CREATE PROCEDURE actualizar_operacion(
    IN p_operacion_id INT,
    IN p_hora_inicio TIME,
    IN p_hora_final TIME,
    IN p_horas_no_operativas FLOAT,
    IN p_tonelaje INT,
    IN p_borrar_cc_aux_1 TINYINT,
    IN p_borrar_cc_aux_2 TINYINT,
    IN p_cc_aux_1 VARCHAR(20),
	IN p_cc_aux_2 VARCHAR(20)

)
BEGIN
    -- Declarar la variable para manejar errores
    DECLARE v_usuario VARCHAR(100);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Si ocurre un error, hacer ROLLBACK
        ROLLBACK;
        -- Aquí podrías agregar un mensaje de error si lo deseas
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en la actualización de la operación';
    END;

    -- Iniciar la transacción
    START TRANSACTION;

    -- Obtener el usuario actual
    SET v_usuario = USER();  -- Utiliza USER() para obtener el nombre de usuario de la sesión

    -- Actualizar solo los campos que no son NULL
	UPDATE operaciones
	SET
		tonelaje = IF(p_tonelaje IS NOT NULL, p_tonelaje, tonelaje),
		hora_inicio = IF(p_hora_inicio IS NOT NULL, p_hora_inicio, hora_inicio),
		hora_final = IF(p_hora_final IS NOT NULL, p_hora_final, hora_final),
		horas_no_operativas = IF(p_horas_no_operativas IS NOT NULL, p_horas_no_operativas, horas_no_operativas),
		cc_aux_1 = IF(p_cc_aux_1 IS NOT NULL, p_cc_aux_1, cc_aux_1),
		cc_aux_2 = IF(p_cc_aux_2 IS NOT NULL, p_cc_aux_2, cc_aux_2)
	WHERE operacion_id = p_operacion_id;

    -- Borrar los valores de cc_aux_1 y cc_aux_2 si se indica en los parámetros
    IF p_borrar_cc_aux_1 = 1 THEN
        UPDATE operaciones
        SET cc_aux_1 = NULL
        WHERE operacion_id = p_operacion_id;
    END IF;

    IF p_borrar_cc_aux_2 = 1 THEN
        UPDATE operaciones
        SET cc_aux_2 = NULL
        WHERE operacion_id = p_operacion_id;
    END IF;

    -- Confirmar la transacción si no hubo errores
    COMMIT;

END //

DELIMITER ;


--  ######################################Procedimiento almacanado para Staginig##########################################################################

-- Procedimiento para limpiar staging_operaciones_avansat
DELIMITER //

CREATE PROCEDURE limpiar_staging_operaciones()
BEGIN
    TRUNCATE TABLE staging_operaciones_avansat;
END //

DELIMITER ;

DELIMITER //


-- Procedimiento almacenado para cargar los datos del df python pandas a staging_operaciones_avansat

DELIMITER //

CREATE PROCEDURE insertar_en_staging_operaciones (
	IN p_manifiesto VARCHAR(20),
    IN p_fecha_manifiesto DATE,
    IN p_placa VARCHAR(10),
    IN p_remolque VARCHAR(10),
    IN p_configuracion VARCHAR(20),
    IN p_tipo_vinculacion VARCHAR(50),
    IN p_orden_cargue VARCHAR(255),
    IN p_remesa VARCHAR(255),
    IN p_remision VARCHAR(255),
    IN p_fecha_remesa DATE,
    IN p_fecha_salida_despacho DATE,
    IN p_fecha_llegada_despacho DATE,
    IN p_cumplida DATE,
    IN p_fecha_llegada_cargue DATETIME,
    IN p_fecha_salida_cargue DATETIME,
    IN p_fecha_llegada_descargue DATETIME,
    IN p_fecha_salida_descargue DATETIME,
    IN p_factura VARCHAR(20),
    IN p_fecha_factura DATE,
    IN p_fecha_vencimiento DATE,
    IN p_val_inicial_remesa DECIMAL(18,2),
    IN p_val_facturado_separado DECIMAL(18,2),
    IN p_val_facturado_remesa DECIMAL(18,2),
    IN p_val_declarado_remesa DECIMAL(18,2),
    IN p_nombre_ser_especial TEXT,
    IN p_val_servicios DECIMAL(18,2),
    IN p_val_produccion DECIMAL(18,2),
    IN p_cantidad_facturada INT,
    IN p_costo_unitario DECIMAL(18,2),
    IN p_retefuente_factura DECIMAL(18,2),
    IN p_ica_factura DECIMAL(18,2),
    IN p_iva_factura DECIMAL(18,2),
    IN p_facturado_a VARCHAR(100),
    IN p_sede VARCHAR(150),
    IN p_agencia_despacho VARCHAR(150),
    IN p_remitente VARCHAR(150),
    IN p_empaque VARCHAR(100),
    IN p_unidad_servicio VARCHAR(100),
    IN p_tn_pedido INT,
    IN p_tn_o_cargue INT,
    IN p_tn_remesa INT,
    IN p_tn_cumplido INT,
    IN p_pendiente INT,
    IN p_cantidad_cumplida INT,
    IN p_flete_manifiesto DECIMAL(18,2),
    IN p_retefuente_manifiesto DECIMAL(18,2),
    IN p_ica_manifiesto DECIMAL(18,2),
    IN p_usuario_cumplido_manifiesto VARCHAR(50),
    IN p_fecha_cumplido_manifiesto DATETIME,
    IN p_anticipo DECIMAL(18,2),
    IN p_nro_anticipos INT,
    IN p_nro_comprob VARCHAR(255),
    IN p_valor_flete_liquidacion DECIMAL(18,2),
    IN p_valor_liquidado DECIMAL(18,2),
    IN p_retefuente_liquid DECIMAL(18,2),
    IN p_ica_liquid DECIMAL(18,2),
    IN p_cree_liquid DECIMAL(18,2),
    IN p_fecha_liquid DATE,
    IN p_nro_comprob1 VARCHAR(255),
    IN p_faltantes_liquidacion INT,
    IN p_valor_descontar DECIMAL(18,2),
    IN p_servicio_integral INT,
    IN p_nombre_ser_especial2 TEXT,
    IN p_ser_especial_manifiesto INT,
    IN p_valor_pagado DECIMAL(18,2),
    IN p_fecha_pago DATE,
    IN p_nro_comprob2 VARCHAR(255),
    IN p_banco VARCHAR(255),
    IN p_cuenta_bancaria VARCHAR(255),
    IN p_nro_cheque VARCHAR(255),
    IN p_tipo_pago VARCHAR(255),
    IN p_origen VARCHAR(255),
    IN p_destino VARCHAR(255),
    IN p_producto VARCHAR(255),
    IN p_conductor VARCHAR(255),
    IN p_cc_conductor VARCHAR(255),
    IN p_celular VARCHAR(255),
    IN p_poseedor VARCHAR(255),
    IN p_cc_nit_poseedor VARCHAR(255),
    IN p_nro_pedido INT,
    IN p_observacion_llegada TEXT,
    IN p_vlr_tarifa_cotizacion_cliente DECIMAL(18,2),
    IN p_descripcion_tarifa TEXT,
    IN p_fecha_recaudo DATE,
    IN p_nro_comprobante_recaudo INT,
    IN p_creado_por VARCHAR(255),
    IN p_estado VARCHAR(255),
    IN p_documento_destinatario VARCHAR(255),
    IN p_destinatario TEXT,
    IN p_costo_produccion DECIMAL(18,2),
    IN p_prorrateo_costo_estimado_propio DECIMAL(18,2),
    IN p_prorrateo_costo_estimado_tercero DECIMAL(18,2),
    IN p_prorrateo_utilidad_estimada DECIMAL(18,2),
    IN p_fecha_hora_entrada_cargue DATETIME,
    IN p_fecha_hora_entrada_descargue DATETIME
)
BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    CALL registrar_error_etl(
        'insertar_en_staging_operaciones',
        'Error al insertar en staging_operaciones_avansat',
        CONCAT_WS('|', p_manifiesto, p_fecha_manifiesto, p_placa)
    );
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en inserción detectado';
END;


    INSERT INTO staging_operaciones_avansat (
        manifiesto, fecha_manifiesto, placa, remolque, configuracion,
        tipo_vinculacion, orden_cargue, remesa, remision, fecha_remesa,
        fecha_salida_despacho, fecha_llegada_despacho, cumplida, fecha_llegada_cargue,
        fecha_salida_cargue, fecha_llegada_descargue, fecha_salida_descargue, factura,
        fecha_factura, fecha_vencimiento, val_inicial_remesa, val_facturado_separado,
        val_facturado_remesa, val_declarado_remesa, nombre_ser_especial,
        val_servicios, val_produccion, cantidad_facturada, costo_unitario, retefuente_factura,
        ica_factura, iva_factura, facturado_a, sede, agencia_despacho, remitente, empaque,
        unidad_servicio, tn_pedido, tn_o_cargue, tn_remesa, tn_cumplido, pendiente,
        cantidad_cumplida, flete_manifiesto, retefuente_manifiesto, ica_manifiesto,
        usuario_cumplido_manifiesto, fecha_cumplido_manifiesto, anticipo, nro_anticipos,
        nro_comprob, valor_flete_liquidacion, valor_liquidado, retefuente_liquid, ica_liquid,
        cree_liquid, fecha_liquid, nro_comprob1, faltantes_liquidacion, valor_descontar,
        servicio_integral, nombre_ser_especial2, ser_especial_manifiesto,
        valor_pagado, fecha_pago, nro_comprob2, banco, cuenta_bancaria, nro_cheque,
        tipo_pago, origen, destino, producto, conductor, cc_conductor, celular,
        poseedor, cc_nit_poseedor, nro_pedido, observacion_llegada,
        vlr_tarifa_cotizacion_cliente, descripcion_tarifa, fecha_recaudo,
        nro_comprobante_recaudo, creado_por, estado, documento_destinatario,
        destinatario, costo_produccion, prorrateo_costo_estimado_propio,
        prorrateo_costo_estimado_tercero, prorrateo_utilidad_estimada,
        fecha_hora_entrada_cargue, fecha_hora_entrada_descargue
    )
    VALUES (
        p_manifiesto, p_fecha_manifiesto, p_placa, p_remolque, p_configuracion,
        p_tipo_vinculacion, p_orden_cargue, p_remesa, p_remision, p_fecha_remesa,
        p_fecha_salida_despacho, p_fecha_llegada_despacho, p_cumplida, p_fecha_llegada_cargue,
        p_fecha_salida_cargue, p_fecha_llegada_descargue, p_fecha_salida_descargue, p_factura,
        p_fecha_factura, p_fecha_vencimiento, p_val_inicial_remesa, p_val_facturado_separado,
        p_val_facturado_remesa, p_val_declarado_remesa, p_nombre_ser_especial,
        p_val_servicios, p_val_produccion, p_cantidad_facturada, p_costo_unitario, p_retefuente_factura,
        p_ica_factura, p_iva_factura, p_facturado_a, p_sede, p_agencia_despacho, p_remitente, p_empaque,
        p_unidad_servicio, p_tn_pedido, p_tn_o_cargue, p_tn_remesa, p_tn_cumplido, p_pendiente,
        p_cantidad_cumplida, p_flete_manifiesto, p_retefuente_manifiesto, p_ica_manifiesto,
        p_usuario_cumplido_manifiesto, p_fecha_cumplido_manifiesto, p_anticipo, p_nro_anticipos,
        p_nro_comprob, p_valor_flete_liquidacion, p_valor_liquidado, p_retefuente_liquid, p_ica_liquid,
        p_cree_liquid, p_fecha_liquid, p_nro_comprob1, p_faltantes_liquidacion, p_valor_descontar,
        p_servicio_integral, p_nombre_ser_especial2, p_ser_especial_manifiesto,
        p_valor_pagado, p_fecha_pago, p_nro_comprob2, p_banco, p_cuenta_bancaria, p_nro_cheque,
        p_tipo_pago, p_origen, p_destino, p_producto, p_conductor, p_cc_conductor, p_celular,
        p_poseedor, p_cc_nit_poseedor, p_nro_pedido, p_observacion_llegada,
        p_vlr_tarifa_cotizacion_cliente, p_descripcion_tarifa, p_fecha_recaudo,
        p_nro_comprobante_recaudo, p_creado_por, p_estado, p_documento_destinatario,
        p_destinatario, p_costo_produccion, p_prorrateo_costo_estimado_propio,
        p_prorrateo_costo_estimado_tercero, p_prorrateo_utilidad_estimada,
        p_fecha_hora_entrada_cargue, p_fecha_hora_entrada_descargue
    );
END //

DELIMITER ;


DELIMITER //
CREATE PROCEDURE registrar_error_etl (
    IN p_operacion VARCHAR(50),
    IN p_descripcion_error TEXT,
    IN p_datos_fallidos TEXT
)
BEGIN
    INSERT INTO log_errores_etl (operacion, descripcion_error, datos_fallidos)
    VALUES (p_operacion, p_descripcion_error, p_datos_fallidos);
END //
DELIMITER ;


-- ########################## Procedimiento almacenado para actualiozar e insertar registros a operaciones_avansat ###############################################

DELIMITER //

CREATE PROCEDURE sp_sincronizar_operaciones_avansat(
    OUT p_duracion INT,
    OUT p_inserts INT,
    OUT p_updates INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en la sincronización de operaciones_avansat';
    END;

    START TRANSACTION;

	SET @inicio = NOW();  -- Marca el inicio del proceso
    
	-- Inicializar contadores
    SET p_inserts = 0;
    SET p_updates = 0;

	
	-- INSERT nuevos
	INSERT INTO operaciones_avansat (
		manifiesto, fecha_manifiesto, placa, remesa, remolque, configuracion,
		tipo_vinculacion, orden_cargue, remision, fecha_remesa, fecha_salida_despacho,
		fecha_llegada_despacho, cumplida, fecha_llegada_cargue, fecha_salida_cargue,
		fecha_llegada_descargue, fecha_salida_descargue, factura, fecha_factura,
		fecha_vencimiento, val_inicial_remesa, val_facturado_separado,
		val_facturado_remesa, val_declarado_remesa, nombre_ser_especial,
		val_servicios, val_produccion, cantidad_facturada, costo_unitario,
		retefuente_factura, ica_factura, iva_factura, facturado_a, sede,
		agencia_despacho, remitente, empaque, unidad_servicio, tn_pedido,
		tn_o_cargue, tn_remesa, tn_cumplido, pendiente, cantidad_cumplida,
		flete_manifiesto, retefuente_manifiesto, ica_manifiesto,
		usuario_cumplido_manifiesto, fecha_cumplido_manifiesto, anticipo,
		nro_anticipos, nro_comprob, valor_flete_liquidacion, valor_liquidado,
		retefuente_liquid, ica_liquid, cree_liquid, fecha_liquid, nro_comprob1,
		faltantes_liquidacion, valor_descontar, servicio_integral,
		nombre_ser_especial2, ser_especial_manifiesto, valor_pagado,
		fecha_pago, nro_comprob2, banco, cuenta_bancaria, nro_cheque, tipo_pago,
		origen, destino, producto, conductor, cc_conductor, celular,
		poseedor, cc_nit_poseedor, nro_pedido, observacion_llegada,
		vlr_tarifa_cotizacion_cliente, descripcion_tarifa, fecha_recaudo,
		nro_comprobante_recaudo, creado_por, estado, documento_destinatario,
		destinatario, costo_produccion, prorrateo_costo_estimado_propio,
		prorrateo_costo_estimado_tercero, prorrateo_utilidad_estimada,
		fecha_hora_entrada_cargue, fecha_hora_entrada_descargue
	)
	SELECT 
		s.manifiesto, s.fecha_manifiesto, s.placa, s.remesa, s.remolque, s.configuracion,
		s.tipo_vinculacion, s.orden_cargue, s.remision, s.fecha_remesa, s.fecha_salida_despacho,
		s.fecha_llegada_despacho, s.cumplida, s.fecha_llegada_cargue, s.fecha_salida_cargue,
		s.fecha_llegada_descargue, s.fecha_salida_descargue, s.factura, s.fecha_factura,
		s.fecha_vencimiento, s.val_inicial_remesa, s.val_facturado_separado,
		s.val_facturado_remesa, s.val_declarado_remesa, s.nombre_ser_especial,
		s.val_servicios, s.val_produccion, s.cantidad_facturada, s.costo_unitario,
		s.retefuente_factura, s.ica_factura, s.iva_factura, s.facturado_a, s.sede,
		s.agencia_despacho, s.remitente, s.empaque, s.unidad_servicio, s.tn_pedido,
		s.tn_o_cargue, s.tn_remesa, s.tn_cumplido, s.pendiente, s.cantidad_cumplida,
		s.flete_manifiesto, s.retefuente_manifiesto, s.ica_manifiesto,
		s.usuario_cumplido_manifiesto, s.fecha_cumplido_manifiesto, s.anticipo,
		s.nro_anticipos, s.nro_comprob, s.valor_flete_liquidacion, s.valor_liquidado,
		s.retefuente_liquid, s.ica_liquid, s.cree_liquid, s.fecha_liquid, s.nro_comprob1,
		s.faltantes_liquidacion, s.valor_descontar, s.servicio_integral,
		s.nombre_ser_especial2, s.ser_especial_manifiesto, s.valor_pagado,
		s.fecha_pago, s.nro_comprob2, s.banco, s.cuenta_bancaria, s.nro_cheque, s.tipo_pago,
		s.origen, s.destino, s.producto, s.conductor, s.cc_conductor, s.celular,
		s.poseedor, s.cc_nit_poseedor, s.nro_pedido, s.observacion_llegada,
		s.vlr_tarifa_cotizacion_cliente, s.descripcion_tarifa, s.fecha_recaudo,
		s.nro_comprobante_recaudo, s.creado_por, s.estado, s.documento_destinatario,
		s.destinatario, s.costo_produccion, s.prorrateo_costo_estimado_propio,
		s.prorrateo_costo_estimado_tercero, s.prorrateo_utilidad_estimada,
		s.fecha_hora_entrada_cargue, s.fecha_hora_entrada_descargue
	FROM staging_operaciones_avansat s
	LEFT JOIN operaciones_avansat o
	  ON o.manifiesto = s.manifiesto
	 AND o.fecha_manifiesto = s.fecha_manifiesto
	 AND o.placa = s.placa
	 AND o.remesa = s.remesa
	WHERE o.manifiesto IS NULL;
    
	-- Capturar cantidad de registros insertados
    SET p_inserts = ROW_COUNT();


	-- Crear tabla temporal con registros modificados

	CREATE TEMPORARY TABLE tmp_registros_actualizados AS
	SELECT s.*
	FROM staging_operaciones_avansat s
	JOIN operaciones_avansat o
	  ON o.manifiesto = s.manifiesto
	 AND o.fecha_manifiesto = s.fecha_manifiesto
	 AND o.placa = s.placa
	 AND o.remesa = s.remesa
	WHERE 
		(
			COALESCE(s.remolque, '') <> COALESCE(o.remolque, '') OR
			COALESCE(s.configuracion, '') <> COALESCE(o.configuracion, '') OR
			COALESCE(s.tipo_vinculacion, '') <> COALESCE(o.tipo_vinculacion, '') OR
			COALESCE(s.orden_cargue, '') <> COALESCE(o.orden_cargue, '') OR
			COALESCE(s.remision, '') <> COALESCE(o.remision, '') OR
			COALESCE(s.fecha_remesa, '1900-01-01') <> COALESCE(o.fecha_remesa, '1900-01-01') OR
			COALESCE(s.fecha_salida_despacho, '1900-01-01') <> COALESCE(o.fecha_salida_despacho, '1900-01-01') OR
			COALESCE(s.fecha_llegada_despacho, '1900-01-01') <> COALESCE(o.fecha_llegada_despacho, '1900-01-01') OR
			COALESCE(s.cumplida, '1900-01-01') <> COALESCE(o.cumplida, '1900-01-01') OR
			COALESCE(s.fecha_llegada_cargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_llegada_cargue, '1900-01-01 00:00:00') OR
			COALESCE(s.fecha_salida_cargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_salida_cargue, '1900-01-01 00:00:00') OR
			COALESCE(s.fecha_llegada_descargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_llegada_descargue, '1900-01-01 00:00:00') OR
			COALESCE(s.fecha_salida_descargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_salida_descargue, '1900-01-01 00:00:00') OR
			COALESCE(s.factura, '') <> COALESCE(o.factura, '') OR
			COALESCE(s.fecha_factura, '1900-01-01') <> COALESCE(o.fecha_factura, '1900-01-01') OR
			COALESCE(s.fecha_vencimiento, '1900-01-01') <> COALESCE(o.fecha_vencimiento, '1900-01-01') OR
			COALESCE(s.val_inicial_remesa, 0) <> COALESCE(o.val_inicial_remesa, 0) OR
			COALESCE(s.val_facturado_separado, 0) <> COALESCE(o.val_facturado_separado, 0) OR
			COALESCE(s.val_facturado_remesa, 0) <> COALESCE(o.val_facturado_remesa, 0) OR
			COALESCE(s.val_declarado_remesa, 0) <> COALESCE(o.val_declarado_remesa, 0) OR
			COALESCE(s.nombre_ser_especial, '') <> COALESCE(o.nombre_ser_especial, '') OR
			COALESCE(s.val_servicios, 0) <> COALESCE(o.val_servicios, 0) OR
			COALESCE(s.val_produccion, 0) <> COALESCE(o.val_produccion, 0) OR
			COALESCE(s.cantidad_facturada, 0) <> COALESCE(o.cantidad_facturada, 0) OR
			COALESCE(s.costo_unitario, 0) <> COALESCE(o.costo_unitario, 0) OR
			COALESCE(s.retefuente_factura, 0) <> COALESCE(o.retefuente_factura, 0) OR
			COALESCE(s.ica_factura, 0) <> COALESCE(o.ica_factura, 0) OR
			COALESCE(s.iva_factura, 0) <> COALESCE(o.iva_factura, 0) OR
			COALESCE(s.facturado_a, '') <> COALESCE(o.facturado_a, '') OR
			COALESCE(s.sede, '') <> COALESCE(o.sede, '') OR
			COALESCE(s.agencia_despacho, '') <> COALESCE(o.agencia_despacho, '') OR
			COALESCE(s.remitente, '') <> COALESCE(o.remitente, '') OR
			COALESCE(s.empaque, '') <> COALESCE(o.empaque, '') OR
			COALESCE(s.unidad_servicio, '') <> COALESCE(o.unidad_servicio, '') OR
			COALESCE(s.tn_pedido, 0) <> COALESCE(o.tn_pedido, 0) OR
			COALESCE(s.tn_o_cargue, 0) <> COALESCE(o.tn_o_cargue, 0) OR
			COALESCE(s.tn_remesa, 0) <> COALESCE(o.tn_remesa, 0) OR
			COALESCE(s.tn_cumplido, 0) <> COALESCE(o.tn_cumplido, 0) OR
			COALESCE(s.pendiente, 0) <> COALESCE(o.pendiente, 0) OR
			COALESCE(s.cantidad_cumplida, 0) <> COALESCE(o.cantidad_cumplida, 0) OR
			COALESCE(s.flete_manifiesto, 0) <> COALESCE(o.flete_manifiesto, 0) OR
			COALESCE(s.retefuente_manifiesto, 0) <> COALESCE(o.retefuente_manifiesto, 0) OR
			COALESCE(s.ica_manifiesto, 0) <> COALESCE(o.ica_manifiesto, 0) OR
			COALESCE(s.usuario_cumplido_manifiesto, '') <> COALESCE(o.usuario_cumplido_manifiesto, '') OR
			COALESCE(s.fecha_cumplido_manifiesto, '1900-01-01 00:00:00') <> COALESCE(o.fecha_cumplido_manifiesto, '1900-01-01 00:00:00') OR
			COALESCE(s.anticipo, 0) <> COALESCE(o.anticipo, 0) OR
			COALESCE(s.nro_anticipos, 0) <> COALESCE(o.nro_anticipos, 0) OR
			COALESCE(s.nro_comprob, '') <> COALESCE(o.nro_comprob, '') OR
			COALESCE(s.valor_flete_liquidacion, 0) <> COALESCE(o.valor_flete_liquidacion, 0) OR
			COALESCE(s.valor_liquidado, 0) <> COALESCE(o.valor_liquidado, 0) OR
			COALESCE(s.retefuente_liquid, 0) <> COALESCE(o.retefuente_liquid, 0) OR
			COALESCE(s.ica_liquid, 0) <> COALESCE(o.ica_liquid, 0) OR
			COALESCE(s.cree_liquid, 0) <> COALESCE(o.cree_liquid, 0) OR
			COALESCE(s.fecha_liquid, '1900-01-01') <> COALESCE(o.fecha_liquid, '1900-01-01') OR
			COALESCE(s.nro_comprob1, '') <> COALESCE(o.nro_comprob1, '') OR
			COALESCE(s.faltantes_liquidacion, 0) <> COALESCE(o.faltantes_liquidacion, 0) OR
			COALESCE(s.valor_descontar, 0) <> COALESCE(o.valor_descontar, 0) OR
			COALESCE(s.servicio_integral, 0) <> COALESCE(o.servicio_integral, 0) OR
			COALESCE(s.nombre_ser_especial2, '') <> COALESCE(o.nombre_ser_especial2, '') OR
			COALESCE(s.ser_especial_manifiesto, 0) <> COALESCE(o.ser_especial_manifiesto, 0) OR
			COALESCE(s.valor_pagado, 0) <> COALESCE(o.valor_pagado, 0) OR
			COALESCE(s.fecha_pago, '1900-01-01') <> COALESCE(o.fecha_pago, '1900-01-01') OR
			COALESCE(s.nro_comprob2, '') <> COALESCE(o.nro_comprob2, '') OR
			COALESCE(s.banco, '') <> COALESCE(o.banco, '') OR
			COALESCE(s.cuenta_bancaria, '') <> COALESCE(o.cuenta_bancaria, '') OR
			COALESCE(s.nro_cheque, '') <> COALESCE(o.nro_cheque, '') OR
			COALESCE(s.tipo_pago, '') <> COALESCE(o.tipo_pago, '') OR
			COALESCE(s.origen, '') <> COALESCE(o.origen, '') OR
			COALESCE(s.destino, '') <> COALESCE(o.destino, '') OR
			COALESCE(s.producto, '') <> COALESCE(o.producto, '') OR
			COALESCE(s.conductor, '') <> COALESCE(o.conductor, '') OR
			COALESCE(s.cc_conductor, '') <> COALESCE(o.cc_conductor, '') OR
			COALESCE(s.celular, '') <> COALESCE(o.celular, '') OR
			COALESCE(s.poseedor, '') <> COALESCE(o.poseedor, '') OR
			COALESCE(s.cc_nit_poseedor, '') <> COALESCE(o.cc_nit_poseedor, '') OR
			COALESCE(s.nro_pedido, 0) <> COALESCE(o.nro_pedido, 0) OR
			COALESCE(s.observacion_llegada, '') <> COALESCE(o.observacion_llegada, '') OR
			COALESCE(s.vlr_tarifa_cotizacion_cliente, 0) <> COALESCE(o.vlr_tarifa_cotizacion_cliente, 0) OR
			COALESCE(s.descripcion_tarifa, '') <> COALESCE(o.descripcion_tarifa, '') OR
			COALESCE(s.fecha_recaudo, '1900-01-01') <> COALESCE(o.fecha_recaudo, '1900-01-01') OR
			COALESCE(s.nro_comprobante_recaudo, 0) <> COALESCE(o.nro_comprobante_recaudo, 0) OR
			COALESCE(s.creado_por, '') <> COALESCE(o.creado_por, '') OR
			COALESCE(s.estado, '') <> COALESCE(o.estado, '') OR
			COALESCE(s.documento_destinatario, '') <> COALESCE(o.documento_destinatario, '') OR
			COALESCE(s.destinatario, '') <> COALESCE(o.destinatario, '') OR
			COALESCE(s.costo_produccion, 0) <> COALESCE(o.costo_produccion, 0) OR
			COALESCE(s.prorrateo_costo_estimado_propio, 0) <> COALESCE(o.prorrateo_costo_estimado_propio, 0) OR
			COALESCE(s.prorrateo_costo_estimado_tercero, 0) <> COALESCE(o.prorrateo_costo_estimado_tercero, 0) OR
			COALESCE(s.prorrateo_utilidad_estimada, 0) <> COALESCE(o.prorrateo_utilidad_estimada, 0) OR
			COALESCE(s.fecha_hora_entrada_cargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_hora_entrada_cargue, '1900-01-01 00:00:00') OR
			COALESCE(s.fecha_hora_entrada_descargue, '1900-01-01 00:00:00') <> COALESCE(o.fecha_hora_entrada_descargue, '1900-01-01 00:00:00')
		);

	-- Actualizar solo registros con diferencias reales

	UPDATE operaciones_avansat o
	JOIN tmp_registros_actualizados s
	  ON o.manifiesto = s.manifiesto
	 AND o.fecha_manifiesto = s.fecha_manifiesto
	 AND o.placa = s.placa
	 AND o.remesa = s.remesa
	SET 
	  o.remolque = s.remolque,
	  o.configuracion = s.configuracion,
	  o.tipo_vinculacion = s.tipo_vinculacion,
	  o.orden_cargue = s.orden_cargue,
	  o.remision = s.remision,
	  o.fecha_remesa = s.fecha_remesa,
	  o.fecha_salida_despacho = s.fecha_salida_despacho,
	  o.fecha_llegada_despacho = s.fecha_llegada_despacho,
	  o.cumplida = s.cumplida,
	  o.fecha_llegada_cargue = s.fecha_llegada_cargue,
	  o.fecha_salida_cargue = s.fecha_salida_cargue,
	  o.fecha_llegada_descargue = s.fecha_llegada_descargue,
	  o.fecha_salida_descargue = s.fecha_salida_descargue,
	  o.factura = s.factura,
	  o.fecha_factura = s.fecha_factura,
	  o.fecha_vencimiento = s.fecha_vencimiento,
	  o.val_inicial_remesa = s.val_inicial_remesa,
	  o.val_facturado_separado = s.val_facturado_separado,
	  o.val_facturado_remesa = s.val_facturado_remesa,
	  o.val_declarado_remesa = s.val_declarado_remesa,
	  o.nombre_ser_especial = s.nombre_ser_especial,
	  o.val_servicios = s.val_servicios,
	  o.val_produccion = s.val_produccion,
	  o.cantidad_facturada = s.cantidad_facturada,
	  o.costo_unitario = s.costo_unitario,
	  o.retefuente_factura = s.retefuente_factura,
	  o.ica_factura = s.ica_factura,
	  o.iva_factura = s.iva_factura,
	  o.facturado_a = s.facturado_a,
	  o.sede = s.sede,
	  o.agencia_despacho = s.agencia_despacho,
	  o.remitente = s.remitente,
	  o.empaque = s.empaque,
	  o.unidad_servicio = s.unidad_servicio,
	  o.tn_pedido = s.tn_pedido,
	  o.tn_o_cargue = s.tn_o_cargue,
	  o.tn_remesa = s.tn_remesa,
	  o.tn_cumplido = s.tn_cumplido,
	  o.pendiente = s.pendiente,
	  o.cantidad_cumplida = s.cantidad_cumplida,
	  o.flete_manifiesto = s.flete_manifiesto,
	  o.retefuente_manifiesto = s.retefuente_manifiesto,
	  o.ica_manifiesto = s.ica_manifiesto,
	  o.usuario_cumplido_manifiesto = s.usuario_cumplido_manifiesto,
	  o.fecha_cumplido_manifiesto = s.fecha_cumplido_manifiesto,
	  o.anticipo = s.anticipo,
	  o.nro_anticipos = s.nro_anticipos,
	  o.nro_comprob = s.nro_comprob,
	  o.valor_flete_liquidacion = s.valor_flete_liquidacion,
	  o.valor_liquidado = s.valor_liquidado,
	  o.retefuente_liquid = s.retefuente_liquid,
	  o.ica_liquid = s.ica_liquid,
	  o.cree_liquid = s.cree_liquid,
	  o.fecha_liquid = s.fecha_liquid,
	  o.nro_comprob1 = s.nro_comprob1,
	  o.faltantes_liquidacion = s.faltantes_liquidacion,
	  o.valor_descontar = s.valor_descontar,
	  o.servicio_integral = s.servicio_integral,
	  o.nombre_ser_especial2 = s.nombre_ser_especial2,
	  o.ser_especial_manifiesto = s.ser_especial_manifiesto,
	  o.valor_pagado = s.valor_pagado,
	  o.fecha_pago = s.fecha_pago,
	  o.nro_comprob2 = s.nro_comprob2,
	  o.banco = s.banco,
	  o.cuenta_bancaria = s.cuenta_bancaria,
	  o.nro_cheque = s.nro_cheque,
	  o.tipo_pago = s.tipo_pago,
	  o.origen = s.origen,
	  o.destino = s.destino,
	  o.producto = s.producto,
	  o.conductor = s.conductor,
	  o.cc_conductor = s.cc_conductor,
	  o.celular = s.celular,
	  o.poseedor = s.poseedor,
	  o.cc_nit_poseedor = s.cc_nit_poseedor,
	  o.nro_pedido = s.nro_pedido,
	  o.observacion_llegada = s.observacion_llegada,
	  o.vlr_tarifa_cotizacion_cliente = s.vlr_tarifa_cotizacion_cliente,
	  o.descripcion_tarifa = s.descripcion_tarifa,
	  o.fecha_recaudo = s.fecha_recaudo,
	  o.nro_comprobante_recaudo = s.nro_comprobante_recaudo,
	  o.creado_por = s.creado_por,
	  o.estado = s.estado,
	  o.documento_destinatario = s.documento_destinatario,
	  o.destinatario = s.destinatario,
	  o.costo_produccion = s.costo_produccion,
	  o.prorrateo_costo_estimado_propio = s.prorrateo_costo_estimado_propio,
	  o.prorrateo_costo_estimado_tercero = s.prorrateo_costo_estimado_tercero,
	  o.prorrateo_utilidad_estimada = s.prorrateo_utilidad_estimada,
	  o.fecha_hora_entrada_cargue = s.fecha_hora_entrada_cargue,
	  o.fecha_hora_entrada_descargue = s.fecha_hora_entrada_descargue;
      
	-- Capturar cantidad de registros actualizados
    SET p_updates = ROW_COUNT();

	-- Duración del procedimiento en segundos
	SET p_duracion = TIMESTAMPDIFF(SECOND, @inicio, NOW());

	COMMIT;

	END//

DELIMITER ;

-- ######################################### Permisos àra Usuarios####################################
 
-- Procedimiento para la asignación de permisos básicos a todos los usuarios creados con antelación

DROP PROCEDURE IF EXISTS AsignarPrivilegiosUsuariosMySQL;

DELIMITER //

CREATE PROCEDURE AsignarPrivilegiosUsuariosMySQL()
SQL SECURITY DEFINER
BEGIN
    -- ----------------------------------------------------------------
    -- Variables de control
    -- ----------------------------------------------------------------
    DECLARE done       BOOL DEFAULT FALSE;
    DECLARE v_usuario  VARCHAR(64);
    DECLARE v_host     VARCHAR(64);

    -- Diagnóstico
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno    INT;
    DECLARE v_msg      TEXT;

    -- ----------------------------------------------------------------
    -- Cursores
    -- ----------------------------------------------------------------
    DECLARE cur_segmentos CURSOR FOR
        SELECT '192.168.0.%'   UNION ALL
        SELECT '192.168.100.%' UNION ALL
        SELECT '192.168.101.%';

    DECLARE cur_usuarios CURSOR FOR
        SELECT usuario
        FROM   usuarios
        WHERE  usuario NOT IN ('root','mysql.sys');

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- ----------------------------------------------------------------
    -- Handler de error
    -- ----------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno    = MYSQL_ERRNO,
            v_msg      = MESSAGE_TEXT;

        -- Cierra cursores (no falla si ya están cerrados)
        CLOSE cur_usuarios;
        CLOSE cur_segmentos;

        SELECT '❌  Error al asignar privilegios. Se abortó la operación.' AS mensaje,
               v_sqlstate AS codigo_sql,
               v_errno    AS errno,
               v_msg      AS detalle;
    END;

    -- ----------------------------------------------------------------
    -- Lógica principal
    -- ----------------------------------------------------------------
    OPEN cur_usuarios;

    usuarios_loop: LOOP
        FETCH cur_usuarios INTO v_usuario;
        IF done THEN
            LEAVE usuarios_loop;
        END IF;

        OPEN cur_segmentos;
        segmentos_loop: LOOP
            FETCH cur_segmentos INTO v_host;
            IF done THEN
                SET done = FALSE;
                LEAVE segmentos_loop;
            END IF;

            -- 1) GRANT USAGE
            SET @sql := CONCAT(
                "GRANT USAGE ON pypdb.* TO '", v_usuario, "'@'", v_host, "'"
            );
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            -- 2) GRANT SELECT
            SET @sql := CONCAT(
                "GRANT SELECT ON pypdb.vista_usuarios_departamentos TO '",
                v_usuario, "'@'", v_host, "'"
            );
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            -- 3) GRANT EXECUTE sp_sincronizar_cambio_password
            SET @sql := CONCAT(
                "GRANT EXECUTE ON PROCEDURE pypdb.sp_sincronizar_cambio_password TO '",
                v_usuario, "'@'", v_host, "'"
            );
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            -- 4) GRANT EXECUTE registrar_log_conexion
            SET @sql := CONCAT(
                "GRANT EXECUTE ON PROCEDURE pypdb.registrar_log_conexion TO '",
                v_usuario, "'@'", v_host, "'"
            );
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
            
            -- 5) GRANT CREATE USER
			SET @sql := CONCAT(
				"GRANT CREATE USER ON *.* TO '", v_usuario, "'@'", v_host, "'"
			);
			PREPARE stmt FROM @sql;
			EXECUTE stmt;
			DEALLOCATE PREPARE stmt;
            
        END LOOP segmentos_loop;
        CLOSE cur_segmentos;
    END LOOP usuarios_loop;

    CLOSE cur_usuarios;

    -- ----------------------------------------------------------------
    -- Mensaje final
    -- ----------------------------------------------------------------
    SELECT '✅  Privilegios asignados exitosamente.' AS mensaje;
END //

DELIMITER ;





-- Procedimiento Almacenado para la asignacion de permisos específicos de usuario por departamento

DELIMITER //

CREATE PROCEDURE AsignarPermisosDepartamento(IN p_departamento_id INT)
BEGIN
    -- ✅ Primero las variables
    DECLARE done_users INT DEFAULT FALSE;
    DECLARE done_perms INT DEFAULT FALSE;

    DECLARE v_usuario VARCHAR(50);
    DECLARE v_tipo_objeto VARCHAR(20); -- No ENUM, para mayor flexibilidad
    DECLARE v_nombre_objeto VARCHAR(100);
    DECLARE v_tipo_permiso VARCHAR(20);
    DECLARE stmt TEXT;

    -- ✅ Luego los cursores
    DECLARE cur_usuarios CURSOR FOR
        SELECT usuario FROM usuarios WHERE departamento_id = p_departamento_id;

    DECLARE cur_permisos CURSOR FOR
        SELECT tipo_objeto, nombre_objeto, tipo_permiso
        FROM permisos_departamento_objetos
        WHERE departamento_id = p_departamento_id;

    -- ✅ Luego los manejadores
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_users = TRUE;
   -- DECLARE EXIT HANDLER FOR SQLEXCEPTION
   -- BEGIN
   --    ROLLBACK;
   --     SELECT 'Error al asignar permisos.' AS mensaje;
   -- END;

    START TRANSACTION;

    OPEN cur_usuarios;

    user_loop: LOOP
        FETCH cur_usuarios INTO v_usuario;
        IF done_users THEN
            LEAVE user_loop;
        END IF;

        SET done_perms = FALSE;
        OPEN cur_permisos;

        perm_loop: LOOP
            FETCH cur_permisos INTO v_tipo_objeto, v_nombre_objeto, v_tipo_permiso;
            IF done_perms THEN
                LEAVE perm_loop;
            END IF;

            -- GRANT para @192.168.0.%
            SET @stmt := CONCAT(
                'GRANT ', v_tipo_permiso, ' ON pypdb.',
                IF(v_tipo_objeto = 'PROCEDIMIENTO', '', '`'),
                v_nombre_objeto,
                IF(v_tipo_objeto = 'PROCEDIMIENTO', '', '`'),
                ' TO \'', v_usuario, '\'@\'192.168.0.%\';'
            );
            PREPARE stmt1 FROM @stmt;
            EXECUTE stmt1;
            DEALLOCATE PREPARE stmt1;

            -- GRANT para @192.168.100.%
            SET @stmt := CONCAT(
                'GRANT ', v_tipo_permiso, ' ON pypdb.',
                IF(v_tipo_objeto = 'PROCEDIMIENTO', '', '`'),
                v_nombre_objeto,
                IF(v_tipo_objeto = 'PROCEDIMIENTO', '', '`'),
                ' TO \'', v_usuario, '\'@\'192.168.100.%\';'
            );
            PREPARE stmt2 FROM @stmt;
            EXECUTE stmt2;
            DEALLOCATE PREPARE stmt2;

        END LOOP perm_loop;

        CLOSE cur_permisos;

    END LOOP user_loop;

    CLOSE cur_usuarios;

    COMMIT;

    SELECT 'Permisos asignados exitosamente.' AS mensaje;
END//

DELIMITER ;


-- ##################################################################################################
-- ########################### PROCEDIMIENTOS ALMACENADOS PARA ETL DE VEHÍCULOS PROPIOS ###########################
-- ##################################################################################################

-- ==================================================================================================
-- 1. PROCEDIMIENTO PARA LIMPIAR LA TABLA DE STAGING
-- Descripción: Elimina todos los registros de la tabla staging_vehiculos_propios para preparar una nueva carga.
-- ==================================================================================================
DELIMITER //
CREATE PROCEDURE limpiar_staging_vehiculos_propios()
BEGIN
    -- Trunca la tabla para un reinicio rápido y eficiente
    TRUNCATE TABLE staging_vehiculos_propios;
END //
DELIMITER ;

-- ==================================================================================================
-- 2. PROCEDIMIENTO PARA INSERTAR DATOS EN LA TABLA DE STAGING
-- Descripción: Inserta un único registro en la tabla staging_vehiculos_propios.
--              Incluye un manejador de errores que registra fallos en la tabla log_errores_etl.
-- ==================================================================================================
DELIMITER //
CREATE PROCEDURE insertar_en_staging_vehiculos_propios (
    IN p_placa VARCHAR(10),
    IN p_id_tipologia INT,
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(50),
    IN p_kilometraje FLOAT,
    IN p_fecha_ult_med DATETIME,
    IN p_anio INT,
    IN p_tipo_combustible VARCHAR(100),
    IN p_max_km_diario DECIMAL(10,2),
    IN p_prom_km_diario DECIMAL(10,2),
    IN p_id_base INT,
    IN p_centro_costo VARCHAR(100),
    IN p_vin VARCHAR(100),
    IN p_propietario VARCHAR(255),
    IN p_motor VARCHAR(100),
    IN p_capacidad DECIMAL(10,2),
    IN p_num_chasis VARCHAR(100),
    IN p_num_serial VARCHAR(100),
    IN p_fecha_compra DATE,
    IN p_costo DECIMAL(20,2),
    IN p_fecha_creacion DATETIME,
    IN p_creado_por VARCHAR(100)
)
BEGIN
    -- Manejador de errores para capturar excepciones SQL durante la inserción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Llama a un procedimiento genérico para registrar el error
        CALL registrar_error_etl(
            'insertar_en_staging_vehiculos_propios',
            'Error al insertar en staging_vehiculos_propios',
            CONCAT('Placa: ', p_placa) -- Se registra la placa para identificar el registro fallido
        );
        -- Señala el error para detener la ejecución si es necesario
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en inserción a staging de vehículos detectado';
    END;

    -- Inserción de los datos en la tabla de staging
    INSERT INTO staging_vehiculos_propios (
        placa, id_tipologia, marca, modelo, kilometraje, fecha_ult_med, anio,
        tipo_combustible, max_km_diario, prom_km_diario, id_base, centro_costo,
        vin, propietario, motor, capacidad, num_chasis, num_serial, fecha_compra,
        costo, fecha_creacion, creado_por
    )
    VALUES (
        p_placa, p_id_tipologia, p_marca, p_modelo, p_kilometraje, p_fecha_ult_med, p_anio,
        p_tipo_combustible, p_max_km_diario, p_prom_km_diario, p_id_base, p_centro_costo,
        p_vin, p_propietario, p_motor, p_capacidad, p_num_chasis, p_num_serial, p_fecha_compra,
        p_costo, p_fecha_creacion, p_creado_por
    );
END //
DELIMITER ;

-- ==================================================================================================
-- 3. PROCEDIMIENTO PARA SINCRONIZAR DATOS DESDE STAGING A LA TABLA PRINCIPAL
-- Descripción: Inserta nuevos registros y actualiza los existentes en la tabla vehiculos_propios
--              a partir de los datos en staging_vehiculos_propios.
--              Utiliza la 'placa' como clave de negocio para la comparación.
-- Parámetros de Salida:
--      p_duracion: Tiempo total de ejecución del procedimiento en segundos.
--      p_inserts:  Cantidad de registros nuevos insertados.
--      p_updates:  Cantidad de registros actualizados.
-- ==================================================================================================
DELIMITER //
CREATE PROCEDURE sp_sincronizar_vehiculos_propios(
    OUT p_duracion INT,
    OUT p_inserts INT,
    OUT p_updates INT
)
BEGIN
    -- Manejador para revertir la transacción en caso de cualquier error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en la sincronización de vehiculos_propios';
    END;

    -- Inicia la transacción para asegurar la atomicidad de la operación
    START TRANSACTION;

    -- Marca el tiempo de inicio del proceso
    SET @inicio = NOW();

    -- Inicializa los contadores de salida
    SET p_inserts = 0;
    SET p_updates = 0;

    -- --------------------------------------------------------------------------
    -- PASO 1: INSERTAR REGISTROS NUEVOS
    -- Se insertan los vehículos de staging que no existen en la tabla principal.
    -- --------------------------------------------------------------------------
    INSERT INTO vehiculos_propios (
        placa, id_tipologia, marca, modelo, kilometraje, fecha_ult_med, anio,
        tipo_combustible, max_km_diario, prom_km_diario, id_base, centro_costo,
        vin, propietario, motor, capacidad, num_chasis, num_serial, fecha_compra,
        costo, fecha_creacion, creado_por
    )
    SELECT
        s.placa, s.id_tipologia, s.marca, s.modelo, s.kilometraje, s.fecha_ult_med, s.anio,
        s.tipo_combustible, s.max_km_diario, s.prom_km_diario, s.id_base, s.centro_costo,
        s.vin, s.propietario, s.motor, s.capacidad, s.num_chasis, s.num_serial, s.fecha_compra,
        s.costo, s.fecha_creacion, s.creado_por
    FROM staging_vehiculos_propios s
    LEFT JOIN vehiculos_propios v ON s.placa = v.placa
    WHERE v.placa IS NULL; -- La condición para identificar un registro nuevo

    -- Captura la cantidad de registros insertados
    SET p_inserts = ROW_COUNT();

    -- --------------------------------------------------------------------------
    -- PASO 2: ACTUALIZAR REGISTROS EXISTENTES
    -- Se actualizan los vehículos que ya existen pero tienen datos diferentes.
    -- Se usa COALESCE para manejar correctamente los valores NULL en las comparaciones.
    -- --------------------------------------------------------------------------
    UPDATE vehiculos_propios v
    JOIN staging_vehiculos_propios s ON v.placa = s.placa
    SET
        v.id_tipologia = s.id_tipologia,
        v.marca = s.marca,
        v.modelo = s.modelo,
        v.kilometraje = s.kilometraje,
        v.fecha_ult_med = s.fecha_ult_med,
        v.anio = s.anio,
        v.tipo_combustible = s.tipo_combustible,
        v.max_km_diario = s.max_km_diario,
        v.prom_km_diario = s.prom_km_diario,
        v.id_base = s.id_base,
        v.centro_costo = s.centro_costo,
        v.vin = s.vin,
        v.propietario = s.propietario,
        v.motor = s.motor,
        v.capacidad = s.capacidad,
        v.num_chasis = s.num_chasis,
        v.num_serial = s.num_serial,
        v.fecha_compra = s.fecha_compra,
        v.costo = s.costo,
        v.fecha_creacion = s.fecha_creacion,
        v.creado_por = s.creado_por
    WHERE
        -- Compara cada campo para detectar diferencias, manejando NULLs
        COALESCE(v.id_tipologia, 0) <> COALESCE(s.id_tipologia, 0) OR
        COALESCE(v.marca, '') <> COALESCE(s.marca, '') OR
        COALESCE(v.modelo, '') <> COALESCE(s.modelo, '') OR
        COALESCE(v.kilometraje, 0) <> COALESCE(s.kilometraje, 0) OR
        COALESCE(v.fecha_ult_med, '1900-01-01 00:00:00') <> COALESCE(s.fecha_ult_med, '1900-01-01 00:00:00') OR
        COALESCE(v.anio, 0) <> COALESCE(s.anio, 0) OR
        COALESCE(v.tipo_combustible, '') <> COALESCE(s.tipo_combustible, '') OR
        COALESCE(v.max_km_diario, 0.00) <> COALESCE(s.max_km_diario, 0.00) OR
        COALESCE(v.prom_km_diario, 0.00) <> COALESCE(s.prom_km_diario, 0.00) OR
        COALESCE(v.id_base, 0) <> COALESCE(s.id_base, 0) OR
        COALESCE(v.centro_costo, '') <> COALESCE(s.centro_costo, '') OR
        COALESCE(v.vin, '') <> COALESCE(s.vin, '') OR
        COALESCE(v.propietario, '') <> COALESCE(s.propietario, '') OR
        COALESCE(v.motor, '') <> COALESCE(s.motor, '') OR
        COALESCE(v.capacidad, 0.00) <> COALESCE(s.capacidad, 0.00) OR
        COALESCE(v.num_chasis, '') <> COALESCE(s.num_chasis, '') OR
        COALESCE(v.num_serial, '') <> COALESCE(s.num_serial, '') OR
        COALESCE(v.fecha_compra, '1900-01-01') <> COALESCE(s.fecha_compra, '1900-01-01') OR
        COALESCE(v.costo, 0.00) <> COALESCE(s.costo, 0.00) OR
        COALESCE(v.fecha_creacion, '1900-01-01 00:00:00') <> COALESCE(s.fecha_creacion, '1900-01-01 00:00:00') OR
        COALESCE(v.creado_por, '') <> COALESCE(s.creado_por, '');

    -- Captura la cantidad de registros actualizados
    SET p_updates = ROW_COUNT();

    -- Calcula la duración total del procedimiento en segundos
    SET p_duracion = TIMESTAMPDIFF(SECOND, @inicio, NOW());

    -- Confirma la transacción si todo ha ido bien
    COMMIT;

END //
DELIMITER ;

-- ############### Procedimientos Almacenados para seguridad ###############################


-- Procedimiento almacenado de insercion de datos Bitácora Seguridad
DELIMITER //
CREATE PROCEDURE insert_bitacora_operacion_trafico(
    IN  p_fecha                 DATE,
    IN  p_turno                 ENUM('06:00-18:00','18:00-06:00'),
    IN  p_controlador_entrega   INT,
    IN  p_controlador_recibe    INT,
    IN  p_observaciones         TEXT,
    IN  p_usuario               VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    SET @usuario_actual = p_usuario;
    INSERT INTO bitacora_operacion_trafico (
        fecha, turno, controlador_entrega,
        controlador_recibe, observaciones
    ) VALUES (
        p_fecha, p_turno, p_controlador_entrega,
        p_controlador_recibe, p_observaciones
    );
    COMMIT;
    -- aquí devolvemos el ID recién creado como un recordset
    SELECT LAST_INSERT_ID() AS entrada_id;
END //
DELIMITER ;


-- Procedimiento almacenado para ingresar datos de vehículos planiollados en Avansat en el turno de controlador

DELIMITER //

CREATE PROCEDURE insertar_trafico_avansat (
    IN p_entrada_id INT,
    IN p_cliente VARCHAR(100),
    IN p_cant_vehiculos INT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
    
    -- Registrar usuario actual
    SET @usuario_actual = p_usuario;

    -- Insertar datos
    INSERT INTO trafico_avansat (entrada_id, cliente, cant_vehiculos)
    VALUES (p_entrada_id, p_cliente, p_cant_vehiculos);

    COMMIT;
END //

DELIMITER ;

-- procedimieno almacenado INSERT en tabla no_planillados_avansat

-- Crear o reemplazar el procedimiento
DROP PROCEDURE IF EXISTS insertar_no_planillados_avansat;

DELIMITER //

CREATE PROCEDURE insertar_no_planillados_avansat (
    IN p_entrada_id INT,
    IN p_placa      VARCHAR(6),
    IN p_detalle    TEXT,
    IN p_usuario    VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

        /* Poner el usuario a disposición de los triggers */
        SET @usuario_actual = p_usuario;

        /* Insertar registro */
        INSERT INTO no_planillados_avansat (
            entrada_id, placa, detalle
        ) VALUES (
            p_entrada_id, p_placa, p_detalle
        );

    COMMIT;
END //
DELIMITER ;


-- Procedimieto almacenado INSERT tabla escoltas

-- Elimina el procedimiento si ya existe para evitar errores al recrearlo.
DROP PROCEDURE IF EXISTS insertar_escoltas;

-- Cambia el delimitador para poder definir el cuerpo del procedimiento.
DELIMITER //

CREATE PROCEDURE insertar_escoltas (
    IN p_entrada_id INT,
    IN p_detalle    TEXT,
    IN p_usuario    VARCHAR(100)
)
BEGIN
    -- Define un manejador de errores que revertirá la transacción si ocurre una excepción.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    -- Inicia la transacción.
    START TRANSACTION;

        -- Almacena el usuario enviado desde VBA en una variable de sesión
        -- para que esté disponible para los triggers de auditoría.
        SET @usuario_actual = p_usuario;

        -- Inserta el nuevo registro en la tabla de novedades de escoltas.
        INSERT INTO escoltas (
            entrada_id, detalle
        ) VALUES (
            p_entrada_id, p_detalle
        );

    -- Confirma la transacción si no hubo errores.
    COMMIT;
END //

-- Restablece el delimitador estándar.
DELIMITER ;

-- Procedimiento alamcenado INSERT tabla botones_panico
-- Elimina el procedimiento si ya existe para evitar errores al recrearlo.
DROP PROCEDURE IF EXISTS insertar_boton_panico;

-- Cambia el delimitador para poder definir el cuerpo del procedimiento.
DELIMITER //

CREATE PROCEDURE insertar_boton_panico (
    IN p_fecha DATE,
    IN p_hora_solicitud_activacion TIME,
    IN p_tiempo_respuesta INT,
    IN p_placa_vehiculo VARCHAR(6),
    IN p_empresa_satelital VARCHAR(50),
    IN p_tipo_flota ENUM('Propia','Tercero'),
    IN p_ubicaciones_vehiculo TEXT,
    IN p_novedades ENUM('No Reporta','Si Reporta'),
    IN p_observaciones TEXT,
    IN p_gestion TEXT,
    IN p_fecha_cierre_novedad DATE,
    IN p_controlador INT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    -- Define un manejador de errores que revertirá la transacción si ocurre una excepción.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    -- Inicia la transacción.
    START TRANSACTION;

        -- Almacena el usuario enviado desde VBA en una variable de sesión
        -- para que esté disponible para los triggers de auditoría.
        SET @usuario_actual = p_usuario;

        -- Inserta el nuevo registro en la tabla de botones de pánico.
        INSERT INTO botones_panico (
            fecha, hora_solicitud_activacion, tiempo_respuesta, placa_vehiculo,
            empresa_satelital, tipo_flota, ubicaciones_vehiculo, novedades,
            observaciones, gestion, fecha_cierre_novedad, controlador
        ) VALUES (
            p_fecha, p_hora_solicitud_activacion, p_tiempo_respuesta, p_placa_vehiculo,
            p_empresa_satelital, p_tipo_flota, p_ubicaciones_vehiculo, p_novedades,
            p_observaciones, p_gestion, p_fecha_cierre_novedad, p_controlador
        );

    -- Confirma la transacción si no hubo errores.
    COMMIT;
END //

-- Restablece el delimitador estándar.
DELIMITER ;


-- procedimiento almacenado para insertar en la tabla pausas_activas
-- Elimina el procedimiento si ya existe para evitar errores.
DROP PROCEDURE IF EXISTS insertar_pausa_activa;

-- Cambia el delimitador.
DELIMITER //

CREATE PROCEDURE insertar_pausa_activa (
    IN p_fecha DATE,
    IN p_hora TIME,
    IN p_tiempo_conduccion DECIMAL(10,2),
    IN p_pausa_real TINYINT,
    IN p_origen INT,
    IN p_destino INT,
    IN p_placa VARCHAR(6),
    IN p_novedad TINYINT,
    IN p_observaciones TEXT,
    IN p_fecha_reporte DATE,
    IN p_controlador INT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    -- Manejador de errores mejorado para diagnóstico.
    DECLARE v_error_message VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Captura el mensaje de error real de MySQL.
        GET DIAGNOSTICS CONDITION 1 v_error_message = MESSAGE_TEXT;
        ROLLBACK;
        -- Lanza un nuevo error personalizado que Access SÍ podrá ver.
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END;

    -- Inicia la transacción.
    START TRANSACTION;
        SET @usuario_actual = p_usuario;
        INSERT INTO pausas_acivas (
            fecha, hora, tiempo_conduccion, pausa_real, origen,
            destino, placa, novedad, observaciones, fecha_reporte, controlador
        ) VALUES (
            p_fecha, p_hora, p_tiempo_conduccion, p_pausa_real, p_origen,
            p_destino, p_placa, p_novedad, p_observaciones, p_fecha_reporte, p_controlador
        );
    COMMIT;
END //

-- Restablece el delimitador.
DELIMITER ;

-- Procedimiento Almacenado de inserción de registro pernocte flota propia
DROP PROCEDURE IF EXISTS sp_insertar_pernocte_flota_propia;

DELIMITER //

CREATE PROCEDURE sp_insertar_pernocte_flota_propia (
    IN p_fecha DATE,
    IN p_placa VARCHAR(20),
    IN p_lugar_pernocte TEXT,
    IN p_controlador INT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    -- Declaración de variables para manejo de errores
    DECLARE v_error_message VARCHAR(255);
    
    -- Definición del manejador de excepciones
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Captura el mensaje de error real
        GET DIAGNOSTICS CONDITION 1 v_error_message = MESSAGE_TEXT;
        ROLLBACK;
        -- Lanza el error para que Access lo reciba
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END;

    -- Inicio de la transacción
    START TRANSACTION;
        -- Auditoría (opcional, pero buena práctica)
        SET @usuario_actual = p_usuario;
        
        -- Inserción de datos
        INSERT INTO pernocte_flota_propia (
            fecha,
            placa,
            lugar_pernocte,
            controlador
        ) VALUES (
            p_fecha,
            p_placa,
            p_lugar_pernocte,
            p_controlador
        );
        
    -- Confirmar cambios
    COMMIT;
END //

DELIMITER ;



-- Procedimiento almacenado para insertar datos de Solicitud auxiliar Tercero

DROP PROCEDURE IF EXISTS Insertar_Auxiliar_Tercero;

DELIMITER //

CREATE PROCEDURE Insertar_Auxiliar_Tercero(
    IN p_fecha DATE,
    IN p_tipo_documento ENUM('CC','TI','CE','PA','PEP','PPT'),
    IN p_documento VARCHAR(20),
    IN p_fecha_nacimiento DATE,
    IN p_nombre VARCHAR(100),
    IN p_grupo_sanguineo ENUM('A','B','AB','O','N/D'),
    IN p_rh ENUM('+','-','N/D'),
    IN p_direccion VARCHAR(255),
    IN p_ciudad INT,
    IN p_eps VARCHAR(200),
    IN p_arl VARCHAR(200),
    IN p_usuario VARCHAR(100) -- El parámetro p_estatus ha sido removido
)
BEGIN
    -- Declarar un handler para errores SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Si ocurre un error, revertir la transacción
        ROLLBACK;
        -- Opcional: Puedes loguear el error o retornar un mensaje
        -- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al insertar auxiliar_tercero.';
    END;

    -- Iniciar la transacción
    START TRANSACTION;

    -- Establecer el usuario actual en una variable de sesión
    SET @usuario_actual = p_usuario;

    -- Insertar los datos en la tabla auxiliares_terceros
    INSERT INTO `auxiliares_terceros` (
        `fecha`,
        `tipo_documento`,
        `documento`,
        `fecha_nacimiento`,
        `nombre`,
        `grupo_sanguineo`,
        `rh`,
        `direccion`,
        `ciudad`,
        `eps`,
        `arl`,
        `estatus` -- Ahora 'estatus' se asigna internamente
    ) VALUES (
        p_fecha,
        p_tipo_documento,
        p_documento,
        p_fecha_nacimiento,
        p_nombre,
        p_grupo_sanguineo,
        p_rh,
        p_direccion,
        p_ciudad,
        p_eps,
        p_arl,
        'Inactivo' -- Valor fijo 'Inactivo' asignado directamente
    );

    -- Confirmar la transacción si todo fue exitoso
    COMMIT;

END //

DELIMITER ;

-- ############################################## CAMBIAR CONTRASEÑA DE USUARIO #########################################
-- Procedimiento Almacenado para sincronizar la contraseña de un usuario en los tres segmentos de red
-- ETHERNET: 192.168.0.0/24, WiFi: 192.168.100.0/24, VPN: 192.168.101.0/24 (porque no hay servidor de dominio)

DROP PROCEDURE IF EXISTS sp_sincronizar_cambio_password;

DELIMITER //

CREATE PROCEDURE sp_sincronizar_cambio_password(
    IN p_usuario VARCHAR(255),
    IN p_password_actual VARCHAR(255),    -- Parámetro solo con fines de claridad/registro
    IN p_nueva_password VARCHAR(255)
)
BEGIN
    -- AVISO: la validación real de la contraseña actual debe hacerse en el frontend (Access)
    -- Antes de llamar a este procedimiento, intente conectarse usando p_usuario@segmento y p_password_actual
    -- Si la conexión es exitosa, entonces permita llamar al SP con la nueva clave.

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se pudo actualizar la contraseña para todos los segmentos. Verifique existencia del usuario en los 3.';
    END;

    -- Segmento ETHERNET
    SET @sql1 = CONCAT('ALTER USER ''', p_usuario, '''@''192.168.0.%'' IDENTIFIED BY ''', p_nueva_password, ''' PASSWORD EXPIRE INTERVAL 30 DAY;');
    PREPARE stmt1 FROM @sql1;
    EXECUTE stmt1;
    DEALLOCATE PREPARE stmt1;

    -- Segmento WiFi
    SET @sql2 = CONCAT('ALTER USER ''', p_usuario, '''@''192.168.100.%'' IDENTIFIED BY ''', p_nueva_password, ''' PASSWORD EXPIRE INTERVAL 30 DAY;');
    PREPARE stmt2 FROM @sql2;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;

    -- Segmento VPN
    SET @sql3 = CONCAT('ALTER USER ''', p_usuario, '''@''192.168.101.%'' IDENTIFIED BY ''', p_nueva_password, ''' PASSWORD EXPIRE INTERVAL 30 DAY;');
    PREPARE stmt3 FROM @sql3;
    EXECUTE stmt3;
    DEALLOCATE PREPARE stmt3;

END //

DELIMITER ;

-- Procedimiento alamcenado para Insertar registo inicial para Backoffice
DROP PROCEDURE IF EXISTS Insertar_BackOffice_Apertura;

DELIMITER //

CREATE PROCEDURE Insertar_BackOffice_Apertura(
    IN p_fecha DATE,
    IN p_estacion INT,
    IN p_servicio INT,
    IN p_driver INT,
    IN p_tipo_pago VARCHAR(20),
    IN p_proveedor ENUM('PYP','TCR'),
    IN p_backof_1 VARCHAR(20),
    IN p_hora_inicial TIME,
    IN p_consecutivo VARCHAR(200),
    IN p_valor DECIMAL(10,2),
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_backoffice_id INT;

    -- Handler de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al insertar registro BackOffice y Caja Menor.';
    END;

    START TRANSACTION;

    -- Variable de sesión
    SET @usuario_actual = p_usuario;

    -- Insertar en backoffice
    INSERT INTO backoffice (
        fecha,
        estacion,
        servicio,
        driver,
        tipo_pago,
        proveedor,
        backof_1,
        hora_inicial,
        hora_final
    ) VALUES (
        p_fecha,
        p_estacion,
        p_servicio,
        p_driver,
        p_tipo_pago,
        p_proveedor,
        p_backof_1,
        p_hora_inicial,
        NULL
    );

    -- Capturar el ID recién insertado
    SET v_backoffice_id = LAST_INSERT_ID();

    -- Si se proporcionó consecutivo y valor, insertar en caja_menor_operaciones
    IF p_consecutivo IS NOT NULL AND p_valor IS NOT NULL THEN
        INSERT INTO caja_menor_operaciones (
            operacion_id,
            consecutivo,
            valor,
            tipo_origen,
            backoffice_id
        ) VALUES (
            NULL,
            p_consecutivo,
            p_valor,
            'backoffice',
            v_backoffice_id
        );
    END IF;

    COMMIT;
END //

DELIMITER ;

-- Procedimiento alamcenado para Actualizar registo inicial para Backoffice
DROP PROCEDURE IF EXISTS Actualizar_BackOffice_Cierre;

DELIMITER //

CREATE PROCEDURE Actualizar_BackOffice_Cierre(
  IN p_backoffice_id INT,
  IN p_hora_final TIME,
  IN p_usuario VARCHAR(100)
)
BEGIN
  DECLARE v_count INT;
  DECLARE v_hora_final_actual TIME;

  -- Handler para errores SQL
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Error al procesar cierre BackOffice.';
  END;

  START TRANSACTION;

  -- Fijar usuario para triggers/auditoría
  SET @usuario_actual = p_usuario;

  -- 1) Verificar existencia
  SELECT COUNT(*) 
    INTO v_count
  FROM backoffice
  WHERE backoffice_id = p_backoffice_id;
  IF v_count = 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se encontró registro BackOffice.';
  END IF;

  -- 2) Obtener hora_final actual
  SELECT hora_final
    INTO v_hora_final_actual
  FROM backoffice
  WHERE backoffice_id = p_backoffice_id
  LIMIT 1;
  IF v_hora_final_actual IS NOT NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Registro BackOffice ya cerrado.';
  END IF;

  -- 3) Aplicar cierre
  UPDATE backoffice
  SET hora_final = p_hora_final
  WHERE backoffice_id = p_backoffice_id;

  COMMIT;
END //
DELIMITER ;


-- Procedimiento almacenado para opcion otros en formulario Back_Office
DROP PROCEDURE IF EXISTS Insertar_BackOffice_Con_Observacion;

DELIMITER //

CREATE PROCEDURE Insertar_BackOffice_Con_Observacion(
    IN p_fecha          DATE,
    IN p_estacion       INT,
    IN p_servicio       INT,
    IN p_driver         INT,
    IN p_tipo_pago      VARCHAR(20),
    IN p_proveedor      ENUM('PYP','TCR'),
    IN p_backof_1       VARCHAR(20),
    IN p_hora_inicial   TIME,
    IN p_hora_final     TIME,
    IN p_observacion    TEXT,
    IN p_consecutivo    VARCHAR(200),
    IN p_valor          DECIMAL(10,2),
    IN p_usuario        VARCHAR(100)
)
BEGIN
    DECLARE v_backoffice_id INT;

    -- Handler de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Error al insertar registro en BackOffice, Observaciones o Caja Menor.'; 
    END;

    START TRANSACTION;

    -- Variable de sesión
    SET @usuario_actual = p_usuario;

    -- Insertar en backoffice
    INSERT INTO backoffice (
        fecha,
        estacion,
        servicio,
        driver,
        tipo_pago,
        proveedor,
        backof_1,
        hora_inicial,
        hora_final
    ) VALUES (
        p_fecha,
        p_estacion,
        p_servicio,
        p_driver,
        p_tipo_pago,
        p_proveedor,
        p_backof_1,
        p_hora_inicial,
        p_hora_final
    );

    -- Capturar el ID recién insertado
    SET v_backoffice_id = LAST_INSERT_ID();

    -- Insertar en observaciones_otros
    INSERT INTO observaciones_otros (
        backoffice_id,
        observacion
    ) VALUES (
        v_backoffice_id,
        p_observacion
    );

    -- Si se proporcionó consecutivo y valor, insertar en caja_menor_operaciones
    IF p_consecutivo IS NOT NULL AND p_valor IS NOT NULL THEN
        INSERT INTO caja_menor_operaciones (
            consecutivo,
            valor,
            tipo_origen,
            backoffice_id
        ) VALUES (
            p_consecutivo,
            p_valor,
            'backoffice',
            v_backoffice_id
        );
    END IF;

    COMMIT;
END //

DELIMITER ;


-- Procedimiento almacenado para recarga de vehiculos adicionando OTs y actualizando cantidad de envios

DROP PROCEDURE IF EXISTS actualizar_operacion_y_ots;

DELIMITER //

CREATE PROCEDURE actualizar_operacion_y_ots (
    IN p_operacion_id INT,
    IN p_nueva_cantidad_envios INT,
    IN p_json_ots LONGTEXT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_count INT;
    DECLARE v_existente INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;
    DECLARE num_ots INT;
    DECLARE ot_val VARCHAR(30);

    -- Handler para errores SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Error al actualizar operación y OTs.';
    END;

    START TRANSACTION;

    -- Fijar usuario para triggers/auditoría
    SET @usuario_actual = p_usuario;

    -- 1) Verificar existencia de la operación
    SELECT COUNT(*)
      INTO v_count
    FROM operaciones
    WHERE operacion_id = p_operacion_id;
    IF v_count = 0 THEN
      ROLLBACK;
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se encontró la operación especificada.';
    END IF;

    -- 2) Actualizar la cantidad de envíos
    UPDATE operaciones
       SET cantidad_envios = p_nueva_cantidad_envios
     WHERE operacion_id = p_operacion_id;

    -- 3) Insertar las OTs
    SET num_ots = JSON_LENGTH(p_json_ots);
    WHILE i < num_ots DO
        SET ot_val = JSON_UNQUOTE(JSON_EXTRACT(p_json_ots, CONCAT('$[', i, ']')));
        -- Verifica si la OT ya existe para esa operación, si no, inserta:
        SELECT COUNT(*)
          INTO v_existente
        FROM ordenes_trabajo_vehiculo
        WHERE operacion_id = p_operacion_id AND numero_ot = ot_val;
        IF v_existente = 0 THEN
            INSERT INTO ordenes_trabajo_vehiculo (operacion_id, numero_ot)
            VALUES (p_operacion_id, ot_val);
        END IF;
        SET i = i + 1;
    END WHILE;

    COMMIT;
END //
DELIMITER ;


-- Procedimiento almacenado para eliminar usuario MySQL cuando un colaborador para a Retirado (No implementado)
/* Elimina versión previa si existe */
DROP PROCEDURE IF EXISTS sp_drop_mysql_user;
DELIMITER //

CREATE PROCEDURE sp_drop_mysql_user(IN p_username VARCHAR(50))
SQL SECURITY DEFINER
BEGIN
    /* 1 – Manejador de errores: revierte ante cualquier excepción */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    /* 2 – Bloque transaccional */
    START TRANSACTION;

        /* Construir y ejecutar DROP USER de forma dinámica */
        SET @sql = CONCAT('DROP USER IF EXISTS ''', p_username, '''@''%'''); -- ajustar a localhost
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    COMMIT;
END;
//
DELIMITER ;


-- version para produccion:
/*–– 1 · Borra versión previa ––*/
DROP PROCEDURE IF EXISTS sp_drop_mysql_user;
DELIMITER //

/*–– 2 · Procedimiento robusto ––*/
CREATE PROCEDURE sp_drop_mysql_user(IN p_username VARCHAR(50))
SQL SECURITY DEFINER
BEGIN
    /*–– Manejador: deshace la transacción ante cualquier error ––*/
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    /*–– Hosts donde existe la misma cuenta ––*/
    DECLARE v_hosts VARCHAR(100) DEFAULT '192.168.0.%,192.168.100.%,192.168.101.%';
    DECLARE v_pos      INT DEFAULT 1;
    DECLARE v_next_pos INT;
    DECLARE v_host     VARCHAR(20);
    DECLARE v_done     TINYINT DEFAULT 0;

    START TRANSACTION;

        /*–– Recorre la lista separada por comas ––*/
        WHILE v_done = 0 DO
            SET v_next_pos = LOCATE(',', v_hosts, v_pos);

            IF v_next_pos = 0 THEN
                SET v_host = SUBSTRING(v_hosts, v_pos);   -- último segmento
                SET v_done = 1;
            ELSE
                SET v_host = SUBSTRING(v_hosts, v_pos, v_next_pos - v_pos);
                SET v_pos = v_next_pos + 1;
            END IF;

            /*–– DROP USER dinámico ––*/
            SET @sql = CONCAT('DROP USER IF EXISTS ''', p_username, '''@''', v_host, '''');
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END WHILE;

    COMMIT;
END;
//
DELIMITER ;


-- Procedimiento almacenado para insertar tarifas PXH Deprisa

-- En la BD que contiene la tabla  tarifas_deprisa_PXH
	DELIMITER //

	CREATE PROCEDURE sp_ins_tarifa_PXH(
		IN p_tipo         ENUM('CM','VN','MT'),
		IN p_estructura   ENUM('PXH Camion Urbano','PXH Camion Poblacion Sabana','PXH Van Urbano','MENSUALIDAD'),
		IN p_modelo       ENUM('ATO','PXH ESP','PXH POB','PXH URB'),
		IN p_base         INT,
		IN p_tonelaje     INT,
		IN p_valor        DECIMAL(10,2),
		IN p_auxiliar     INT,
		IN p_vigencia     INT
	)
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			-- Si ocurre cualquier error, revierte y propaga.
			ROLLBACK;
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Error al insertar en tarifas_deprisa_PXH';
		END;

		START TRANSACTION;

		INSERT INTO tarifas_deprisa_PXH(
			tipo, estructura, modelo, base,
			tonelaje, valor, auxiliar, vigencia
		)
		VALUES (
			p_tipo, p_estructura, p_modelo, p_base,
			p_tonelaje, p_valor, p_auxiliar, p_vigencia
		);

		COMMIT;
	END //

	DELIMITER ;

-- Procedimieto almacenado para insertar cobro_total PxQ en operaciones

/*--------------------------------------------------------------------------*
 | Procedimiento: sp_actualizar_total_cobro                       		 	|
 | Propósito   : Calcular y actualizar el campo operaciones.total_cobro PxQ	|	
 | Autor       : Juan Saavedra                                           	|
 | Notas       : Utiliza control de errores y transacción explícita  		|
 *--------------------------------------------------------------------------*/
DROP PROCEDURE IF EXISTS actualizar_total_cobro_PxQ;

DELIMITER //

CREATE PROCEDURE actualizar_total_cobro_PxQ()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    WITH max_tarifas AS (
        SELECT
            tipo,
            poblacion,
            MAX(entrega)     AS tarifa_entreg,
            MAX(recoleccion) AS tarifa_recol
        FROM tarifas_deprisa_PXQ
        GROUP BY tipo, poblacion
    )
    UPDATE operaciones AS o
    JOIN max_tarifas AS mt
      ON mt.tipo = CASE o.vehiculo
                     WHEN 'CAMION' THEN 'CM'
                     WHEN 'VAN'    THEN 'VN'
                     WHEN 'MOTO'   THEN 'MT'
                   END
     AND mt.poblacion = o.ciudad_poblacion
    SET o.total_cobro = ROUND(
            ROUND(o.cantidad_envios        - o.cantidad_devoluciones, 0) *
            COALESCE(ROUND(mt.tarifa_entreg, 4), 0)
            +
            ROUND(o.cantidad_recolecciones - o.cantidad_no_recogidos, 0) *
            COALESCE(ROUND(mt.tarifa_recol , 4), 0),
        2)
    WHERE o.servicio = 5
      AND (o.total_cobro IS NULL OR o.total_cobro = 0);

    COMMIT;
END //

DELIMITER ;



/*--------------------------------------------------------------------------*
 | Procedimiento: sp_ActualizarTotalCobroPxH                       		 	|
 | Propósito   : Calcular y actualizar el campo operaciones.total_cobro PxH	|	
 | Autor       : Juan saavedra                                              |
 | Notas       : Utiliza control de errores y transacción explícita  		|
 *--------------------------------------------------------------------------*/

DROP PROCEDURE IF EXISTS sp_ActualizarTotalCobroPxH;

DELIMITER //

CREATE PROCEDURE sp_ActualizarTotalCobroPxH()
BEGIN
    -- 1. [OBLIGATORIO] Las declaraciones van PRIMERO
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        -- Reactivar modo seguro si falla
        SET SQL_SAFE_UPDATES = 1;
        RESIGNAL;
    END;

    -- 2. [AHORA SÍ] Desactivar modo seguro (instrucción ejecutable)
    SET SQL_SAFE_UPDATES = 0;

    START TRANSACTION;

    UPDATE operaciones AS o
    JOIN vista_calculos_total_tarifa_PxH calc
      ON calc.operacion_id = o.operacion_id
    SET o.total_cobro = calc.total_tarifa
    WHERE calc.total_tarifa IS NOT NULL
      AND (o.total_cobro IS NULL OR o.total_cobro = 0)
      AND NOT EXISTS (
          SELECT 1
          FROM tarifas_mensuales t
          WHERE t.sector = o.sector
      );

    COMMIT;

    -- 3. [LIMPIEZA] Reactivar modo seguro
    SET SQL_SAFE_UPDATES = 1;

    SELECT 'Actualización de total_cobro completada.' AS resultado;
END //

DELIMITER ;






/*-----------------------------------------------------------
  Procedimiento: sp_CalcularCobroSinAuxiliar
  Cálculo: total_cobro – cobro_auxiliar → cobro_sin_auxiliar
-----------------------------------------------------------*/

DROP PROCEDURE IF EXISTS sp_CalcularCobroSinAuxiliar;
DELIMITER //

CREATE PROCEDURE sp_CalcularCobroSinAuxiliar()
SQL SECURITY DEFINER
BEGIN
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno     INT;
    DECLARE v_text      VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno    = MYSQL_ERRNO,
            v_text     = MESSAGE_TEXT;
        ROLLBACK;
        SELECT CONCAT('ERROR ',v_errno,' (',v_sqlstate,'): ',v_text) AS Mensaje;
    END;

    START TRANSACTION;

        UPDATE operaciones
        SET cobro_sin_auxiliar = COALESCE(total_cobro,0) - COALESCE(cobro_auxiliar,0)
        WHERE (cobro_sin_auxiliar IS NULL OR cobro_sin_auxiliar = 0);

    COMMIT;

    SELECT 'ÉXITO: cobro_sin_auxiliar calculado solo donde estaba NULL/0.' AS Mensaje;
END;
//
DELIMITER ;



/*-----------------------------------------------------------
  Procedimiento: sp_ActualizarTotalTurno
  Lógica: total_turno = cobro_sin_auxiliar × 0.88
  Ámbito: solo operaciones cuyo proveedor = 'PYP'
-----------------------------------------------------------*/

/* Elimina versión previa */

DROP PROCEDURE IF EXISTS sp_ActualizarTotalTurno;

DELIMITER //

CREATE PROCEDURE sp_ActualizarTotalTurno()
BEGIN
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno    INT;
    DECLARE v_text     VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno    = MYSQL_ERRNO,
            v_text     = MESSAGE_TEXT;
        ROLLBACK;
        SELECT CONCAT('ERROR ',v_errno,' (',v_sqlstate,'): ',v_text) AS Mensaje;
    END;

    START TRANSACTION;

        UPDATE operaciones
        SET total_turno = cobro_sin_auxiliar * 0.90
        WHERE proveedor = 'PYP'
          AND (total_turno IS NULL OR total_turno = 0);

    COMMIT;

    SELECT ROW_COUNT() AS filas_afectadas,
           'ÉXITO: total_turno actualizado (solo NULL/0).' AS Mensaje;
END;
//
DELIMITER ;



-- Procedimiento Almacenado para colocar total_turno en la tabla operaciones de vehiculos terceros y fidelizados
-- segun método de pago

DROP PROCEDURE IF EXISTS actualizar_total_turno_terceros;

DELIMITER //
CREATE PROCEDURE actualizar_total_turno_terceros()
BEGIN
    UPDATE operaciones o
    JOIN metodo_pago m 
        ON o.sector = m.sector
    
    -- Fletes normal por ciudad_poblacion
    LEFT JOIN fletes f_normal 
        ON o.proveedor = f_normal.proveedor
       AND o.tonelaje = f_normal.tonelaje
       AND o.ciudad_poblacion = f_normal.ciudad_poblacion
       AND m.metodo_pago = f_normal.metodo_pago
    
    -- Fletes especial BOGPOB
    LEFT JOIN fletes f_bogpob 
        ON o.proveedor = f_bogpob.proveedor
       AND o.tonelaje = f_bogpob.tonelaje
       AND m.metodo_pago = f_bogpob.metodo_pago
       AND f_bogpob.base_corta = 'BOGPOB'
    
    LEFT JOIN prod_tarifa pt 
        ON pt.vehiculo_tipo = CONCAT(
                CASE
                    WHEN o.vehiculo = 'VAN' THEN 'VAN'
                    WHEN o.vehiculo = 'CAMION' THEN 'CM'
                    ELSE o.vehiculo
                END,
                ' ',
                RIGHT(m.modelo, 3)
            )
       AND pt.tonelaje = o.tonelaje
       AND ((o.cantidad_envios - o.cantidad_devoluciones) 
          + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) 
           BETWEEN pt.piezas_ini AND pt.piezas_fin
    
    SET o.total_turno =
        CASE
            WHEN m.metodo_pago = 'HORA' THEN 
                ROUND(
                    ROUND(
                        LEAST(
                            ROUND(
                                TIMESTAMPDIFF(
                                    MINUTE,
                                    o.hora_inicio,
                                    CASE
                                        WHEN o.cierre_dia_siguiente = 1 
                                        THEN ADDTIME(o.hora_final, '24:00:00')
                                        ELSE o.hora_final
                                    END
                                ) / 60.0, 2
                            ), 8.00
                        ) * f_normal.valor, 2
                    )
                    + 
                    ROUND(
                        GREATEST(
                            ROUND(
                                TIMESTAMPDIFF(
                                    MINUTE,
                                    o.hora_inicio,
                                    CASE
                                        WHEN o.cierre_dia_siguiente = 1 
                                        THEN ADDTIME(o.hora_final, '24:00:00')
                                        ELSE o.hora_final
                                    END
                                ) / 60.0, 2
                            ) - 9.00, 0.00
                        ) * f_normal.hora_extra, 2
                    ), 2
                )
            
            WHEN m.metodo_pago = 'TURNO' THEN 
                ROUND(f_normal.turno, 2)
            
            -- INICIO DE LA MODIFICACIÓN: Lógica especial para Productividad en Medellín
            WHEN m.metodo_pago = 'PRODUCTIVIDAD' AND o.ciudad_poblacion = 554 THEN
                (
                    SELECT ROUND(f.valor, 2)
                    FROM fletes f
                    WHERE f.proveedor = o.proveedor
                      AND f.tonelaje = o.tonelaje
                      AND f.ciudad_poblacion = o.ciudad_poblacion
                      AND f.metodo_pago = 'PRODUCTIVIDAD'
                      AND f.sub_tipo = (
                          SELECT CASE
                              WHEN ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) <= 70 THEN 'TURNO1'
                              WHEN ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) <= 80 THEN 'TURNO2'
                              WHEN ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) <= 90 THEN 'TURNO3'
                              WHEN ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) <= 105 THEN 'TURNO4'
                              WHEN ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) <= 120 THEN 'TURNO5'
                              ELSE 'TURNO6'
                          END
                      )
                )

            -- Lógica original de Productividad para el resto de ciudades
            WHEN m.metodo_pago = 'PRODUCTIVIDAD' THEN 
                ROUND(
                    pt.horas_a_pagar * (
                        CASE
                            WHEN o.estacion = 3 AND o.ciudad_poblacion <> 110 
                                 THEN f_bogpob.valor
                            ELSE f_normal.valor
                        END
                    ), 2
                )
            -- FIN DE LA MODIFICACIÓN

            ELSE o.total_turno
        END
        WHERE o.proveedor IN ('TCR', 'FDZ1', 'FDZ2')
      AND (o.total_turno IS NULL OR o.total_turno = 0);

END//
DELIMITER ;




-- Procedinmieto almacenado encargado de calcular total_cobro para las operaciones con el método de cobro 'ENTREGA'

DROP PROCEDURE IF EXISTS sp_actualizar_total_cobro_entrega;

DELIMITER //

CREATE PROCEDURE sp_actualizar_total_cobro_entrega()
BEGIN
    UPDATE operaciones  AS o
    JOIN metodo_pago    AS mp
      ON mp.sector = o.sector
    JOIN entrega        AS e
      ON (
            CASE
              WHEN o.vehiculo = 'CAMION' THEN 'CM'
              WHEN o.vehiculo = 'VAN'    THEN 'VN'
              WHEN o.vehiculo = 'MOTO'   THEN 'MT'
              ELSE o.vehiculo
            END                 = e.vehiculo_tipo
        AND mp.modelo          = e.modelo
        AND o.estacion         = e.estacion
        AND o.ciudad_poblacion = e.ciudad_poblacion
      )
    SET o.total_cobro =
          ((o.cantidad_envios        - o.cantidad_devoluciones) * e.cobro_entrega)
        + ((o.cantidad_recolecciones - o.cantidad_no_recogidos) * e.cobro_recoleccion)
    WHERE mp.metodo_pago = 'ENTREGA'
      AND (o.total_cobro IS NULL OR o.total_cobro = 0);
END//

DELIMITER ;


-- Procedimieto almacenado encargado de calcular el total_turno para operaciones con metodo de pago = 'ENTREGA'

DROP PROCEDURE IF EXISTS sp_actualizar_total_turno_entrega;

DELIMITER //

CREATE PROCEDURE sp_actualizar_total_turno_entrega()
BEGIN
    UPDATE operaciones AS o
    JOIN metodo_pago  AS mp
      ON mp.sector = o.sector
    JOIN entrega      AS e
      ON (
            CASE
              WHEN o.vehiculo = 'CAMION' THEN 'CM'
              WHEN o.vehiculo = 'VAN'    THEN 'VN'
              WHEN o.vehiculo = 'MOTO'   THEN 'MT'
              ELSE o.vehiculo
            END                 = e.vehiculo_tipo
        AND mp.modelo          = e.modelo
        AND o.estacion         = e.estacion
        AND o.ciudad_poblacion = e.ciudad_poblacion
      )
    SET o.total_turno =
          ((o.cantidad_envios        - o.cantidad_devoluciones) * e.pago_entrega)
        + ((o.cantidad_recolecciones - o.cantidad_no_recogidos) * e.pago_recoleccion)
    WHERE mp.metodo_pago = 'ENTREGA'
      AND (o.total_turno IS NULL OR o.total_turno = 0);
END//

DELIMITER ;




-- =========================================================================
-- Procedimiento: sp_ActualizarCostosNomina
-- Propósito   : Calcular y actualizar los costos de nómina y el cobro
--               de auxiliares en la tabla 'operaciones'.
-- Autor       : [Tu Nombre/Equipo]
-- Notas       : - Utiliza una transacción explícita con control de errores.
--               - El cálculo de 'cobro_auxiliar' es un valor simple
--                 basado en horas totales y una tarifa fija.
--               - Esta versión SOBRESCRIBE valores existentes al no
--                 tener la cláusula WHERE ... IS NULL.
-- =========================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarCobroAuxiliar;

DELIMITER //

CREATE PROCEDURE sp_ActualizarCobroAuxiliar()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: La actualización masiva fue revertida por un error técnico.' AS Mensaje;
    END;

    START TRANSACTION;

    UPDATE operaciones AS op
    CROSS JOIN (
        /* Obtenemos el valor de la tarifa una sola vez para toda la operación */
        SELECT valor_parametro 
        FROM parametros_empresa 
        WHERE nombre_parametro = 'valor_hora_auxiliar' 
        LIMIT 1
    ) AS param
    SET op.cobro_auxiliar = ROUND(
        /* LÓGICA DE HORAS EFECTIVAS (REGLA 8-9h ALMUERZO) */
        (
            CASE 
                -- 1. Cálculo de horas brutas (considerando cierre al día siguiente)
                WHEN (TIMESTAMPDIFF(MINUTE, op.hora_inicio, 
                        CASE WHEN op.cierre_dia_siguiente = 1 THEN ADDTIME(op.hora_final, '24:00:00') ELSE op.hora_final END
                      ) / 60.0) <= 8 
                THEN (TIMESTAMPDIFF(MINUTE, op.hora_inicio, 
                        CASE WHEN op.cierre_dia_siguiente = 1 THEN ADDTIME(op.hora_final, '24:00:00') ELSE op.hora_final END
                      ) / 60.0)
                
                -- 2. Si está entre la hora 8 y la 9, se congela en 8 horas
                WHEN (TIMESTAMPDIFF(MINUTE, op.hora_inicio, 
                        CASE WHEN op.cierre_dia_siguiente = 1 THEN ADDTIME(op.hora_final, '24:00:00') ELSE op.hora_final END
                      ) / 60.0) BETWEEN 8.0001 AND 9
                THEN 8
                
                -- 3. Si es mayor a 9 horas, se resta la hora de almuerzo completa
                ELSE (TIMESTAMPDIFF(MINUTE, op.hora_inicio, 
                        CASE WHEN op.cierre_dia_siguiente = 1 THEN ADDTIME(op.hora_final, '24:00:00') ELSE op.hora_final END
                      ) / 60.0) - 1
            END
        )
        * 
        /* CONTEO DE AUXILIARES (Suma 1 por cada campo con datos) */
        ((CASE WHEN op.cc_aux_1 IS NOT NULL AND op.cc_aux_1 <> '' THEN 1 ELSE 0 END) +
         (CASE WHEN op.cc_aux_2 IS NOT NULL AND op.cc_aux_2 <> '' THEN 1 ELSE 0 END)) 
        * 
        /* TARIFA DE PARÁMETROS */
        param.valor_parametro
    , 2)
    /* RESTRICCIÓN DE PRODUCCIÓN: Solo registros vacíos o en cero */
    WHERE (op.cobro_auxiliar IS NULL OR op.cobro_auxiliar = 0)
      AND op.hora_final IS NOT NULL; -- Asegura que la operación ya cerró

    COMMIT;

    SELECT 'ÉXITO: Se han actualizado todos los registros pendientes de cobro auxiliar.' AS Mensaje;
END //

DELIMITER ;




-- Procedimiento alamacenado para calcular el valor diario que le corresponde a vehículos con pago MENSUAL mes vencido

DROP PROCEDURE IF EXISTS actualizar_total_cobro_mensualidad;


DELIMITER //

CREATE PROCEDURE actualizar_total_cobro_mensualidad()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Error: transacción revertida' AS mensaje;
    END;

    START TRANSACTION;

    DROP TEMPORARY TABLE IF EXISTS tmp_valores_mensuales;

CREATE TEMPORARY TABLE tmp_valores_mensuales AS
SELECT
    o2.operacion_id,
    o2.fecha,
    o2.sector,
    CASE 
      WHEN DAY(o2.fecha) < 25 THEN DATE_FORMAT(DATE_SUB(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-25')
      ELSE DATE_FORMAT(o2.fecha, '%Y-%m-25')
    END AS periodo_inicio,
    CASE 
      WHEN DAY(o2.fecha) < 25 THEN DATE_FORMAT(o2.fecha, '%Y-%m-24')
      ELSE DATE_FORMAT(DATE_ADD(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-24')
    END AS periodo_fin,
    (
      SELECT COUNT(DISTINCT DATE(x.fecha))
      FROM operaciones x
      WHERE x.sector = o2.sector
        AND x.hora_final IS NOT NULL
        AND DATE(x.fecha) BETWEEN 
            STR_TO_DATE(
                CASE WHEN DAY(o2.fecha) < 25 
                     THEN DATE_FORMAT(DATE_SUB(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-25')
                     ELSE DATE_FORMAT(o2.fecha, '%Y-%m-25') END, '%Y-%m-%d')
            AND 
            STR_TO_DATE(
                CASE WHEN DAY(o2.fecha) < 25 
                     THEN DATE_FORMAT(o2.fecha, '%Y-%m-24')
                     ELSE DATE_FORMAT(DATE_ADD(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-24') END, '%Y-%m-%d')
    ) AS dias_totales_periodo,
    ROUND(
        IFNULL(tm.valor_cobro, 0) / NULLIF(
            (
              SELECT COUNT(DISTINCT DATE(x2.fecha))
              FROM operaciones x2
              WHERE x2.sector = o2.sector
                AND x2.hora_final IS NOT NULL
                AND DATE(x2.fecha) BETWEEN 
                    STR_TO_DATE(
                        CASE WHEN DAY(o2.fecha) < 25 
                             THEN DATE_FORMAT(DATE_SUB(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-25')
                             ELSE DATE_FORMAT(o2.fecha, '%Y-%m-25') END, '%Y-%m-%d')
                    AND 
                    STR_TO_DATE(
                        CASE WHEN DAY(o2.fecha) < 25 
                             THEN DATE_FORMAT(o2.fecha, '%Y-%m-24')
                             ELSE DATE_FORMAT(DATE_ADD(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-24') END, '%Y-%m-%d')
            ), 0
        ), 2
    ) AS valor_vehiculo_dia
FROM operaciones o2
INNER JOIN metodo_pago mp ON mp.sector = o2.sector AND mp.metodo_pago = 'MENSUALIDAD'
INNER JOIN tarifas_mensuales tm ON tm.sector = o2.sector
WHERE o2.hora_final IS NOT NULL
  -- Aquí la clave: usar periodo_inicio y periodo_fin calculados
  AND o2.fecha >= STR_TO_DATE(
        CASE WHEN DAY(o2.fecha) < 25 THEN DATE_FORMAT(DATE_SUB(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-25')
             ELSE DATE_FORMAT(o2.fecha, '%Y-%m-25') END, '%Y-%m-%d')
  AND o2.fecha <= STR_TO_DATE(
        CASE WHEN DAY(o2.fecha) < 25 THEN DATE_FORMAT(o2.fecha, '%Y-%m-24')
             ELSE DATE_FORMAT(DATE_ADD(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-24') END, '%Y-%m-%d')
  AND STR_TO_DATE(
        CASE 
          WHEN DAY(o2.fecha) < 25 THEN DATE_FORMAT(o2.fecha, '%Y-%m-24')
          ELSE DATE_FORMAT(DATE_ADD(o2.fecha, INTERVAL 1 MONTH), '%Y-%m-24')
        END, '%Y-%m-%d'
      ) < CURDATE();



    -- Filas a actualizar
    SELECT COUNT(*) INTO @to_update 
    FROM tmp_valores_mensuales 
    WHERE valor_vehiculo_dia IS NOT NULL AND valor_vehiculo_dia <> 0;

    -- Actualización
    UPDATE operaciones o
    JOIN tmp_valores_mensuales t ON o.operacion_id = t.operacion_id
    SET o.total_cobro = t.valor_vehiculo_dia
    WHERE t.valor_vehiculo_dia IS NOT NULL
      AND t.valor_vehiculo_dia <> 0
      AND (o.total_cobro IS NULL OR o.total_cobro = 0);


    SET @rows = ROW_COUNT();

    COMMIT;

    SELECT CONCAT('Actualización completada. Filas calculadas: ', @to_update, '. Filas actualizadas: ', @rows) AS mensaje;

    DROP TEMPORARY TABLE IF EXISTS tmp_valores_mensuales;
END//

DELIMITER ;

-- ####################### Procedimientos Almacenados para Edicion de registros de Operaciones #######################################

-- Procedimiento almacenado para inserción de OT de un registro operacion_id

DELIMITER //

CREATE PROCEDURE sp_insertar_ot_vehiculo (
    IN p_operacion_id INT,
    IN p_numero_ot VARCHAR(30),
    IN p_usuario VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al insertar la orden de trabajo.';
    END;

    START TRANSACTION;

    INSERT INTO ordenes_trabajo_vehiculo (operacion_id, numero_ot)
    VALUES (p_operacion_id, p_numero_ot);

    COMMIT;
END //

DELIMITER ;

-- Procedimiento almacenado para actualización de OT de un registro operacion_id

DELIMITER //

CREATE PROCEDURE sp_actualizar_ot_vehiculo (
    IN p_ot_id INT,
    IN p_numero_ot VARCHAR(30),
    IN p_usuario VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al actualizar la orden de trabajo.';
    END;

    START TRANSACTION;

    UPDATE ordenes_trabajo_vehiculo
    SET numero_ot = p_numero_ot
    WHERE ot_id = p_ot_id;

    COMMIT;
END //

DELIMITER ;


-- Procedimiento almacenado para eliminacion de OT de un registro operacion_id

DELIMITER //

CREATE PROCEDURE sp_eliminar_ot_vehiculo (
    IN p_ot_id INT,
    IN p_usuario VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al eliminar la orden de trabajo.';
    END;

    START TRANSACTION;

    DELETE FROM ordenes_trabajo_vehiculo
    WHERE ot_id = p_ot_id;

    COMMIT;
END //

DELIMITER ;

-- Procedimiento almacenado para actualizar la informacion de uyn registro de operaciones
DELIMITER //

CREATE PROCEDURE sp_actualizar_operacion_flexible(
    IN p_operacion_id INT,
    IN p_fecha DATE,
    IN p_estacion VARCHAR(100),
    IN p_sector VARCHAR(100),
    IN p_servicio VARCHAR(100),
    IN p_driver VARCHAR(100),
    IN p_ciudad_poblacion VARCHAR(100),
    IN p_vehiculo VARCHAR(100),
    IN p_placa VARCHAR(20),
    IN p_proveedor VARCHAR(100),
    IN p_tonelaje DECIMAL(10,2),
    IN p_tipo_pago VARCHAR(50),
    IN p_nombre_ruta VARCHAR(150),
    IN p_hora_inicio TIME,
    IN p_cantidad_envios INT,
    IN p_km_inicial DECIMAL(10,2),
    IN p_remesa VARCHAR(50),
    IN p_manifiesto VARCHAR(50),
    IN p_clasificacion_uso_PxH VARCHAR(50),
    IN p_cc_conductor VARCHAR(50),
    IN p_cc_aux_1 VARCHAR(50),
    IN p_cc_aux_2 VARCHAR(50),
    IN p_km_final DECIMAL(10,2),
    IN p_hora_final TIME,
    IN p_cierre_dia_siguiente BOOLEAN,
    IN p_cantidad_devoluciones INT,
    IN p_cantidad_recolecciones INT,
    IN p_cantidad_no_recogidos INT,
    IN p_borrar_aux1 BOOLEAN,
    IN p_borrar_aux2 BOOLEAN,
    IN p_borrar_remesa BOOLEAN,
    IN p_borrar_manifiesto BOOLEAN
)
BEGIN
    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    UPDATE operaciones
    SET
        fecha = COALESCE(p_fecha, fecha),
        estacion = COALESCE(p_estacion, estacion),
        sector = COALESCE(p_sector, sector),
        servicio = COALESCE(p_servicio, servicio),
        driver = COALESCE(p_driver, driver),
        ciudad_poblacion = COALESCE(p_ciudad_poblacion, ciudad_poblacion),
        vehiculo = COALESCE(p_vehiculo, vehiculo),
        placa = COALESCE(p_placa, placa),
        proveedor = COALESCE(p_proveedor, proveedor),
        tonelaje = COALESCE(p_tonelaje, tonelaje),
        tipo_pago = COALESCE(p_tipo_pago, tipo_pago),
        nombre_ruta = COALESCE(p_nombre_ruta, nombre_ruta),
        hora_inicio = COALESCE(p_hora_inicio, hora_inicio),
        cantidad_envios = COALESCE(p_cantidad_envios, cantidad_envios),
        km_inicial = COALESCE(p_km_inicial, km_inicial),
        remesa = IF(p_borrar_remesa, NULL, COALESCE(p_remesa, remesa)),
        manifiesto = IF(p_borrar_manifiesto, NULL, COALESCE(p_manifiesto, manifiesto)),
        clasificacion_uso_PxH = COALESCE(p_clasificacion_uso_PxH, clasificacion_uso_PxH),
        cc_conductor = COALESCE(p_cc_conductor, cc_conductor),
        cc_aux_1 = IF(p_borrar_aux1, NULL, COALESCE(p_cc_aux_1, cc_aux_1)),
        cc_aux_2 = IF(p_borrar_aux2, NULL, COALESCE(p_cc_aux_2, cc_aux_2)),
        km_final = COALESCE(p_km_final, km_final),
        hora_final = COALESCE(p_hora_final, hora_final),
        cierre_dia_siguiente = COALESCE(p_cierre_dia_siguiente, cierre_dia_siguiente),
        cantidad_devoluciones = COALESCE(p_cantidad_devoluciones, cantidad_devoluciones),
        cantidad_recolecciones = COALESCE(p_cantidad_recolecciones, cantidad_recolecciones),
        cantidad_no_recogidos = COALESCE(p_cantidad_no_recogidos, cantidad_no_recogidos)
    WHERE operacion_id = p_operacion_id;

    COMMIT;
END;


-- #############################################################################################################################
-- Procedimientos almacenados talento Humano

-- Procedimiento almacenado para insertar colaborador nuevo

DELIMITER //

CREATE PROCEDURE insertar_colaborador (
    IN p_tipo_id VARCHAR(50),
    IN p_num_id VARCHAR(50),
    IN p_lugar_expedicion VARCHAR(100),
    IN p_fecha_expedicion DATE,
    IN p_primer_nombre VARCHAR(100),
    IN p_segundo_nombre VARCHAR(100),
    IN p_primer_apellido VARCHAR(100),
    IN p_segundo_apellido VARCHAR(100),
    IN p_formacion_academica VARCHAR(100),
    IN p_estado_formacion VARCHAR(100),
    IN p_fecha_nacimiento DATE,
    IN p_sexo VARCHAR(10),
    IN p_grupo_sanguineo VARCHAR(5),
    IN p_rh VARCHAR(5),
    IN p_estado_civil VARCHAR(50),
    IN p_direccion VARCHAR(255),
    IN p_barrio VARCHAR(100),
    IN p_estrato VARCHAR(10),
    IN p_pais_nacimiento VARCHAR(100),
    IN p_departamento_id INT,
    IN p_ciudad_id INT,
    IN p_estatus VARCHAR(50),
    IN p_departamento_empresa_id INT,
    IN p_cargo_id INT,
    IN p_sede_id INT,
    IN p_planta VARCHAR(100),
    IN p_jefe_id INT,
    IN p_fecha_emo DATE,
    IN p_fecha_prox_emo DATE,
    IN p_fecha_carnet DATE,
    IN p_contacto_emergencia VARCHAR(100),
    IN p_telefono_emergencia VARCHAR(50),
    IN p_ruta_induccion TINYINT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores SQL: hace ROLLBACK y devuelve error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Error en insertar_colaborador (transacción cancelada).';
    END;

    START TRANSACTION;

    -- Fijar usuario para triggers/auditoría
    SET @usuario_actual = p_usuario;

    -- 1) Verificar duplicado por id_cc
    SELECT COUNT(*) INTO v_existente
    FROM colaboradores
    WHERE id_cc = p_num_id;

    IF v_existente > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Ya existe un colaborador con ese número de identificación.';
    END IF;

    -- 2) Insertar colaborador
    INSERT INTO colaboradores (
        tipo_id,
        id_cc,
        lugar_expedicion,
        fecha_expedicion,
        primer_nombre,
        segundo_nombre,
        primer_apellido,
        segundo_apellido,
        formacion_academica,
        estado_formacion_academica,
        fecha_nacimiento,
        sexo,
        grupo_sanguineo,
        rh,
        estado_civil,
        direccion,
        barrio,
        estrato,
        pais_nacimiento,
        departamento_nacimiento,
        ciudad_nacimiento,
        estatus_colaborador,
        departamento,
        cargo,
        sede,
        planta,
        id_jefe,
        fecha_emo,
        fecha_proximo_emo,
        fecha_elaboracion_carnet,
        contacto_emergencia,
        telefono_contacto_emergencia,
        ruta_induccion
    )
    VALUES (
        p_tipo_id,
        p_num_id,
        p_lugar_expedicion,
        p_fecha_expedicion,
        p_primer_nombre,
        p_segundo_nombre,
        p_primer_apellido,
        p_segundo_apellido,
        p_formacion_academica,
        p_estado_formacion,
        p_fecha_nacimiento,
        p_sexo,
        p_grupo_sanguineo,
        p_rh,
        p_estado_civil,
        p_direccion,
        p_barrio,
        p_estrato,
        p_pais_nacimiento,
        p_departamento_id,
        p_ciudad_id,
        p_estatus,
        p_departamento_empresa_id,
        p_cargo_id,
        p_sede_id,
        p_planta,
        p_jefe_id,
        p_fecha_emo,
        p_fecha_prox_emo,
        p_fecha_carnet,
        p_contacto_emergencia,
        p_telefono_emergencia,
        p_ruta_induccion
    );

    COMMIT;
END//

DELIMITER ;


-- Procedimiento Almacenado para INSERT contactos_colaboradores y seguridad social

DROP PROCEDURE IF EXISTS sp_insertar_contactos_segsocial;

DELIMITER //

CREATE PROCEDURE sp_insertar_contactos_segsocial (
    IN p_id_empleado INT,
    IN p_cesantias VARCHAR(100),
    IN p_pension VARCHAR(100),
    IN p_eps VARCHAR(100),
    IN p_arl VARCHAR(100),
    IN p_riesgo ENUM('I','II','III','IV','V'),
    IN p_ccf VARCHAR(100),
    IN p_contactos_json JSON,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_contactos_segsocial_inicio: BEGIN
    DECLARE v_existe_segsocial INT DEFAULT 0;
    DECLARE v_existe_contactos INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Verificar qué existe
    SELECT COUNT(*) INTO v_existe_segsocial
    FROM seguridad_social
    WHERE id_empleado = p_id_empleado;

    SELECT COUNT(*) INTO v_existe_contactos
    FROM contactos_colaboradores
    WHERE id_colaborador = p_id_empleado;

    -- Caso 1: Ambos existen - bloquear
    IF v_existe_segsocial > 0 AND v_existe_contactos > 0 THEN
        ROLLBACK;
        SET p_resultado = 2;
        LEAVE sp_insertar_contactos_segsocial_inicio;
    END IF;

    -- Caso 2: Solo seguridad social existe - insertar contactos
    IF v_existe_segsocial > 0 AND v_existe_contactos = 0 THEN
        IF JSON_LENGTH(p_contactos_json) = 0 THEN
            ROLLBACK;
            SET p_resultado = -1;
            LEAVE sp_insertar_contactos_segsocial_inicio;
        END IF;
        
        INSERT INTO contactos_colaboradores (id_colaborador, tipo, valor)
        SELECT
            p_id_empleado,
            jt.tipo,
            jt.valor
        FROM
            JSON_TABLE(
                p_contactos_json,
                '$[*]' COLUMNS (
                    tipo VARCHAR(255) PATH '$.tipo',
                    valor VARCHAR(255) PATH '$.valor'
                )
            ) AS jt;
        
        COMMIT;
        SET p_resultado = 3;
        LEAVE sp_insertar_contactos_segsocial_inicio;
    END IF;

    -- Caso 3: Solo contactos existen - insertar seguridad social
    IF v_existe_contactos > 0 AND v_existe_segsocial = 0 THEN
        INSERT INTO seguridad_social (
            id_empleado, cesantias, pension, eps, arl, riesgo, ccf
        ) VALUES (
            p_id_empleado, p_cesantias, p_pension, p_eps, p_arl, p_riesgo, p_ccf
        );
        
        COMMIT;
        SET p_resultado = 1;
        LEAVE sp_insertar_contactos_segsocial_inicio;
    END IF;

    -- Caso 4: Ninguno existe - insertar ambos
    IF JSON_LENGTH(p_contactos_json) = 0 THEN
        ROLLBACK;
        SET p_resultado = -1;
        LEAVE sp_insertar_contactos_segsocial_inicio;
    END IF;

    INSERT INTO seguridad_social (
        id_empleado, cesantias, pension, eps, arl, riesgo, ccf
    ) VALUES (
        p_id_empleado, p_cesantias, p_pension, p_eps, p_arl, p_riesgo, p_ccf
    );

    INSERT INTO contactos_colaboradores (id_colaborador, tipo, valor)
    SELECT
        p_id_empleado,
        jt.tipo,
        jt.valor
    FROM
        JSON_TABLE(
            p_contactos_json,
            '$[*]' COLUMNS (
                tipo VARCHAR(255) PATH '$.tipo',
                valor VARCHAR(255) PATH '$.valor'
            )
        ) AS jt;

    COMMIT;
    SET p_resultado = 0;

END sp_insertar_contactos_segsocial_inicio//

DELIMITER ;



-- Procedimieto almacenado de inserción de contratos (detecta si hay un contrato vigente)

DROP PROCEDURE IF EXISTS sp_insertar_contrato;

DELIMITER //

CREATE PROCEDURE sp_insertar_contrato (
    -- Parámetros para la tabla contratos (obligatorios)
    IN p_id_colaborador INT,
    IN p_fecha_ingreso DATE,
    IN p_forma_pago ENUM('Mensual','Quincenal','Semanal','Diario'),
    IN p_id_centro_costo INT,
    IN p_salario_base DECIMAL(12,2),
    IN p_turno VARCHAR(50),
    
    -- Parámetros para la tabla contratos (opcionales)
    IN p_tipo_contrato ENUM('Indefinido','Obra o Labor','Aprendizaje','Termino fijo','Obra o Labor - Medio Tiempo','Aprendizaje - Medio Tiempo'),
    IN p_termino_meses DATE,
    IN p_aux_alimentacion DECIMAL(12,2),
    IN p_aux_transporte DECIMAL(12,2),
    IN p_salario_integral TINYINT,
    IN p_rodamiento DECIMAL(12,2),
    IN p_contrato TINYINT,
    IN p_fecha_afiliacion_arl DATE,
    IN p_fecha_afiliacion_eps DATE,
    IN p_fecha_afiliacion_ccf DATE,
    IN p_num_ultimo_otro_si INT,
    IN p_dias_pp INT,
    IN p_contrato_vigente TINYINT,

    -- Parámetro para auditoría
    IN p_usuario VARCHAR(100),
    
    -- Parámetro de salida para resultado
    OUT p_resultado INT
)
sp_insertar_contrato_inicio: BEGIN
    DECLARE v_contrato_activo INT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- 1. Verificación de contrato vigente
    SELECT COUNT(*) INTO v_contrato_activo
    FROM contratos
    WHERE id_colaborador = p_id_colaborador AND contrato_vigente = 1;

    -- Si ya existe un contrato vigente, retornar 0 (sin hacer insert)
    IF v_contrato_activo > 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_insertar_contrato_inicio;
    END IF;

    -- 2. Insertar en la tabla contratos (VERSIÓN ACTUALIZADA: incluye dias_pp)
    INSERT INTO contratos (
        id_colaborador, fecha_ingreso, tipo_contrato, termino_meses, forma_pago,
        id_centro_costo, salario_base, aux_alimentacion, aux_transporte, salario_integral,
        rodamiento, turno, contrato, fecha_afiliacion_arl, fecha_afiliacion_eps,
        fecha_afiliacion_ccf, num_ultimo_otro_si, dias_pp, contrato_vigente
    ) VALUES (
        p_id_colaborador, p_fecha_ingreso, p_tipo_contrato, p_termino_meses, p_forma_pago,
        p_id_centro_costo, p_salario_base, COALESCE(p_aux_alimentacion, 0.00), COALESCE(p_aux_transporte, 0.00),
        COALESCE(p_salario_integral, 0), COALESCE(p_rodamiento, 0.00), p_turno, COALESCE(p_contrato, 0),
        p_fecha_afiliacion_arl, p_fecha_afiliacion_eps, p_fecha_afiliacion_ccf, p_num_ultimo_otro_si,
        COALESCE(p_dias_pp, 60), COALESCE(p_contrato_vigente, 1)
    );

    COMMIT;
    
    -- Retornar resultado exitoso (1 = inserción exitosa)
    SET p_resultado = 1;

END sp_insertar_contrato_inicio//

DELIMITER ;

-- Procedimiento almacenado para insertar Beneficiarios del colaborador

DROP PROCEDURE IF EXISTS sp_insertar_beneficiarios;

DELIMITER //

CREATE PROCEDURE sp_insertar_beneficiarios (
    IN p_id_colaborador INT,
    IN p_beneficiarios_json JSON,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_beneficiarios_inicio: BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_json_items INT;
    DECLARE v_nombre VARCHAR(100);
    DECLARE v_genero ENUM('M','F','Otro');
    DECLARE v_fecha_nacimiento VARCHAR(10);
    DECLARE v_existe_beneficiarios INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Verificar si ya existen beneficiarios para este colaborador
    SELECT COUNT(*) INTO v_existe_beneficiarios
    FROM beneficiarios
    WHERE id_colaborador = p_id_colaborador;

    -- Si ya existen beneficiarios, bloquear
    IF v_existe_beneficiarios > 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_insertar_beneficiarios_inicio;
    END IF;

    SET v_json_items = JSON_LENGTH(p_beneficiarios_json);

    WHILE i < v_json_items DO
        SET v_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].nombre')));
        SET v_genero = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].genero')));
        SET v_fecha_nacimiento = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].fecha_nacimiento')));

        INSERT INTO beneficiarios (
            id_colaborador,
            nombre,
            genero,
            fecha_nacimiento
        ) VALUES (
            p_id_colaborador,
            v_nombre,
            v_genero,
            CASE WHEN v_fecha_nacimiento = '' OR v_fecha_nacimiento IS NULL THEN NULL ELSE v_fecha_nacimiento END
        );

        SET i = i + 1;
    END WHILE;

    COMMIT;
    SET p_resultado = 1;

END sp_insertar_beneficiarios_inicio//

DELIMITER ;


-- Procedimiento almacenado para la Inserción de datos bancarios de los Colaboradores

DROP PROCEDURE IF EXISTS sp_insertar_cuenta_bancaria;

DELIMITER //

CREATE PROCEDURE sp_insertar_cuenta_bancaria (
    IN p_id_colaborador INT,
    IN p_banco_id INT,
    IN p_tipo_cuenta ENUM('Ahorros','Corriente'),
    IN p_num_cuenta VARCHAR(100),
    IN p_cta_contable_banco VARCHAR(50),
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_cuenta_bancaria_inicio: BEGIN
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;

    -- --- VERIFICACIÓN DE DUPLICADOS: ¿Ya existe cuenta para este colaborador? ---
    SELECT COUNT(*) INTO v_existente
    FROM cuentas_bancarias_colaboradores
    WHERE id_colaborador = p_id_colaborador;

    -- Si ya existe, retornar 0 (sin hacer insert)
    IF v_existente > 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_insertar_cuenta_bancaria_inicio;
    END IF;

    -- Insertar la nueva cuenta bancaria
    INSERT INTO cuentas_bancarias_colaboradores (
        id_colaborador,
        banco_id,
        tipo_cuenta,
        num_cuenta,
        cta_contable_banco
    )
    VALUES (
        p_id_colaborador,
        p_banco_id,
        p_tipo_cuenta,
        p_num_cuenta,
        p_cta_contable_banco
    );

    COMMIT;

    -- Retornar resultado exitoso (1 = inserción exitosa)
    SET p_resultado = 1;

END sp_insertar_cuenta_bancaria_inicio//

DELIMITER ; 


-- Procedimiento almacenado para la inserción de tallas de dotación colaboradores

DROP PROCEDURE IF EXISTS sp_insertar_tallas_dotacion;

DELIMITER //

CREATE PROCEDURE sp_insertar_tallas_dotacion (
    IN p_id_colaborador INT,
    IN p_talla_pantalon VARCHAR(5),
    IN p_talla_camisa VARCHAR(5),
    IN p_talla_botas VARCHAR(5),
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_tallas_dotacion_inicio: BEGIN
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;

    -- --- AJUSTE CLAVE: Verificación de duplicados por id_colaborador ---
    SELECT COUNT(*) INTO v_existente
    FROM tallas_dotacion
    WHERE id_colaborador = p_id_colaborador;

    IF v_existente > 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_insertar_tallas_dotacion_inicio;
    END IF;

    -- Insertar las nuevas tallas de dotación
    INSERT INTO tallas_dotacion (
        id_colaborador,
        talla_pantalon,
        talla_camisa,
        talla_botas
    ) VALUES (
        p_id_colaborador,
        p_talla_pantalon,
        p_talla_camisa,
        p_talla_botas
    );

    COMMIT;
    
    -- Retornar resultado exitoso (1 = inserción exitosa)
    SET p_resultado = 1;

END sp_insertar_tallas_dotacion_inicio//

DELIMITER ;



-- Procedimiento almacenado para la actualización de datos personales del colaborador
-- Solo actualiza los campos que realmente han cambiado

DROP PROCEDURE IF EXISTS sp_actualizar_colaborador;

DELIMITER //

CREATE PROCEDURE sp_actualizar_colaborador (
    IN p_id_colaborador INT,
    IN p_tipo_id VARCHAR(5),
    IN p_id_cc VARCHAR(20),
    IN p_lugar_expedicion INT,
    IN p_fecha_expedicion VARCHAR(10),
    IN p_primer_nombre VARCHAR(100),
    IN p_segundo_nombre VARCHAR(100),
    IN p_primer_apellido VARCHAR(100),
    IN p_segundo_apellido VARCHAR(100),
    IN p_formacion_academica VARCHAR(50),
    IN p_estado_formacion_academica VARCHAR(50),
    IN p_fecha_nacimiento VARCHAR(10),
    IN p_sexo VARCHAR(10),
    IN p_grupo_sanguineo VARCHAR(5),
    IN p_rh VARCHAR(3),
    IN p_estado_civil VARCHAR(50),
    IN p_direccion VARCHAR(255),
    IN p_barrio VARCHAR(200),
    IN p_estrato VARCHAR(10),
    IN p_ciudad_nacimiento INT,
    IN p_departamento_nacimiento INT,
    IN p_pais_nacimiento INT,
    IN p_estatus_colaborador VARCHAR(50),
    IN p_departamento INT,
    IN p_cargo INT,
    IN p_sede INT,
    IN p_planta VARCHAR(20),
    IN p_id_jefe INT,
    IN p_fecha_emo VARCHAR(10),
    IN p_fecha_proximo_emo VARCHAR(10),
    IN p_fecha_elaboracion_carnet VARCHAR(10),
    IN p_ruta_induccion TINYINT,
    IN p_contacto_emergencia VARCHAR(150),
    IN p_telefono_contacto_emergencia VARCHAR(150),
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_existente INT DEFAULT 0;
    DECLARE v_cambios INT DEFAULT 0;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;

    -- Verificar que el colaborador existe
    SELECT COUNT(*) INTO v_existente
    FROM colaboradores
    WHERE id_colaborador = p_id_colaborador;

    IF v_existente = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El colaborador especificado no existe en el sistema.';
    END IF;

    -- Verificar si hay cambios ANTES de actualizar
        SELECT COUNT(*) INTO v_cambios
    FROM colaboradores
    WHERE id_colaborador = p_id_colaborador
      AND (
        tipo_id <> p_tipo_id
        OR id_cc <> p_id_cc
        OR lugar_expedicion <> p_lugar_expedicion
        OR fecha_expedicion <> p_fecha_expedicion
        OR primer_nombre <> p_primer_nombre
        OR segundo_nombre <> p_segundo_nombre
        OR primer_apellido <> p_primer_apellido
        OR segundo_apellido <> p_segundo_apellido
        OR formacion_academica <> p_formacion_academica
        OR estado_formacion_academica <> p_estado_formacion_academica
        OR fecha_nacimiento <> p_fecha_nacimiento
        OR sexo <> p_sexo
        OR grupo_sanguineo <> p_grupo_sanguineo
        OR rh <> p_rh
        OR estado_civil <> p_estado_civil
        OR direccion <> p_direccion
        OR barrio <> p_barrio
        OR estrato <> p_estrato
        OR ciudad_nacimiento <> p_ciudad_nacimiento
        OR departamento_nacimiento <> p_departamento_nacimiento
        OR pais_nacimiento <> p_pais_nacimiento
        OR estatus_colaborador <> p_estatus_colaborador
        OR departamento <> p_departamento
        OR cargo <> p_cargo
        OR sede <> p_sede
        OR planta <> p_planta
        OR id_jefe <> p_id_jefe

        -- fecha_emo
        OR (
            (fecha_emo IS NULL AND p_fecha_emo IS NOT NULL)
         OR (fecha_emo IS NOT NULL AND p_fecha_emo IS NULL)
         OR (fecha_emo IS NOT NULL AND p_fecha_emo IS NOT NULL AND fecha_emo <> p_fecha_emo)
        )

        -- fecha_proximo_emo
        OR (
            (fecha_proximo_emo IS NULL AND p_fecha_proximo_emo IS NOT NULL)
         OR (fecha_proximo_emo IS NOT NULL AND p_fecha_proximo_emo IS NULL)
         OR (fecha_proximo_emo IS NOT NULL AND p_fecha_proximo_emo IS NOT NULL AND fecha_proximo_emo <> p_fecha_proximo_emo)
        )

        -- fecha_elaboracion_carnet
        OR (
            (fecha_elaboracion_carnet IS NULL AND p_fecha_elaboracion_carnet IS NOT NULL)
         OR (fecha_elaboracion_carnet IS NOT NULL AND p_fecha_elaboracion_carnet IS NULL)
         OR (fecha_elaboracion_carnet IS NOT NULL AND p_fecha_elaboracion_carnet IS NOT NULL AND fecha_elaboracion_carnet <> p_fecha_elaboracion_carnet)
        )

        OR ruta_induccion <> p_ruta_induccion

        -- textos que aceptan NULL
        OR COALESCE(contacto_emergencia,'') <> COALESCE(p_contacto_emergencia,'')
        OR COALESCE(telefono_contacto_emergencia,'') <> COALESCE(p_telefono_contacto_emergencia,'')
      );


    -- Si no hay cambios, lanzar error
    IF v_cambios = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se detectaron cambios en los datos del colaborador.';
    END IF;

    -- Actualizar solo los campos que cambiaron
    UPDATE colaboradores
    SET
        tipo_id = IF(tipo_id != p_tipo_id, p_tipo_id, tipo_id),
        id_cc = IF(id_cc != p_id_cc, p_id_cc, id_cc),
        lugar_expedicion = IF(lugar_expedicion != p_lugar_expedicion, p_lugar_expedicion, lugar_expedicion),
        fecha_expedicion = IF(fecha_expedicion != p_fecha_expedicion, p_fecha_expedicion, fecha_expedicion),
        primer_nombre = IF(primer_nombre != p_primer_nombre, p_primer_nombre, primer_nombre),
        segundo_nombre = IF(segundo_nombre != p_segundo_nombre, p_segundo_nombre, segundo_nombre),
        primer_apellido = IF(primer_apellido != p_primer_apellido, p_primer_apellido, primer_apellido),
        segundo_apellido = IF(segundo_apellido != p_segundo_apellido, p_segundo_apellido, segundo_apellido),
        formacion_academica = IF(formacion_academica != p_formacion_academica, p_formacion_academica, formacion_academica),
        estado_formacion_academica = IF(estado_formacion_academica != p_estado_formacion_academica, p_estado_formacion_academica, estado_formacion_academica),
        fecha_nacimiento = IF(fecha_nacimiento != p_fecha_nacimiento, p_fecha_nacimiento, fecha_nacimiento),
        sexo = IF(sexo != p_sexo, p_sexo, sexo),
        grupo_sanguineo = IF(grupo_sanguineo != p_grupo_sanguineo, p_grupo_sanguineo, grupo_sanguineo),
        rh = IF(rh != p_rh, p_rh, rh),
        estado_civil = IF(estado_civil != p_estado_civil, p_estado_civil, estado_civil),
        direccion = IF(direccion != p_direccion, p_direccion, direccion),
        barrio = IF(barrio != p_barrio, p_barrio, barrio),
        estrato = IF(estrato != p_estrato, p_estrato, estrato),
        ciudad_nacimiento = IF(ciudad_nacimiento != p_ciudad_nacimiento, p_ciudad_nacimiento, ciudad_nacimiento),
        departamento_nacimiento = IF(departamento_nacimiento != p_departamento_nacimiento, p_departamento_nacimiento, departamento_nacimiento),
        pais_nacimiento = IF(pais_nacimiento != p_pais_nacimiento, p_pais_nacimiento, pais_nacimiento),
        estatus_colaborador = IF(estatus_colaborador != p_estatus_colaborador, p_estatus_colaborador, estatus_colaborador),
        departamento = IF(departamento != p_departamento, p_departamento, departamento),
        cargo = IF(cargo != p_cargo, p_cargo, cargo),
        sede = IF(sede != p_sede, p_sede, sede),
        planta = IF(planta != p_planta, p_planta, planta),
        id_jefe = IF(id_jefe != p_id_jefe, p_id_jefe, id_jefe),
        fecha_emo = IF(fecha_emo != p_fecha_emo, p_fecha_emo, fecha_emo),
        fecha_proximo_emo = IF(fecha_proximo_emo != p_fecha_proximo_emo, p_fecha_proximo_emo, fecha_proximo_emo),
                fecha_elaboracion_carnet =
            CASE
                WHEN (fecha_elaboracion_carnet IS NULL AND p_fecha_elaboracion_carnet IS NOT NULL)
                  OR (fecha_elaboracion_carnet IS NOT NULL AND p_fecha_elaboracion_carnet IS NULL)
                  OR (fecha_elaboracion_carnet IS NOT NULL AND p_fecha_elaboracion_carnet IS NOT NULL
                      AND fecha_elaboracion_carnet <> p_fecha_elaboracion_carnet)
                THEN p_fecha_elaboracion_carnet
                ELSE fecha_elaboracion_carnet
            END,
        ruta_induccion = IF(ruta_induccion != p_ruta_induccion, p_ruta_induccion, ruta_induccion),
        contacto_emergencia = IF(contacto_emergencia != p_contacto_emergencia, p_contacto_emergencia, contacto_emergencia),
        telefono_contacto_emergencia = IF(telefono_contacto_emergencia != p_telefono_contacto_emergencia, p_telefono_contacto_emergencia, telefono_contacto_emergencia)
    WHERE id_colaborador = p_id_colaborador;

    COMMIT;

END//

DELIMITER ;


-- Procedimiento Almacenado INSERTAR MÚLTIPLES CONTACTOS DESDE JSON (CORREGIDO Y OPTIMIZADO)
DELIMITER //

CREATE PROCEDURE sp_insertar_contactos_colaboradores (
    IN p_id_colaborador INT,
    -- --- AJUSTE CLAVE: Se define el parámetro como tipo JSON ---
    IN p_contactos_json JSON,
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_json_items INT;
    DECLARE v_tipo VARCHAR(50);
    DECLARE v_valor VARCHAR(255);
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_insertar_contactos_colaboradores. La transacción ha sido cancelada.';
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;
    
    -- Verificar que el colaborador existe
    SELECT COUNT(*) INTO v_existente
    FROM colaboradores
    WHERE id_colaborador = p_id_colaborador;

    IF v_existente = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El colaborador especificado no existe en el sistema.';
    END IF;

    -- Obtener la cantidad de elementos en el JSON
    SET v_json_items = JSON_LENGTH(p_contactos_json);

    -- Iterar sobre cada elemento del JSON e insertar
    WHILE i < v_json_items DO
        -- Extraer los valores de cada contacto
        SET v_tipo = JSON_UNQUOTE(JSON_EXTRACT(p_contactos_json, CONCAT('$[', i, '].tipo')));
        SET v_valor = JSON_UNQUOTE(JSON_EXTRACT(p_contactos_json, CONCAT('$[', i, '].valor')));

        -- Validar que tipo y valor no estén vacíos antes de insertar
        IF v_tipo IS NOT NULL AND v_tipo <> '' AND v_valor IS NOT NULL AND v_valor <> '' THEN
            INSERT INTO contactos_colaboradores (id_colaborador, tipo, valor)
            VALUES (p_id_colaborador, v_tipo, v_valor);
        END IF;

        SET i = i + 1;
    END WHILE;

    COMMIT;

END//

DELIMITER ;


-- Procedimieto Almacenado Actualizar Contacto Existente
DELIMITER //

CREATE PROCEDURE sp_actualizar_contacto_colaborador (
    IN p_id_contacto INT,
    IN p_tipo VARCHAR(50),
    IN p_valor VARCHAR(255),
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_existente INT DEFAULT 0;
    DECLARE v_cambios INT DEFAULT 0;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;

    -- Verificar que el contacto existe
    SELECT COUNT(*) INTO v_existente
    FROM contactos_colaboradores
    WHERE id_contacto = p_id_contacto;

    IF v_existente = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El contacto especificado no existe en el sistema.';
    END IF;

    -- Verificar si hay cambios ANTES de actualizar
    SELECT COUNT(*) INTO v_cambios
    FROM contactos_colaboradores
    WHERE id_contacto = p_id_contacto
    AND (
        tipo != p_tipo
        OR valor != p_valor
    );

    -- Si no hay cambios, lanzar error
    IF v_cambios = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se detectaron cambios en el dato de contacto.';
    END IF;

    -- Actualizar solo los campos que cambiaron
    UPDATE contactos_colaboradores
    SET
        tipo = IF(tipo != p_tipo, p_tipo, tipo),
        valor = IF(valor != p_valor, p_valor, valor)
    WHERE id_contacto = p_id_contacto;

    COMMIT;

END//

DELIMITER ;

-- Procedimiento almacenado para la eliminacioón de datos de contacto de un colaborador
DELIMITER //

CREATE PROCEDURE sp_eliminar_contacto_colaborador (
    IN p_id_contacto INT,
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores SQL que revierte la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_eliminar_contacto_colaborador. La transacción ha sido cancelada.';
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría que usará el trigger
    SET @usuario_actual = p_usuario;

    -- Verificar que el dato de contacto realmente existe antes de intentar borrarlo
    SELECT COUNT(*) INTO v_existente
    FROM contactos_colaboradores
    WHERE id_contacto = p_id_contacto;

    IF v_existente = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El dato de contacto que intenta eliminar no existe o ya fue eliminado.';
    ELSE
        -- Si existe, proceder con la eliminación
        DELETE FROM contactos_colaboradores
        WHERE id_contacto = p_id_contacto;
    END IF;

    COMMIT;
END//

DELIMITER ;

-- Procedimeinto almacenado para Insertar Registros de Seguridad social de Colaborador
DELIMITER //

CREATE PROCEDURE sp_insertar_seguridad_social (
    IN p_id_colaborador INT,
    IN p_cesantias VARCHAR(100),
    IN p_pension VARCHAR(100),
    IN p_eps VARCHAR(100),
    IN p_arl VARCHAR(100),
    IN p_riesgo ENUM('I','II','III','IV','V'),
    IN p_ccf VARCHAR(100),
    IN p_usuario VARCHAR(100)
)
BEGIN
    DECLARE v_existente INT DEFAULT 0;

    -- Handler para errores SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_insertar_seguridad_social. La transacción ha sido cancelada.';
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Validar que no exista ya un registro para este colaborador para evitar duplicados
    SELECT COUNT(*) INTO v_existente
    FROM seguridad_social
    WHERE id_empleado = p_id_colaborador;

    IF v_existente > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existen datos de seguridad social para este colaborador. No se puede insertar un nuevo registro.';
    ELSE
        -- No existe, entonces INSERTAMOS
        INSERT INTO seguridad_social (
            id_empleado, cesantias, pension, eps, arl, riesgo, ccf
        ) VALUES (
            p_id_colaborador, p_cesantias, p_pension, p_eps, p_arl, p_riesgo, p_ccf
        );
    END IF;

    COMMIT;
END//

DELIMITER ;

-- Procedimieto Almacando para Actualizar info Seguridad social

DROP PROCEDURE IF EXISTS sp_actualizar_seguridad_social;

DELIMITER //

CREATE PROCEDURE sp_actualizar_seguridad_social (
    IN p_id_seguridad INT,
    IN p_cesantias VARCHAR(100),
    IN p_pension VARCHAR(100),
    IN p_eps VARCHAR(100),
    IN p_arl VARCHAR(100),
    IN p_riesgo ENUM('I','II','III','IV','V'),
    IN p_ccf VARCHAR(100),
    IN p_usuario VARCHAR(100),
    OUT p_filas_afectadas INT
)
BEGIN
    -- --- AJUSTE CLAVE: EL ORDEN ---
    -- 1. Declarar el HANDLER primero.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1; -- Señal de error
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_actualizar_seguridad_social.';
    END;

    -- 2. Ahora, el resto de la lógica del procedimiento.
    -- Inicializar el parámetro de salida
    SET p_filas_afectadas = 0;
    
    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Comprobar si hay cambios
    IF (SELECT COUNT(*) FROM seguridad_social WHERE id_seguridad = p_id_seguridad AND
            NOT (cesantias <=> p_cesantias AND
                 pension <=> p_pension AND
                 eps <=> p_eps AND
                 arl <=> p_arl AND
                 riesgo <=> p_riesgo AND
                 ccf <=> p_ccf)
        ) > 0 THEN
        
        UPDATE seguridad_social
        SET
            cesantias = p_cesantias, pension = p_pension, eps = p_eps,
            arl = p_arl, riesgo = p_riesgo, ccf = p_ccf
        WHERE id_seguridad = p_id_seguridad;
        
        SET p_filas_afectadas = ROW_COUNT();
    
    END IF;

    COMMIT;
END//

DELIMITER ;


-- Procedimiento almacenado para registrar cambios en Contrato Colaboradores y en modificaciones contratos

DROP PROCEDURE IF EXISTS sp_crear_modificacion_contrato;

DELIMITER //

CREATE PROCEDURE sp_crear_modificacion_contrato (
    -- Parámetros de entrada (12 en total)
    IN p_id_contrato INT,
    IN p_fecha_modificacion DATE,
    IN p_tipo_modificacion ENUM('Otro Si', 'Terminación', 'Corrección'),
    IN p_observaciones TEXT,
    IN p_nuevo_salario DECIMAL(12,2),
    IN p_nuevo_cargo INT,
    IN p_nueva_fecha_fin DATE,
    IN p_nuevo_aux_alimentacion DECIMAL(12,2),
    IN p_nuevo_aux_transporte DECIMAL(12,2),
    IN p_nuevo_rodamiento DECIMAL(12,2),
    IN p_nuevo_turno VARCHAR(50),
    IN p_usuario_actual VARCHAR(100)
)
BEGIN
    DECLARE v_id_colaborador INT;

    -- Handler de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error al crear la modificación del contrato. La transacción ha sido cancelada.';
    END;

    -- Iniciar transacción y fijar usuario
    START TRANSACTION;
    SET @usuario_actual = p_usuario_actual;

    -- 1. Insertar el registro completo en la tabla de historial
    INSERT INTO contratos_modificaciones (
        id_contrato, fecha_modificacion, tipo_modificacion, observaciones,
        cambio_salario, cambio_cargo, cambio_fecha_fin,
        nuevo_aux_alimentacion, nuevo_aux_transporte, nuevo_rodamiento, nuevo_turno
    ) VALUES (
        p_id_contrato, p_fecha_modificacion, p_tipo_modificacion, p_observaciones,
        p_nuevo_salario, p_nuevo_cargo, p_nueva_fecha_fin,
        p_nuevo_aux_alimentacion, p_nuevo_aux_transporte, p_nuevo_rodamiento, p_nuevo_turno
    );

    -- 2. Actualizar las tablas maestras con los nuevos valores (si se proporcionaron)
    UPDATE contratos
    SET
        salario_base = IF(p_nuevo_salario IS NOT NULL, p_nuevo_salario, salario_base),
        termino_meses = IF(p_nueva_fecha_fin IS NOT NULL, p_nueva_fecha_fin, termino_meses),
        aux_alimentacion = IF(p_nuevo_aux_alimentacion IS NOT NULL, p_nuevo_aux_alimentacion, aux_alimentacion),
        aux_transporte = IF(p_nuevo_aux_transporte IS NOT NULL, p_nuevo_aux_transporte, aux_transporte),
        rodamiento = IF(p_nuevo_rodamiento IS NOT NULL, p_nuevo_rodamiento, rodamiento),
        turno = IF(p_nuevo_turno IS NOT NULL AND p_nuevo_turno <> '', p_nuevo_turno, turno),
        num_ultimo_otro_si = num_ultimo_otro_si + 1 -- Asumimos que cada modificación es un "otrosí"
    WHERE id_contrato = p_id_contrato;

    -- Actualizar el cargo en la tabla colaboradores si se especificó uno nuevo
    IF p_nuevo_cargo IS NOT NULL THEN
        SELECT id_colaborador INTO v_id_colaborador FROM contratos WHERE id_contrato = p_id_contrato;
        UPDATE colaboradores SET cargo = p_nuevo_cargo WHERE id_colaborador = v_id_colaborador;
    END IF;

    -- Confirmar la transacción
    COMMIT;

END//

DELIMITER ;


-- Procedimiento almacenado para actualizar una modificación a contrato colaborador

DROP PROCEDURE IF EXISTS sp_actualizar_modificacion_contrato;

DELIMITER //

CREATE PROCEDURE sp_actualizar_modificacion_contrato (
    -- Parámetros de Entrada
    IN p_id_modificacion INT,
    IN p_id_contrato INT,
    IN p_fecha_modificacion DATE, 
    IN p_tipo_modificacion ENUM('Otro Si', 'Terminación', 'Corrección'),
    IN p_observaciones TEXT,
    IN p_nuevo_salario DECIMAL(12,2),
    IN p_nuevo_cargo INT,
    IN p_nueva_fecha_fin DATE,
    IN p_nuevo_aux_alimentacion DECIMAL(12,2),
    IN p_nuevo_aux_transporte DECIMAL(12,2),
    IN p_nuevo_rodamiento DECIMAL(12,2),
    IN p_nuevo_turno VARCHAR(50),
    IN p_usuario_actual VARCHAR(100),
    
    -- Parámetro de Salida
    OUT p_filas_afectadas INT
)
BEGIN
    DECLARE v_id_colaborador INT;
    DECLARE hay_cambios INT DEFAULT 0;

    -- Handler de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    -- Inicializar el parámetro de salida
    SET p_filas_afectadas = 0;
    
    -- 1. Comprobar si hay cambios usando el mismo método que tu ejemplo
    SELECT COUNT(*) INTO hay_cambios
    FROM contratos_modificaciones
    WHERE id_modificacion = p_id_modificacion
      AND NOT (
            fecha_modificacion <=> p_fecha_modificacion AND
            tipo_modificacion <=> p_tipo_modificacion AND
            observaciones <=> p_observaciones AND
            cambio_salario <=> p_nuevo_salario AND
            cambio_cargo <=> p_nuevo_cargo AND
            cambio_fecha_fin <=> p_nueva_fecha_fin AND
            nuevo_aux_alimentacion <=> p_nuevo_aux_alimentacion AND
            nuevo_aux_transporte <=> p_nuevo_aux_transporte AND
            nuevo_rodamiento <=> p_nuevo_rodamiento AND
            nuevo_turno <=> p_nuevo_turno
      );

    -- 2. Si hay cambios, proceder con la transacción
    IF hay_cambios > 0 THEN
        START TRANSACTION;
        SET @usuario_actual = p_usuario_actual;

        -- Actualizar el historial
        UPDATE contratos_modificaciones SET
            fecha_modificacion = p_fecha_modificacion,
            tipo_modificacion = p_tipo_modificacion,
            observaciones = p_observaciones,
            cambio_salario = p_nuevo_salario,
            cambio_cargo = p_nuevo_cargo,
            cambio_fecha_fin = p_nueva_fecha_fin,
            nuevo_aux_alimentacion = p_nuevo_aux_alimentacion,
            nuevo_aux_transporte = p_nuevo_aux_transporte,
            nuevo_rodamiento = p_nuevo_rodamiento,
            nuevo_turno = p_nuevo_turno
        WHERE id_modificacion = p_id_modificacion;

        -- Actualizar las tablas maestras
        UPDATE contratos SET salario_base = IF(p_nuevo_salario IS NOT NULL, p_nuevo_salario, salario_base), termino_meses = IF(p_nueva_fecha_fin IS NOT NULL, p_nueva_fecha_fin, termino_meses), aux_alimentacion = IF(p_nuevo_aux_alimentacion IS NOT NULL, p_nuevo_aux_alimentacion, aux_alimentacion), aux_transporte = IF(p_nuevo_aux_transporte IS NOT NULL, p_nuevo_aux_transporte, aux_transporte), rodamiento = IF(p_nuevo_rodamiento IS NOT NULL, p_nuevo_rodamiento, rodamiento), turno = IF(p_nuevo_turno IS NOT NULL AND p_nuevo_turno <> '', p_nuevo_turno, turno) WHERE id_contrato = p_id_contrato;
        IF p_nuevo_cargo IS NOT NULL THEN SELECT id_colaborador INTO v_id_colaborador FROM contratos WHERE id_contrato = p_id_contrato; UPDATE colaboradores SET cargo = p_nuevo_cargo WHERE id_colaborador = v_id_colaborador; END IF;
        
        SET p_filas_afectadas = ROW_COUNT();
        
        COMMIT;
    END IF;

END//

DELIMITER ;


-- Procedimiento almacenado para INSERTAR  registros de Operaciones completos con OTs (carga masiva)

DROP PROCEDURE IF EXISTS sp_insertar_operacion_desde_excel;

DELIMITER //

CREATE PROCEDURE sp_insertar_operacion_desde_excel (
    -- PARÁMETROS DE APERTURA
    IN  p_servicio              INT,
    IN  p_driver                INT,
    IN  p_vehiculo              ENUM('CAMION','MOTO','VAN'),
    IN  p_estacion              INT,
    IN  p_fecha                 DATE,
    IN  p_proveedor             ENUM('PYP','TCR','FDZ1','FDZ2'),
    IN  p_tonelaje              INT,
    IN  p_sector                VARCHAR(50),
    IN  p_placa                 VARCHAR(10),
    IN  p_hora_inicio           TIME,
    IN  p_nombre_ruta           TEXT,
    IN  p_clasificacion_uso_PxH ENUM(
        '1. Solo UM','2. Solo PM','3. Mixto (UM-PM)',
        '4. Vehiculo circular','5. Aeropuerto',
        '6. Vehiculo dedicado cliente'
    ),
    IN  p_cc_conductor          VARCHAR(20),
    IN  p_cc_aux_1              VARCHAR(20),
    IN  p_cc_aux_2              VARCHAR(20),
    IN  p_cantidad_envios       INT,
    IN  p_km_inicial            FLOAT,
    IN  p_tipo_pago             ENUM('MENSUAL','CAJA MENOR','TRANS PRONTO PAGO','NO','APOYO'),
    IN  p_remesa                VARCHAR(20),
    IN  p_manifiesto            VARCHAR(20),
    IN  p_ciudad_poblacion      INT,
    
    -- PARÁMETROS DE CIERRE
    IN  p_hora_final            TIME,
    IN  p_km_final              FLOAT,
    IN  p_horas_no_operativas   FLOAT,
    IN  p_cantidad_devoluciones INT,
    IN  p_cantidad_recolecciones INT,
    IN  p_cantidad_no_recogidos INT,
    IN  p_total_cobro           DECIMAL(19,2),
    IN  p_total_turno           DECIMAL(15,2),
    IN  p_cobro_auxiliar        DECIMAL(10,2),
    IN  p_cobro_sin_auxiliar    DECIMAL(13,2),
    IN  p_validacion_cumplido_liquidado TINYINT,
    IN  p_validacion_prefactura TINYINT,
    
    -- ÓRDENES DE TRABAJO (string separado por /)
    IN  p_ordenes_trabajo       TEXT,
    
    IN  p_usuario               VARCHAR(100)
)
BEGIN
    DECLARE v_ot_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    
    SET @usuario_actual = p_usuario;
    START TRANSACTION;
    
    -- ========== INSERCIÓN EN OPERACIONES ==========
    INSERT INTO operaciones (
        servicio, driver, vehiculo, estacion, fecha, proveedor, tonelaje,
        sector, placa, hora_inicio, hora_final, nombre_ruta,
        clasificacion_uso_PxH, cc_conductor, cc_aux_1, cc_aux_2,
        cantidad_envios, cantidad_devoluciones, cantidad_recolecciones, 
        cantidad_no_recogidos, km_inicial, km_final, horas_no_operativas,
        tipo_pago, remesa, manifiesto, ciudad_poblacion,
        total_cobro, total_turno, cobro_auxiliar, cobro_sin_auxiliar,
        validacion_cumplido_liquidado, validacion_prefactura
    ) VALUES (
        p_servicio, 
        p_driver, 
        p_vehiculo, 
        p_estacion, 
        p_fecha, 
        p_proveedor, 
        p_tonelaje,
        p_sector, 
        p_placa, 
        p_hora_inicio, 
        p_hora_final, 
        p_nombre_ruta,
        p_clasificacion_uso_PxH, 
        p_cc_conductor, 
        NULLIF(p_cc_aux_1, ''),     -- vacío → NULL
        NULLIF(p_cc_aux_2, ''),     -- vacío → NULL
        COALESCE(p_cantidad_envios, 0),
        COALESCE(p_cantidad_devoluciones, 0),
        COALESCE(p_cantidad_recolecciones, 0),
        COALESCE(p_cantidad_no_recogidos, 0),
        COALESCE(p_km_inicial, 0),
        COALESCE(p_km_final, 0),
        COALESCE(p_horas_no_operativas, 0),
        p_tipo_pago, 
        p_remesa, 
        p_manifiesto, 
        p_ciudad_poblacion,
        COALESCE(p_total_cobro, 0),
        COALESCE(p_total_turno, 0),
        COALESCE(p_cobro_auxiliar, 0),
        COALESCE(p_cobro_sin_auxiliar, 0),
        COALESCE(p_validacion_cumplido_liquidado, 0),
        COALESCE(p_validacion_prefactura, 0)
    );
    
    SET @new_op = LAST_INSERT_ID();
    
    -- ========== INSERCIÓN EN ORDENES_TRABAJO_VEHICULO ==========
    IF p_ordenes_trabajo IS NOT NULL AND p_ordenes_trabajo != '' THEN
        INSERT INTO ordenes_trabajo_vehiculo (operacion_id, numero_ot)
        SELECT 
            @new_op,
            TRIM(
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(p_ordenes_trabajo, '/', n.pos),
                    '/',
                    -1
                )
            ) AS numero_ot
        FROM (
            SELECT 1 AS pos UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9 UNION ALL
            SELECT 10
        ) n
        WHERE n.pos <= (CHAR_LENGTH(p_ordenes_trabajo) - CHAR_LENGTH(REPLACE(p_ordenes_trabajo, '/', '')) + 1)
        AND TRIM(
            SUBSTRING_INDEX(
                SUBSTRING_INDEX(p_ordenes_trabajo, '/', n.pos),
                '/',
                -1
            )
        ) != '';
        
        SET v_ot_count = ROW_COUNT();
    END IF;
    
    COMMIT;
    
END//

DELIMITER ;


-- Continuacion de SP de talento humano
-- Procedimiento almacenado de actualización de contratos
-- Detecta cambios campo por campo y solo actualiza si hay cambios
-- Retorna: 1 = Actualización exitosa, 0 = Sin cambios detectados, -1 = Error

DROP PROCEDURE IF EXISTS sp_actualizar_contrato;

DELIMITER //

CREATE PROCEDURE sp_actualizar_contrato (
    -- Identificador del contrato a actualizar
    IN p_id_contrato INT,
    
    -- Parámetros para la tabla contratos (17 campos actualizables)
    IN p_fecha_ingreso DATE,
    IN p_tipo_contrato ENUM('Indefinido','Obra o Labor','Aprendizaje','Termino fijo','Obra o Labor - Medio Tiempo','Aprendizaje - Medio Tiempo'),
    IN p_termino_meses DATE,
    IN p_forma_pago ENUM('Mensual','Quincenal','Semanal','Diario'),
    IN p_id_centro_costo INT,
    IN p_salario_base DECIMAL(12,2),
    IN p_aux_alimentacion DECIMAL(12,2),
    IN p_aux_transporte DECIMAL(12,2),
    IN p_salario_integral TINYINT,
    IN p_rodamiento DECIMAL(12,2),
    IN p_turno VARCHAR(50),
    IN p_fecha_afiliacion_arl DATE,
    IN p_fecha_afiliacion_eps DATE,
    IN p_fecha_afiliacion_ccf DATE,
    IN p_num_ultimo_otro_si INT,
    IN p_dias_pp INT,
    IN p_contrato TINYINT,

    -- Parámetro para auditoría
    IN p_usuario VARCHAR(100)
)
sp_actualizar_contrato_inicio: BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_actualizar_contrato. La transacción ha sido cancelada.';
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría.
    SET @usuario_actual = p_usuario;

    -- Detectar cambios comparando cada parámetro con los valores actuales
    -- Se considera un cambio si al menos un campo es diferente
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM contratos
    WHERE id_contrato = p_id_contrato
    AND (
        fecha_ingreso <> p_fecha_ingreso
        OR COALESCE(tipo_contrato, '') <> COALESCE(p_tipo_contrato, '')
        OR COALESCE(termino_meses, '1900-01-01') <> COALESCE(p_termino_meses, '1900-01-01')
        OR forma_pago <> p_forma_pago
        OR id_centro_costo <> p_id_centro_costo
        OR salario_base <> p_salario_base
        OR COALESCE(aux_alimentacion, 0.00) <> COALESCE(p_aux_alimentacion, 0.00)
        OR COALESCE(aux_transporte, 0.00) <> COALESCE(p_aux_transporte, 0.00)
        OR COALESCE(salario_integral, 0) <> COALESCE(p_salario_integral, 0)
        OR COALESCE(rodamiento, 0.00) <> COALESCE(p_rodamiento, 0.00)
        OR turno <> p_turno
        OR COALESCE(fecha_afiliacion_arl, '1900-01-01') <> COALESCE(p_fecha_afiliacion_arl, '1900-01-01')
        OR COALESCE(fecha_afiliacion_eps, '1900-01-01') <> COALESCE(p_fecha_afiliacion_eps, '1900-01-01')
        OR COALESCE(fecha_afiliacion_ccf, '1900-01-01') <> COALESCE(p_fecha_afiliacion_ccf, '1900-01-01')
        OR COALESCE(num_ultimo_otro_si, 0) <> COALESCE(p_num_ultimo_otro_si, 0)
        OR COALESCE(dias_pp, 60) <> COALESCE(p_dias_pp, 60)
        OR COALESCE(contrato, 0) <> COALESCE(p_contrato, 0)
    );

    -- Si no hay cambios detectados, hacer rollback y retornar
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SELECT 0 AS resultado;
        LEAVE sp_actualizar_contrato_inicio;
    END IF;

    -- Actualizar el contrato con los nuevos valores
    UPDATE contratos SET
        fecha_ingreso = p_fecha_ingreso,
        tipo_contrato = p_tipo_contrato,
        termino_meses = p_termino_meses,
        forma_pago = p_forma_pago,
        id_centro_costo = p_id_centro_costo,
        salario_base = p_salario_base,
        aux_alimentacion = COALESCE(p_aux_alimentacion, 0.00),
        aux_transporte = COALESCE(p_aux_transporte, 0.00),
        salario_integral = COALESCE(p_salario_integral, 0),
        rodamiento = COALESCE(p_rodamiento, 0.00),
        turno = p_turno,
        fecha_afiliacion_arl = p_fecha_afiliacion_arl,
        fecha_afiliacion_eps = p_fecha_afiliacion_eps,
        fecha_afiliacion_ccf = p_fecha_afiliacion_ccf,
        num_ultimo_otro_si = p_num_ultimo_otro_si,
        dias_pp = COALESCE(p_dias_pp, 60),
        contrato = COALESCE(p_contrato, 0)
    WHERE id_contrato = p_id_contrato;

    COMMIT;

    -- Retornar resultado exitoso
    SELECT 1 AS resultado;

END sp_actualizar_contrato_inicio//

DELIMITER ;

-- Procedimiento almacenado de eliminación de modificación de contrato
-- Elimina un registro de la tabla contratos_modificaciones
-- Retorna: 1 = Eliminación exitosa, 0 = Registro no encontrado, -1 = Error

DROP PROCEDURE IF EXISTS sp_eliminar_modificacion_contrato;

DELIMITER //

CREATE PROCEDURE sp_eliminar_modificacion_contrato (
    -- Identificador de la modificación a eliminar
    IN p_id_modificacion INT,
    
    -- Parámetro para auditoría
    IN p_usuario VARCHAR(100)
)
sp_eliminar_modificacion_inicio: BEGIN
    DECLARE v_filas_afectadas INT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en el procedimiento sp_eliminar_modificacion_contrato. La transacción ha sido cancelada.';
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría.
    SET @usuario_actual = p_usuario;

    -- Verificar si el registro existe
    SELECT COUNT(*) INTO v_filas_afectadas
    FROM contratos_modificaciones
    WHERE id_modificacion = p_id_modificacion;

    -- Si el registro no existe, hacer rollback y retornar 0
    IF v_filas_afectadas = 0 THEN
        ROLLBACK;
        SELECT 0 AS resultado;
        LEAVE sp_eliminar_modificacion_inicio;
    END IF;

    -- Eliminar el registro
    DELETE FROM contratos_modificaciones
    WHERE id_modificacion = p_id_modificacion;

    COMMIT;

    -- Retornar resultado exitoso
    SELECT 1 AS resultado;

END sp_eliminar_modificacion_inicio//

DELIMITER ;

-- Procedimieto almacenado de actualizacion datos beneficiario de colaborador
-- ==================================================================================================
-- PROCEDIMIENTO ALMACENADO: sp_actualizar_beneficiario
-- Función: Actualiza los datos de un beneficiario existente
--          Detecta cambios y solo actualiza los campos que cambiaron
--          Retorna: 1 si hay cambios y se actualizó, 0 si no hay cambios, -1 si hay error
-- ==================================================================================================

DROP PROCEDURE IF EXISTS sp_actualizar_beneficiario;

DELIMITER //

CREATE PROCEDURE sp_actualizar_beneficiario (
    IN p_id_beneficiario INT,
    IN p_nombre VARCHAR(100),
    IN p_genero ENUM('M','F','Otro'),
    IN p_fecha_nacimiento DATE,
    IN p_usuario VARCHAR(100),
    OUT p_filas_afectadas INT
)
sp_actualizar_beneficiario_inicio: BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Detectar cambios comparando cada parámetro con los valores actuales
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM beneficiarios
    WHERE id_beneficiario = p_id_beneficiario
    AND (
        COALESCE(nombre, '') <> COALESCE(p_nombre, '')
        OR COALESCE(genero, '') <> COALESCE(p_genero, '')
        OR COALESCE(fecha_nacimiento, '1900-01-01') <> COALESCE(p_fecha_nacimiento, '1900-01-01')
    );

    -- Si no hay cambios detectados, hacer rollback y retornar 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_filas_afectadas = 0;
        LEAVE sp_actualizar_beneficiario_inicio;
    END IF;

    -- Actualizar el beneficiario con los nuevos valores
    UPDATE beneficiarios SET
        nombre = p_nombre,
        genero = p_genero,
        fecha_nacimiento = p_fecha_nacimiento
    WHERE id_beneficiario = p_id_beneficiario;

    COMMIT;

    -- Retornar resultado exitoso (1 = actualización exitosa)
    SET p_filas_afectadas = 1;

END sp_actualizar_beneficiario_inicio//

DELIMITER ;

-- #####################################################################################################################33
-- Procedimiento almacenado para editar Datos Bancarios de Colaborador
DROP PROCEDURE IF EXISTS sp_actualizar_cuenta_bancaria;

DELIMITER //

CREATE PROCEDURE sp_actualizar_cuenta_bancaria (
    IN p_cuenta_id INT,
    IN p_banco_id INT,
    IN p_tipo_cuenta ENUM('Ahorros','Corriente'),
    IN p_num_cuenta VARCHAR(100),
    IN p_cta_contable_banco VARCHAR(50),
    IN p_usuario VARCHAR(100),
    OUT p_filas_afectadas INT
)
sp_actualizar_cuenta_bancaria_inicio: BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Detectar cambios comparando cada parámetro con los valores actuales
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM cuentas_bancarias_colaboradores
    WHERE cuenta_id = p_cuenta_id
    AND (
        COALESCE(banco_id, 0) <> COALESCE(p_banco_id, 0)
        OR COALESCE(tipo_cuenta, '') <> COALESCE(p_tipo_cuenta, '')
        OR COALESCE(num_cuenta, '') <> COALESCE(p_num_cuenta, '')
        OR COALESCE(cta_contable_banco, '') <> COALESCE(p_cta_contable_banco, '')
    );

    -- Si no hay cambios detectados, hacer rollback y retornar 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_filas_afectadas = 0;
        LEAVE sp_actualizar_cuenta_bancaria_inicio;
    END IF;

    -- Actualizar solo los campos que existen en la tabla
    UPDATE cuentas_bancarias_colaboradores 
    SET
        banco_id = p_banco_id,
        tipo_cuenta = p_tipo_cuenta,
        num_cuenta = p_num_cuenta,
        cta_contable_banco = p_cta_contable_banco
    WHERE cuenta_id = p_cuenta_id;

    COMMIT;

    -- Retornar resultado exitoso (1 = actualización exitosa)
    SET p_filas_afectadas = 1;

END sp_actualizar_cuenta_bancaria_inicio//

DELIMITER ;




-- ==================================================================================================
-- PROCEDIMIENTO ALMACENADO: sp_eliminar_beneficiario
-- Función: Elimina un beneficiario existente basado en su id_beneficiario
--          Retorna: 1 si la eliminación fue exitosa, -1 si hay error
-- ==================================================================================================

DROP PROCEDURE IF EXISTS sp_eliminar_beneficiario;

DELIMITER //

CREATE PROCEDURE sp_eliminar_beneficiario (
    IN p_id_beneficiario INT,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_eliminar_beneficiario_inicio: BEGIN

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Eliminar el beneficiario
    DELETE FROM beneficiarios
    WHERE id_beneficiario = p_id_beneficiario;

    COMMIT;

    -- Retornar resultado exitoso (1 = eliminación exitosa)
    SET p_resultado = 1;

END sp_eliminar_beneficiario_inicio//

DELIMITER ;

-- Procedimiento Almacenado de Actualización de tallas de dotación
DROP PROCEDURE IF EXISTS sp_actualizar_talla_dotacion;

DELIMITER //

CREATE PROCEDURE sp_actualizar_talla_dotacion (
    IN p_id_talla INT,
    IN p_talla_pantalon VARCHAR(5),
    IN p_talla_camisa VARCHAR(5),
    IN p_talla_botas VARCHAR(5),
    IN p_usuario VARCHAR(100),
    OUT p_filas_afectadas INT
)
sp_actualizar_talla_dotacion_inicio: BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    -- Handler para errores SQL que revierte toda la transacción
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Detectar cambios comparando cada parámetro con los valores actuales
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tallas_dotacion
    WHERE id_talla = p_id_talla
    AND (
        COALESCE(talla_pantalon, '') <> COALESCE(p_talla_pantalon, '')
        OR COALESCE(talla_camisa, '') <> COALESCE(p_talla_camisa, '')
        OR COALESCE(talla_botas, '') <> COALESCE(p_talla_botas, '')
    );

    -- Si no hay cambios detectados, hacer rollback y retornar 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_filas_afectadas = 0;
        LEAVE sp_actualizar_talla_dotacion_inicio;
    END IF;

    -- Actualizar solo los campos que existen y fueron modificados
    UPDATE tallas_dotacion 
    SET
        talla_pantalon = p_talla_pantalon,
        talla_camisa = p_talla_camisa,
        talla_botas = p_talla_botas
    WHERE id_talla = p_id_talla;

    COMMIT;

    -- Retornar resultado exitoso (1 = actualización exitosa)
    SET p_filas_afectadas = 1;

END sp_actualizar_talla_dotacion_inicio//

DELIMITER ;

-- Procedimiento Almacenado para eliminar dato bancario de un colaborador
DROP PROCEDURE IF EXISTS sp_eliminar_cuenta_bancaria;

DELIMITER //

CREATE PROCEDURE sp_eliminar_cuenta_bancaria (
    IN p_cuenta_id INT,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_eliminar_cuenta_bancaria_inicio: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Eliminar el registro de la cuenta bancaria
    DELETE FROM cuentas_bancarias_colaboradores
    WHERE cuenta_id = p_cuenta_id;

    COMMIT;

    -- Retornar resultado exitoso (1 = eliminación exitosa)
    SET p_resultado = 1;

END sp_eliminar_cuenta_bancaria_inicio//

DELIMITER ;

-- Procedimiento Alamcenado para eliminar un registro de tallas de dotación de colaborador
DROP PROCEDURE IF EXISTS sp_eliminar_talla_dotacion;

DELIMITER //

CREATE PROCEDURE sp_eliminar_talla_dotacion (
    IN p_id_talla INT,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_eliminar_talla_dotacion_inicio: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría
    SET @usuario_actual = p_usuario;

    -- Eliminar el registro de la talla de dotación
    DELETE FROM tallas_dotacion
    WHERE id_talla = p_id_talla;

    COMMIT;

    -- Retornar resultado exitoso (1 = eliminación exitosa)
    SET p_resultado = 1;

END sp_eliminar_talla_dotacion_inicio//

DELIMITER ;

-- Procedimiento alamcenado para insertar Beneficiarios adicionales para un colaborador

DROP PROCEDURE IF EXISTS sp_insertar_beneficiarios_adicionales;

DELIMITER //

CREATE PROCEDURE sp_insertar_beneficiarios_adicionales (
    IN p_id_colaborador INT,
    IN p_beneficiarios_json JSON,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_beneficiarios_adicionales_inicio: BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_json_items INT;
    DECLARE v_nombre VARCHAR(100);
    DECLARE v_genero ENUM('M','F','Otro');
    DECLARE v_fecha_nacimiento VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- NO verificamos duplicados. Permitimos insertar beneficiarios adicionales
    -- sin importar si el colaborador ya tiene beneficiarios registrados

    SET v_json_items = JSON_LENGTH(p_beneficiarios_json);

    WHILE i < v_json_items DO
        SET v_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].nombre')));
        SET v_genero = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].genero')));
        SET v_fecha_nacimiento = JSON_UNQUOTE(JSON_EXTRACT(p_beneficiarios_json, CONCAT('$[', i, '].fecha_nacimiento')));

        INSERT INTO beneficiarios (
            id_colaborador,
            nombre,
            genero,
            fecha_nacimiento
        ) VALUES (
            p_id_colaborador,
            v_nombre,
            v_genero,
            CASE WHEN v_fecha_nacimiento = '' OR v_fecha_nacimiento IS NULL THEN NULL ELSE v_fecha_nacimiento END
        );

        SET i = i + 1;
    END WHILE;

    COMMIT;
    SET p_resultado = 1;

END sp_insertar_beneficiarios_adicionales_inicio//

DELIMITER ;

-- procedimiento almacenado para Insertar inactividades de colaboradores en la tabla tbl_inactividades
DROP PROCEDURE IF EXISTS sp_insertar_inactividad;

DELIMITER //

CREATE PROCEDURE sp_insertar_inactividad (
    IN p_id_colaborador INT,
    IN p_tipo_inactividad VARCHAR(50),
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_observaciones TEXT,
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_inactividad_inicio: BEGIN
    DECLARE v_id_registrador INT;

    -- 1. Fijar usuario actual para auditoría por triggers
    SET @usuario_actual = p_usuario;

    -- 2. Obtener id_colaborador del usuario que registra
    SELECT id_colaborador INTO v_id_registrador
    FROM vista_usuarios
    WHERE usuario = p_usuario
    LIMIT 1;

    -- 3. Validar que se encontró el usuario registrador
    IF v_id_registrador IS NULL THEN
        SET p_resultado = -1;  -- código negocio: usuario no válido
        LEAVE sp_insertar_inactividad_inicio;
    END IF;

    -- 4. Insertar inactividad
    INSERT INTO tbl_inactividades (
        id_colaborador,
        tipo_inactividad,
        fecha_inicio,
        fecha_fin,
        observaciones,
        registrado_por
    ) VALUES (
        p_id_colaborador,
        p_tipo_inactividad,
        p_fecha_inicio,
        p_fecha_fin,
        CASE 
            WHEN p_observaciones IS NULL OR p_observaciones = '' THEN NULL 
            ELSE p_observaciones 
        END,
        v_id_registrador
    );

    -- 5. Actualizar estatus del colaborador a Inactivo
    UPDATE colaboradores
    SET estatus_colaborador = 'Inactivo'
    WHERE id_colaborador = p_id_colaborador;

    -- 6. Todo OK
    SET p_resultado = 1;

END sp_insertar_inactividad_inicio//

DELIMITER ;


-- procedimiento Almacenado Retiro Coaborador
DROP PROCEDURE IF EXISTS sp_insertar_retiro;

DELIMITER //

CREATE PROCEDURE sp_insertar_retiro (
    IN p_id_colaborador INT,
    IN p_fecha_retiro DATE,
    IN p_motivo VARCHAR(255),
    IN p_detalles TEXT,
    IN p_paz_salvo ENUM('Paz y Salvo OK',
                        'Pendiente Paz y Salvo',
                        'Paz y Salvo no Encontrado',
                        'N/A',
                        'Informacion no Disponible'),
    IN p_usuario VARCHAR(100),
    OUT p_resultado INT
)
sp_insertar_retiro_inicio: BEGIN
    DECLARE v_id_registrador INT;

    -- 1. Usuario para auditoría
    SET @usuario_actual = p_usuario;

    -- 2. Obtener id_colaborador del usuario que registra
    SELECT id_colaborador
    INTO v_id_registrador
    FROM vista_usuarios
    WHERE usuario = p_usuario
    LIMIT 1;

    IF v_id_registrador IS NULL THEN
        SET p_resultado = -1;
        LEAVE sp_insertar_retiro_inicio;
    END IF;

    -- 3. Insertar registro de retiro
    INSERT INTO colaboradores_retirados (
        id_colaborador,
        fecha_retiro,
        motivo,
        detalles,
        registrado_por,
        paz_salvo
    ) VALUES (
        p_id_colaborador,
        p_fecha_retiro,
        p_motivo,
        CASE
            WHEN p_detalles IS NULL OR p_detalles = '' THEN NULL
            ELSE p_detalles
        END,
        v_id_registrador,
        p_paz_salvo
    );

    -- 4. Actualizar estatus del colaborador a Retirado
    UPDATE colaboradores
    SET estatus_colaborador = 'Retirado'
    WHERE id_colaborador = p_id_colaborador;

    -- 5. Marcar todos los contratos del colaborador como no vigentes
    UPDATE contratos
    SET contrato_vigente = 0
    WHERE id_colaborador = p_id_colaborador;

    -- 6. OK
    SET p_resultado = 1;

END sp_insertar_retiro_inicio//

DELIMITER ;

-- Procedimieto almacenado para actualizar registro de inactividad de colaborador
DROP PROCEDURE IF EXISTS sp_actualizar_inactividad;

DELIMITER //

CREATE PROCEDURE sp_actualizar_inactividad (
    IN p_id_inactividad INT,
    IN p_id_colaborador INT,
    IN p_tipo_inactividad ENUM('Incapacidad','Vacaciones','Licencia/Permiso','Inasistencia'),
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_observaciones TEXT,
    IN p_estado_actual TINYINT,
    IN p_usuario VARCHAR(100),
    OUT p_filas_afectadas INT
)
sp_actualizar_inactividad_inicio: BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Detectar cambios incluyendo estado_actual
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tbl_inactividades
    WHERE id_inactividad = p_id_inactividad
    AND id_colaborador = p_id_colaborador
    AND (
        COALESCE(tipo_inactividad, '') <> COALESCE(p_tipo_inactividad, '') OR
        COALESCE(fecha_inicio, '0000-00-00') <> COALESCE(p_fecha_inicio, '0000-00-00') OR
        COALESCE(fecha_fin, '0000-00-00') <> COALESCE(p_fecha_fin, '0000-00-00') OR
        COALESCE(observaciones, '') <> COALESCE(p_observaciones, '') OR
        COALESCE(estado_actual, 0) <> COALESCE(p_estado_actual, 0)
    );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_filas_afectadas = 0;
        LEAVE sp_actualizar_inactividad_inicio;
    END IF;

    -- Actualizar incluyendo estado_actual
    UPDATE tbl_inactividades
    SET
        tipo_inactividad = p_tipo_inactividad,
        fecha_inicio = p_fecha_inicio,
        fecha_fin = p_fecha_fin,
        observaciones = p_observaciones,
        estado_actual = p_estado_actual
    WHERE id_inactividad = p_id_inactividad
    AND id_colaborador = p_id_colaborador;

    COMMIT;

    SET p_filas_afectadas = 1;

END sp_actualizar_inactividad_inicio//

DELIMITER ;


-- Procedimiento Almacenado para eliminar un registro de tbl_inactividad
DROP PROCEDURE IF EXISTS sp_eliminar_inactividad;

DELIMITER //

CREATE PROCEDURE sp_eliminar_inactividad (
    IN  p_id_inactividad  INT,
    IN  p_id_colaborador  INT,
    IN  p_usuario         VARCHAR(100),
    OUT p_filas_afectadas INT
)
sp_eliminar_inactividad_inicio: BEGIN

    -- Handler para errores SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_filas_afectadas = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría (usado por los triggers)
    SET @usuario_actual = p_usuario;

    -- Verificar que el registro exista y pertenezca al colaborador indicado
    IF NOT EXISTS (
        SELECT 1
        FROM tbl_inactividades
        WHERE id_inactividad = p_id_inactividad
          AND id_colaborador = p_id_colaborador
    ) THEN
        ROLLBACK;
        SET p_filas_afectadas = 0;   -- nada que borrar
        LEAVE sp_eliminar_inactividad_inicio;
    END IF;

    -- Eliminar el registro
    DELETE FROM tbl_inactividades
    WHERE id_inactividad = p_id_inactividad
      AND id_colaborador = p_id_colaborador;

    COMMIT;

    -- 1 = eliminación exitosa
    SET p_filas_afectadas = 1;

END sp_eliminar_inactividad_inicio//

DELIMITER ;

-- SP de tablas de Satgging para vehiculos y conductores terceros

-- 1. limpiar_staging_conductores
DROP PROCEDURE IF EXISTS limpiar_staging_conductores;

DELIMITER //
CREATE PROCEDURE limpiar_staging_conductores()
BEGIN
    TRUNCATE TABLE staging_conductores_avansat;
END //
DELIMITER ;

-- 2. insertar_en_staging_conductores
DROP PROCEDURE IF EXISTS insertar_en_staging_conductores;

DELIMITER //
CREATE PROCEDURE insertar_en_staging_conductores(
    IN p_cc_id VARCHAR(20),
    IN p_nombre VARCHAR(200),
    IN p_estado VARCHAR(50)
)
BEGIN
    INSERT INTO staging_conductores_avansat (cc_id, nombre_completo, estado)
    VALUES (p_cc_id, p_nombre, p_estado);
END //
DELIMITER ;

-- 3. sp_sincronizar_conductores
DROP PROCEDURE IF EXISTS sp_sincronizar_conductores ;

DELIMITER //
CREATE PROCEDURE sp_sincronizar_conductores(
    OUT p_duracion INT,
    OUT p_inserts INT,
    OUT p_updates INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error sincronizando conductores';
    END;

    START TRANSACTION;
    SET @inicio = NOW();
    SET p_inserts = 0;
    SET p_updates = 0;

    -- 1. INSERTAR NUEVOS
    INSERT INTO conductores_terceros_avansat (cc_id, nombre, estado)
    SELECT s.cc_id, s.nombre_completo, s.estado
    FROM staging_conductores_avansat s
    LEFT JOIN conductores_terceros_avansat t ON t.cc_id = s.cc_id
    WHERE t.cc_id IS NULL;
    
    SET p_inserts = ROW_COUNT();

    -- 2. ACTUALIZAR EXISTENTES
    UPDATE conductores_terceros_avansat t
    JOIN staging_conductores_avansat s ON t.cc_id = s.cc_id
    SET 
        t.nombre = s.nombre_completo,
        t.estado = s.estado
    WHERE 
        COALESCE(s.nombre_completo,'') <> COALESCE(t.nombre,'') OR
        COALESCE(s.estado,'') <> COALESCE(t.estado,'');

    SET p_updates = ROW_COUNT();
    SET p_duracion = TIMESTAMPDIFF(SECOND, @inicio, NOW());
    
    COMMIT;
END //
DELIMITER ;


-- 4. limpiar_staging_vehiculos
DROP PROCEDURE IF EXISTS limpiar_staging_vehiculos;

DELIMITER //
CREATE PROCEDURE limpiar_staging_vehiculos()
BEGIN
    TRUNCATE TABLE staging_vehiculos_avansat;
END //
DELIMITER ;

-- 5. insertar_en_staging_vehiculos
DROP PROCEDURE IF EXISTS insertar_en_staging_vehiculos;

DELIMITER //
CREATE PROCEDURE insertar_en_staging_vehiculos(
    IN p_placa VARCHAR(20),
    IN p_marca VARCHAR(50),
    IN p_linea VARCHAR(100),
    IN p_modelo VARCHAR(10),
    IN p_ciudad_conductor_txt VARCHAR(100),
    IN p_capacidad VARCHAR(50),
    IN p_estado_vehiculo VARCHAR(50),
    IN p_nombre_conductor VARCHAR(150),
    IN p_cc_conductor VARCHAR(20),
    IN p_celular_conductor VARCHAR(50),
    IN p_direccion_conductor VARCHAR(255)
)
BEGIN
    INSERT INTO staging_vehiculos_avansat 
    (placa, marca, linea, modelo, ciudad_conductor_txt, capacidad, estado_vehiculo, nombre_conductor, cc_conductor, celular_conductor, direccion_conductor)
    VALUES 
    (p_placa, p_marca, p_linea, p_modelo, p_ciudad_conductor_txt, p_capacidad, p_estado_vehiculo, p_nombre_conductor, p_cc_conductor, p_celular_conductor, p_direccion_conductor);
END //
DELIMITER ;

-- 6. sp_sincronizar_vehiculos_complejo


DROP PROCEDURE IF EXISTS sp_sincronizar_vehiculos_complejo;
DELIMITER //

CREATE PROCEDURE sp_sincronizar_vehiculos_complejo(
    OUT p_duracion INT,
    OUT p_inserts INT,
    OUT p_updates INT
)
BEGIN
    DECLARE v_sql_state CHAR(5);
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        INSERT INTO log_errores_etl (operacion, descripcion_error, datos_fallidos)
        VALUES ('sp_sincronizar_vehiculos_complejo',
                CONCAT('Error SQL: ', v_sql_state, ' - ', v_error_msg),
                'Proceso abortado');
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @inicio = NOW();
    SET p_inserts = 0;
    SET p_updates = 0;

    /* =========================================================
       A. PERSONAS (igual que tenías; puedes luego quitar IGNORE)
       ========================================================= */
    INSERT IGNORE INTO proveedores_vehiculos_terceros
        (nombre, identificacion, telefono1, direccion, ciudad, estado, fecha_creacion, fecha_ultima_actualizacion)
    SELECT
        MAX(stg.nombre_conductor),
        stg.cc_conductor,
        MAX(stg.celular_conductor),
        MAX(stg.direccion_conductor),
        MAX(c.id_ciudad),
        MAX(IF(stg.estado_vehiculo = 'Habilitado', 'Habilitado', 'Deshabilitado')),
        CURDATE(),
        CURDATE()
    FROM staging_vehiculos_avansat stg
    LEFT JOIN ciudades c ON c.nombre = stg.ciudad_conductor_txt
    LEFT JOIN proveedores_vehiculos_terceros t ON t.identificacion = stg.cc_conductor
    WHERE stg.cc_conductor IS NOT NULL AND stg.cc_conductor <> ''
      AND stg.nombre_conductor IS NOT NULL AND stg.nombre_conductor <> ''
      AND t.identificacion IS NULL
    GROUP BY stg.cc_conductor;

    SET p_inserts = p_inserts + ROW_COUNT();

    DROP TEMPORARY TABLE IF EXISTS tmp_personas_upd;
    CREATE TEMPORARY TABLE tmp_personas_upd AS
    SELECT
        t.id_persona,
        MAX(stg.nombre_conductor) AS nombre,
        MAX(stg.celular_conductor) AS telefono,
        MAX(stg.direccion_conductor) AS direccion,
        MAX(c.id_ciudad) AS id_ciudad,
        MAX(IF(stg.estado_vehiculo = 'Habilitado', 'Habilitado', 'Deshabilitado')) AS nuevo_estado
    FROM staging_vehiculos_avansat stg
    JOIN proveedores_vehiculos_terceros t ON t.identificacion = stg.cc_conductor
    LEFT JOIN ciudades c ON c.nombre = stg.ciudad_conductor_txt
    WHERE stg.cc_conductor IS NOT NULL AND stg.cc_conductor <> ''
      AND stg.nombre_conductor IS NOT NULL AND stg.nombre_conductor <> ''
    GROUP BY t.id_persona;

    UPDATE proveedores_vehiculos_terceros t
    JOIN tmp_personas_upd tmp ON t.id_persona = tmp.id_persona
    SET
        t.nombre = tmp.nombre,
        t.telefono1 = tmp.telefono,
        t.direccion = tmp.direccion,
        t.ciudad = tmp.id_ciudad,
        t.estado = tmp.nuevo_estado,
        t.fecha_ultima_actualizacion = CURDATE()
    WHERE
        COALESCE(tmp.nombre, '') <> COALESCE(t.nombre, '') OR
        COALESCE(tmp.telefono, '') <> COALESCE(t.telefono1, '') OR
        COALESCE(tmp.direccion, '') <> COALESCE(t.direccion, '') OR
        COALESCE(tmp.id_ciudad, 0) <> COALESCE(t.ciudad, 0) OR
        COALESCE(tmp.nuevo_estado, '') <> COALESCE(t.estado, '');

    SET p_updates = p_updates + ROW_COUNT();
    DROP TEMPORARY TABLE IF EXISTS tmp_personas_upd;

    /* =========================================================
       B. VEHÍCULOS (AQUÍ VA EL ARREGLO: id_tipologia=13)
       - Quitar IGNORE para no silenciar problemas reales
       ========================================================= */
    INSERT INTO vehiculos_terceros
        (placa, marca, modelo, anio, id_tipologia, id_base, capacidad, estado)
    SELECT
        stg.placa,
        MAX(stg.marca),
        MAX(stg.linea),
        MAX(stg.modelo),
        13 AS id_tipologia,
        MAX(c.id_ciudad),
        MAX(stg.capacidad),
        MAX(stg.estado_vehiculo)
    FROM staging_vehiculos_avansat stg
    LEFT JOIN ciudades c ON c.nombre = stg.ciudad_conductor_txt
    LEFT JOIN vehiculos_terceros t ON t.placa = stg.placa
    WHERE stg.placa IS NOT NULL AND stg.placa <> ''
      AND t.placa IS NULL
    GROUP BY stg.placa;

    SET p_inserts = p_inserts + ROW_COUNT();

    DROP TEMPORARY TABLE IF EXISTS tmp_vehiculos_upd;
    CREATE TEMPORARY TABLE tmp_vehiculos_upd AS
    SELECT
        t.id_vehiculo,
        MAX(stg.marca) AS marca,
        MAX(stg.linea) AS modelo,
        MAX(stg.modelo) AS anio,
        13 AS id_tipologia,
        MAX(c.id_ciudad) AS id_ciudad,
        MAX(stg.capacidad) AS capacidad,
        MAX(stg.estado_vehiculo) AS estado
    FROM staging_vehiculos_avansat stg
    JOIN vehiculos_terceros t ON t.placa = stg.placa
    LEFT JOIN ciudades c ON c.nombre = stg.ciudad_conductor_txt
    GROUP BY t.id_vehiculo;

    UPDATE vehiculos_terceros t
    JOIN tmp_vehiculos_upd tmp ON t.id_vehiculo = tmp.id_vehiculo
    SET
        t.marca = tmp.marca,
        t.modelo = tmp.modelo,
        t.anio = tmp.anio,
        t.id_tipologia = tmp.id_tipologia,
        t.id_base = tmp.id_ciudad,
        t.capacidad = tmp.capacidad,
        t.estado = tmp.estado,
        t.fecha_ultima_actualizacion = NOW()
    WHERE
        COALESCE(tmp.marca, '') <> COALESCE(t.marca, '') OR
        COALESCE(tmp.modelo, '') <> COALESCE(t.modelo, '') OR
        COALESCE(tmp.anio, '') <> COALESCE(t.anio, '') OR
        COALESCE(tmp.id_tipologia, 0) <> COALESCE(t.id_tipologia, 0) OR
        COALESCE(tmp.id_ciudad, 0) <> COALESCE(t.id_base, 0) OR
        COALESCE(tmp.capacidad, '') <> COALESCE(t.capacidad, '') OR
        COALESCE(tmp.estado, '') <> COALESCE(t.estado, '');

    SET p_updates = p_updates + ROW_COUNT();
    DROP TEMPORARY TABLE IF EXISTS tmp_vehiculos_upd;

    /* =========================================================
       C. VINCULACIÓN
       - Ignorar SOLO duplicado PK con ON DUPLICATE KEY no-op
       ========================================================= */
    INSERT INTO vehiculo_persona (id_vehiculo, id_persona, roles)
    SELECT DISTINCT
        v.id_vehiculo,
        p.id_persona,
        'Conductor'
    FROM staging_vehiculos_avansat stg
    JOIN vehiculos_terceros v ON v.placa = stg.placa
    JOIN proveedores_vehiculos_terceros p ON p.identificacion = stg.cc_conductor
    WHERE stg.cc_conductor IS NOT NULL AND stg.cc_conductor <> ''
      AND stg.nombre_conductor IS NOT NULL AND stg.nombre_conductor <> ''
    ON DUPLICATE KEY UPDATE roles = roles;

    SET p_duracion = TIMESTAMPDIFF(SECOND, @inicio, NOW());
    COMMIT;
END //

DELIMITER ;


-- Procedimiento Almacenado para insertar motos, proveedores y relación persona-moto
DROP PROCEDURE IF EXISTS sp_insertar_moto_completa_terceros;
DELIMITER //

CREATE PROCEDURE sp_insertar_moto_completa_terceros(
    -- Parámetros del Vehículo
    IN p_tipo ENUM('MOTO','MOTOCARRO','BICICLETA'),
    IN p_placa VARCHAR(10),
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(50),
    IN p_anio INT,
    IN p_id_base INT,
    IN p_capacidad DECIMAL(10,2),
    IN p_estado_v ENUM('Habilitado','No Habilitado'),
    IN p_vencimiento_soat DATE,
    IN p_ans TINYINT,
    -- Parámetros de Personas (JSON)
    IN p_json_personas JSON,
    -- p_usuario es VARCHAR(50) para ambas tablas (motos y proveedores)
    IN p_usuario VARCHAR(50), 
    OUT p_id_vehiculo_gen INT
)
BEGIN
    DECLARE v_sql_state CHAR(5);
    DECLARE v_error_msg TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        INSERT INTO log_errores_etl (operacion, descripcion_error, datos_fallidos)
        VALUES ('sp_insertar_moto_completa_terceros', 
                CONCAT('Error SQL: ', v_sql_state, ' - ', v_error_msg), 
                CONCAT('Placa: ', p_placa));
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Insertar o actualizar Vehículo
    INSERT INTO motos_motocarros_terceros (
        tipo, placa, marca, modelo, anio, id_base, capacidad, 
        estado, fecha_vencimiento_soat, registrado_por, fecha_creacion, ANS
    ) VALUES (
        p_tipo, p_placa, p_marca, p_modelo, p_anio, p_id_base, p_capacidad, 
        p_estado_v, p_vencimiento_soat, p_usuario, NOW(), p_ans
    ) ON DUPLICATE KEY UPDATE
        tipo = VALUES(tipo), 
        marca = VALUES(marca), 
        modelo = VALUES(modelo),
        anio = VALUES(anio), 
        id_base = VALUES(id_base), 
        capacidad = VALUES(capacidad),
        estado = VALUES(estado), 
        fecha_vencimiento_soat = VALUES(fecha_vencimiento_soat),
        registrado_por = VALUES(registrado_por),
        fecha_ultima_actualizacion = NOW(), 
        ANS = VALUES(ANS);

    -- Obtener ID del vehículo (para la tabla puente)
    SELECT id_vehiculo INTO p_id_vehiculo_gen FROM motos_motocarros_terceros WHERE placa = p_placa;

    -- 2. Procesar Personas (proveedores) desde el JSON
    INSERT INTO proveedores_motos_terceros (
        nombre, identificacion, telefono1, direccion, ciudad, 
        estado, registrado_por, fecha_creacion
    )
    SELECT nombre, identificacion, telefono, direccion, ciudad, 'Habilitado', p_usuario, CURDATE()
    FROM JSON_TABLE(p_json_personas, '$[*]' COLUMNS (
        nombre VARCHAR(100) PATH '$.nombre',
        identificacion VARCHAR(20) PATH '$.id',
        telefono VARCHAR(20) PATH '$.tel',
        direccion VARCHAR(255) PATH '$.dir',
        ciudad INT PATH '$.ciu'
    )) AS jt
    ON DUPLICATE KEY UPDATE 
        nombre = VALUES(nombre), 
        telefono1 = VALUES(telefono1), 
        direccion = VALUES(direccion), 
        registrado_por = VALUES(registrado_por),
        fecha_ultima_actualizacion = CURDATE();

    -- 3. Vincular en la tabla puente (moto_persona_tercero)
    INSERT INTO moto_persona_tercero (id_vehiculo, id_persona, roles)
    SELECT 
        p_id_vehiculo_gen,
        p.id_persona,
        jt.rol
    FROM JSON_TABLE(p_json_personas, '$[*]' COLUMNS (
        identificacion VARCHAR(20) PATH '$.id',
        rol ENUM('Propietario','Tenedor','Conductor') PATH '$.rol'
    )) AS jt
    JOIN proveedores_motos_terceros p ON p.identificacion = jt.identificacion
    ON DUPLICATE KEY UPDATE roles = VALUES(roles);

    COMMIT;
END //
DELIMITER ;


-- Procedimiento almacenado para ingreso de candados satelitales a la operación
DROP PROCEDURE IF EXISTS sp_insertar_candado_satelital;
DELIMITER //

CREATE PROCEDURE sp_insertar_candado_satelital(
    IN p_numero_candado VARCHAR(20),
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(50)
)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_errno = MYSQL_ERRNO,
            v_msg   = MESSAGE_TEXT;

        ROLLBACK;

        IF v_errno = 1062 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Número de candado ya registrado';
        ELSE
            SET v_msg = CONCAT('Error SQL: ', v_msg);
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = v_msg;
        END IF;
    END;

    START TRANSACTION;

    INSERT INTO candados_satelitales (numero_candado, marca, modelo)
    VALUES (p_numero_candado, p_marca, p_modelo);

    COMMIT;
END //

DELIMITER ;


-- SP actualizar candado Satelital

DROP PROCEDURE IF EXISTS sp_actualizar_estatus_candado_satelital;
DELIMITER //

CREATE PROCEDURE sp_actualizar_estatus_candado_satelital(
    IN p_candado_id INT,
    IN p_estatus ENUM('EN OPERACION','FUERA DE OPERACION','MANTENIMIENTO','RETIRO DEFINITIVO')
)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg TEXT DEFAULT '';
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_errno = MYSQL_ERRNO,
            v_msg   = MESSAGE_TEXT;

        ROLLBACK;

        -- Duplicados no aplican en UPDATE, pero dejamos la misma estructura
        IF v_errno = 1062 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Conflicto de datos (duplicado).';
        ELSE
            SET v_msg = CONCAT('Error SQL: ', v_msg);
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = v_msg;
        END IF;
    END;

    START TRANSACTION;

    -- Validar que el candado_id exista
    SELECT COUNT(*)
      INTO v_existe
      FROM candados_satelitales
     WHERE candado_id = p_candado_id;

    IF v_existe = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El candado_id no existe';
    END IF;

    -- Actualizar estatus
    UPDATE candados_satelitales
       SET estatus = p_estatus
     WHERE candado_id = p_candado_id;

    COMMIT;
END //

DELIMITER ;


-- SP para registrrar el movimiento de los candados Satelitales
DROP PROCEDURE IF EXISTS sp_insertar_movimiento_candado;
DELIMITER //

CREATE PROCEDURE sp_insertar_movimiento_candado(
    IN p_candado_id INT,
    IN p_fecha DATE,
    IN p_ubicacion VARCHAR(150),
    IN p_placa_asignada VARCHAR(6),
    IN p_estatus_operativo ENUM('ASIGNADO','PEND RETORNO A BOGOTA','PEND QUE CONDUCTOR RECLAME','DISPONIBLE'),
    IN p_observaciones TEXT
)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg TEXT DEFAULT '';
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_errno = MYSQL_ERRNO,
            v_msg   = MESSAGE_TEXT;

        ROLLBACK;

        SET v_msg = CONCAT('Error SQL: ', v_msg);
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = v_msg;
    END;

    START TRANSACTION;

    -- Validar candado_id existente (FK lógica)
    SELECT COUNT(*)
      INTO v_existe
      FROM candados_satelitales
     WHERE candado_id = p_candado_id;

    IF v_existe = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El candado_id no existe';
    END IF;

    INSERT INTO movimiento_candados
        (candado_id, fecha, ubicacion, placa_asignada, estatus_operativo, observaciones)
    VALUES
        (p_candado_id, p_fecha, p_ubicacion, p_placa_asignada, p_estatus_operativo, p_observaciones);

    COMMIT;
END //

DELIMITER ;

-- Procedimeinto almacenado para actualizar datos y estado de Auxiliar Tercero

DROP PROCEDURE IF EXISTS sp_actualizar_auxiliar_tercero;

DELIMITER //

CREATE PROCEDURE sp_actualizar_auxiliar_tercero(
    IN  p_auxiliar_id         INT,
    IN  p_fecha               DATE,
    IN  p_tipo_documento      ENUM('CC','TI','CE','PA','PEP','PPT'),
    IN  p_documento           VARCHAR(20),
    IN  p_fecha_nacimiento    DATE,
    IN  p_nombre              VARCHAR(100),
    IN  p_grupo_sanguineo     ENUM('A','B','AB','O','N/D'),
    IN  p_rh                  ENUM('+','-','N/D'),
    IN  p_direccion           VARCHAR(255),
    IN  p_ciudad              INT,
    IN  p_eps                 VARCHAR(200),
    IN  p_arl                 VARCHAR(200),
    IN  p_estatus             ENUM('Activo','Inactivo'),
    IN  p_fecha_nuevo_estatus DATE,
    IN  p_usuario             VARCHAR(100),
    OUT p_resultado           INT
)
sp_actualizar_auxiliar_tercero:BEGIN
    DECLARE v_cambios_generales TINYINT DEFAULT 0;
    DECLARE v_cambio_estatus    TINYINT DEFAULT 0;

    -- Handler para errores SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    -- Fijar el usuario para la auditoría (por triggers que usen @usuario_actual)
    SET @usuario_actual = p_usuario;

    -- Detectar cambios generales (incluye estatus, pero no toca fecha_nuevo_estatus)
    SELECT COUNT(*) INTO v_cambios_generales
    FROM auxiliares_terceros
    WHERE auxiliar_id = p_auxiliar_id
      AND (
           COALESCE(fecha, '1000-01-01')              <> COALESCE(p_fecha, '1000-01-01')
        OR COALESCE(tipo_documento, '')               <> COALESCE(p_tipo_documento, '')
        OR COALESCE(documento, '')                    <> COALESCE(p_documento, '')
        OR COALESCE(fecha_nacimiento, '1000-01-01')   <> COALESCE(p_fecha_nacimiento, '1000-01-01')
        OR COALESCE(nombre, '')                       <> COALESCE(p_nombre, '')
        OR COALESCE(grupo_sanguineo, '')              <> COALESCE(p_grupo_sanguineo, '')
        OR COALESCE(rh, '')                           <> COALESCE(p_rh, '')
        OR COALESCE(direccion, '')                    <> COALESCE(p_direccion, '')
        OR COALESCE(ciudad, 0)                        <> COALESCE(p_ciudad, 0)
        OR COALESCE(eps, '')                          <> COALESCE(p_eps, '')
        OR COALESCE(arl, '')                          <> COALESCE(p_arl, '')
        OR COALESCE(estatus, '')                      <> COALESCE(p_estatus, '')
      );

    -- Detectar específicamente si cambió el estatus (valor → valor, no NULL → valor)
    SELECT COUNT(*) INTO v_cambio_estatus
    FROM auxiliares_terceros
    WHERE auxiliar_id = p_auxiliar_id
      AND estatus IS NOT NULL
      AND p_estatus IS NOT NULL
      AND estatus <> p_estatus;

    -- Si no hay cambios en nada, rollback y retornar 0
    IF v_cambios_generales = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_actualizar_auxiliar_tercero;
    END IF;

    -- Actualizar registro
    UPDATE auxiliares_terceros
    SET
        fecha               = p_fecha,
        tipo_documento      = p_tipo_documento,
        documento           = p_documento,
        fecha_nacimiento    = p_fecha_nacimiento,
        nombre              = p_nombre,
        grupo_sanguineo     = p_grupo_sanguineo,
        rh                  = p_rh,
        direccion           = p_direccion,
        ciudad              = p_ciudad,
        eps                 = p_eps,
        arl                 = p_arl,
        estatus             = p_estatus,
        fecha_nuevo_estatus = CASE
                                  WHEN v_cambio_estatus = 1 THEN p_fecha_nuevo_estatus
                                  ELSE fecha_nuevo_estatus
                               END
    WHERE auxiliar_id = p_auxiliar_id;

    COMMIT;
    SET p_resultado = 1;
END sp_actualizar_auxiliar_tercero//

DELIMITER ;


-- procedimiento almacenado actualizar moto tercero

DELIMITER //

CREATE PROCEDURE sp_actualizar_moto_tercero(
    IN  p_id_vehiculo           INT,
    IN  p_placa                 VARCHAR(10),
    IN  p_tipo                  ENUM('MOTO','MOTOCARRO','BICICLETA'),
    IN  p_marca                 VARCHAR(50),
    IN  p_modelo                VARCHAR(50),
    IN  p_anio                  INT,
    IN  p_id_base               INT,
    IN  p_capacidad             DECIMAL(10,2),
    IN  p_estado                ENUM('Habilitado','No Habilitado'),
    IN  p_fecha_vencimiento_soat DATE,
    IN  p_ans                   TINYINT,
    IN  p_usuario               VARCHAR(100),
    OUT p_resultado             INT
)
sp_actualizar_moto_tercero:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_cambio_estado TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Detectar cambios generales
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM motos_motocarros_terceros
    WHERE id_vehiculo = p_id_vehiculo
      AND (
           COALESCE(placa, '')                    <> COALESCE(p_placa, '')
        OR COALESCE(tipo, '')                     <> COALESCE(p_tipo, '')
        OR COALESCE(marca, '')                    <> COALESCE(p_marca, '')
        OR COALESCE(modelo, '')                   <> COALESCE(p_modelo, '')
        OR COALESCE(anio, 0)                      <> COALESCE(p_anio, 0)
        OR COALESCE(id_base, 0)                   <> COALESCE(p_id_base, 0)
        OR COALESCE(capacidad, 0)                 <> COALESCE(p_capacidad, 0)
        OR COALESCE(estado, '')                   <> COALESCE(p_estado, '')
        OR COALESCE(fecha_vencimiento_soat, '1000-01-01') <> COALESCE(p_fecha_vencimiento_soat, '1000-01-01')
        OR COALESCE(ans, 0)                       <> COALESCE(p_ans, 0)
      );

    -- Detectar cambio de estado específicamente (para lógica de deshabilitar personas)
    SELECT COUNT(*) INTO v_cambio_estado
    FROM motos_motocarros_terceros
    WHERE id_vehiculo = p_id_vehiculo
      AND estado IS NOT NULL
      AND p_estado IS NOT NULL
      AND estado <> p_estado
      AND p_estado = 'No Habilitado';

    -- Si no hay cambios, rollback y retornar 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_actualizar_moto_tercero;
    END IF;

    -- Si se deshabilita la moto, deshabilitar automáticamente todas sus personas
    IF v_cambio_estado = 1 THEN
        UPDATE proveedores_motos_terceros
        SET estado = 'Deshabilitado'
        WHERE id_persona IN (
            SELECT id_persona FROM moto_persona_tercero
            WHERE id_vehiculo = p_id_vehiculo
        );
    END IF;

    -- Actualizar moto
    UPDATE motos_motocarros_terceros
    SET
        placa                    = p_placa,
        tipo                     = p_tipo,
        marca                    = p_marca,
        modelo                   = p_modelo,
        anio                     = p_anio,
        id_base                  = p_id_base,
        capacidad                = p_capacidad,
        estado                   = p_estado,
        fecha_vencimiento_soat   = p_fecha_vencimiento_soat,
        ans                      = p_ans,
        fecha_ultima_actualizacion = NOW()
    WHERE id_vehiculo = p_id_vehiculo;

    COMMIT;
    SET p_resultado = 1;
END sp_actualizar_moto_tercero//

DELIMITER ;

-- Actualizar persona tercero (motos)
DELIMITER //

CREATE PROCEDURE sp_actualizar_persona_tercero(
    IN  p_id_persona        INT,
    IN  p_nombre            VARCHAR(100),
    IN  p_identificacion    VARCHAR(20),
    IN  p_telefono1         VARCHAR(20),
    IN  p_direccion         VARCHAR(255),
    IN  p_ciudad            INT,
    IN  p_estado            ENUM('Habilitado','Deshabilitado'),
    IN  p_usuario           VARCHAR(100),
    OUT p_resultado         INT
)
sp_actualizar_persona_tercero:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM proveedores_motos_terceros
    WHERE id_persona = p_id_persona
      AND (
           COALESCE(nombre, '')           <> COALESCE(p_nombre, '')
        OR COALESCE(identificacion, '')   <> COALESCE(p_identificacion, '')
        OR COALESCE(telefono1, '')        <> COALESCE(p_telefono1, '')
        OR COALESCE(direccion, '')        <> COALESCE(p_direccion, '')
        OR COALESCE(ciudad, 0)            <> COALESCE(p_ciudad, 0)
        OR COALESCE(estado, '')           <> COALESCE(p_estado, '')
      );

    -- Si no hay cambios, rollback y 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_actualizar_persona_tercero;
    END IF;

    -- Actualizar persona
    UPDATE proveedores_motos_terceros
    SET
        nombre                 = p_nombre,
        identificacion         = p_identificacion,
        telefono1              = p_telefono1,
        direccion              = p_direccion,
        ciudad                 = p_ciudad,
        estado                 = p_estado,
        fecha_ultima_actualizacion = CURDATE()
    WHERE id_persona = p_id_persona;

    COMMIT;
    SET p_resultado = 1;
END sp_actualizar_persona_tercero//

DELIMITER ;


-- Procedimiento Almacenado Agregar persona a moto
DELIMITER //

CREATE PROCEDURE sp_agregar_persona_a_moto(
    IN  p_id_vehiculo       INT,
    IN  p_id_persona        INT,
    IN  p_nombre            VARCHAR(100),
    IN  p_identificacion    VARCHAR(20),
    IN  p_telefono1         VARCHAR(20),
    IN  p_direccion         VARCHAR(255),
    IN  p_ciudad            INT,
    IN  p_rol               ENUM('Propietario','Tenedor','Conductor'),
    IN  p_usuario           VARCHAR(100),
    OUT p_resultado         INT
)
sp_agregar_persona_a_moto:BEGIN
    DECLARE v_id_persona_nuevo INT;
    DECLARE v_existe_relacion TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Si p_id_persona es NULL, crear nueva persona
    IF p_id_persona IS NULL THEN
        INSERT INTO proveedores_motos_terceros (nombre, identificacion, telefono1, direccion, ciudad, estado, registrado_por, fecha_creacion)
        VALUES (p_nombre, p_identificacion, p_telefono1, p_direccion, p_ciudad, 'Habilitado', p_usuario, CURDATE());
        
        SET v_id_persona_nuevo = LAST_INSERT_ID();
    ELSE
        SET v_id_persona_nuevo = p_id_persona;
    END IF;

    -- Validar que la relación no exista ya
    SELECT COUNT(*) INTO v_existe_relacion
    FROM moto_persona_tercero
    WHERE id_vehiculo = p_id_vehiculo
      AND id_persona = v_id_persona_nuevo
      AND roles = p_rol;

    IF v_existe_relacion > 0 THEN
        ROLLBACK;
        SET p_resultado = -2;  -- -2 = relación ya existe
        LEAVE sp_agregar_persona_a_moto;
    END IF;

    -- Insertar relación en moto_persona_tercero
    INSERT INTO moto_persona_tercero (id_vehiculo, id_persona, roles)
    VALUES (p_id_vehiculo, v_id_persona_nuevo, p_rol);

    COMMIT;
    SET p_resultado = 1;
END sp_agregar_persona_a_moto//

DELIMITER ;

-- Procedimiento alamcenado Eliminar relacion persona moto

DELIMITER //

CREATE PROCEDURE sp_eliminar_relacion_persona_moto(
    IN  p_id_vehiculo       INT,
    IN  p_id_persona        INT,
    IN  p_rol               ENUM('Propietario','Tenedor','Conductor'),
    IN  p_usuario           VARCHAR(100),
    OUT p_resultado         INT
)
sp_eliminar_relacion_persona_moto:BEGIN
    DECLARE v_filas_afectadas INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Eliminar la relación específica
    DELETE FROM moto_persona_tercero
    WHERE id_vehiculo = p_id_vehiculo
      AND id_persona = p_id_persona
      AND roles = p_rol;

    GET DIAGNOSTICS v_filas_afectadas = ROW_COUNT;

    IF v_filas_afectadas = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;  -- 0 = no encontrada
    ELSE
        COMMIT;
        SET p_resultado = 1;  -- 1 = eliminada
    END IF;
END sp_eliminar_relacion_persona_moto//

DELIMITER ;



DELIMITER //

CREATE PROCEDURE sp_crear_relacion_persona_moto(
    IN  p_id_vehiculo INT,
    IN  p_id_persona  INT,
    IN  p_rol         ENUM('Propietario','Tenedor','Conductor'),
    IN  p_usuario     VARCHAR(100),
    OUT p_resultado   INT
)
sp_crear_relacion_persona_moto:BEGIN
    DECLARE v_existe_relacion TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- Validar que la relación no exista ya
    SELECT COUNT(*) INTO v_existe_relacion
    FROM moto_persona_tercero
    WHERE id_vehiculo = p_id_vehiculo
      AND id_persona  = p_id_persona
      AND roles       = p_rol;

    IF v_existe_relacion > 0 THEN
        ROLLBACK;
        SET p_resultado = -2;  -- relación duplicada
        LEAVE sp_crear_relacion_persona_moto;
    END IF;

    INSERT INTO moto_persona_tercero (id_vehiculo, id_persona, roles)
    VALUES (p_id_vehiculo, p_id_persona, p_rol);

    COMMIT;
    SET p_resultado = 1;
END sp_crear_relacion_persona_moto//

DELIMITER ;

-- Procedimientos almacenados para Actualizar los parámetros de Operaciones

DELIMITER //

CREATE PROCEDURE sp_guardar_tarifas_deprisa_pxh(
    IN p_tarifa_id      INT,
    IN p_tipo           ENUM('CM','VN','MT'),
    IN p_estructura     ENUM('PXH Camion Urbano','PXH Camion Poblacion Sabana','PXH Van Urbano','MENSUALIDAD'),
    IN p_modelo         ENUM('ATO','PXH ESP','PXH POB','PXH URB'),
    IN p_base           INT,
    IN p_tonelaje       INT,
    IN p_valor          DECIMAL(10,2),
    IN p_auxiliar       INT,
    IN p_vigencia       INT,
    IN p_usuario        VARCHAR(100),
    OUT p_resultado     INT
)
sp_guardar_tarifas_deprisa_pxh:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_tarifa_id IS NULL OR p_tarifa_id = 0 THEN
    
        INSERT INTO tarifas_deprisa_PXH (
            tipo, 
            estructura, 
            modelo, 
            base, 
            tonelaje, 
            valor, 
            auxiliar, 
            vigencia
        ) VALUES (
            p_tipo, 
            p_estructura, 
            p_modelo, 
            p_base, 
            p_tonelaje, 
            p_valor, 
            p_auxiliar, 
            p_vigencia
        );
        
        SET p_resultado = 2; -- 2 indica Inserción exitosa
        COMMIT;
        LEAVE sp_guardar_tarifas_deprisa_pxh;
        
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    
    -- Validar que el registro exista
    SELECT COUNT(*) INTO v_existe FROM tarifas_deprisa_PXH WHERE tarifa_id = p_tarifa_id;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2; -- Código de error: ID proporcionado no existe
        LEAVE sp_guardar_tarifas_deprisa_pxh;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tarifas_deprisa_PXH
    WHERE tarifa_id = p_tarifa_id
      AND (
           COALESCE(tipo, '')        <> COALESCE(p_tipo, '')
        OR COALESCE(estructura, '')  <> COALESCE(p_estructura, '')
        OR COALESCE(modelo, '')      <> COALESCE(p_modelo, '')
        OR COALESCE(base, 0)         <> COALESCE(p_base, 0)
        OR COALESCE(tonelaje, 0)     <> COALESCE(p_tonelaje, 0)
        OR COALESCE(valor, 0)        <> COALESCE(p_valor, 0)
        OR COALESCE(auxiliar, 0)     <> COALESCE(p_auxiliar, 0)
        OR COALESCE(vigencia, 0)     <> COALESCE(p_vigencia, 0)
      );

    -- Si no hay cambios, rollback y 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0; -- 0 indica Sin cambios
        LEAVE sp_guardar_tarifas_deprisa_pxh;
    END IF;

    -- Actualizar registro
    UPDATE tarifas_deprisa_PXH
    SET
        tipo        = p_tipo,
        estructura  = p_estructura,
        modelo      = p_modelo,
        base        = p_base,
        tonelaje    = p_tonelaje,
        valor       = p_valor,
        auxiliar    = p_auxiliar,
        vigencia    = p_vigencia
    WHERE tarifa_id = p_tarifa_id;

    COMMIT;
    SET p_resultado = 1; -- 1 indica Actualización exitosa
    
END sp_guardar_tarifas_deprisa_pxh//

DELIMITER ;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_tarifas_deprisa_pxq //

CREATE PROCEDURE sp_guardar_tarifas_deprisa_pxq(
    IN p_tarifa_id      INT,
    IN p_tipo           ENUM('CM','VN','MT'),
    IN p_estructura     ENUM('PXQ Camion Urbano','PXQ Poblaciones','PXQ Van Urbano','PXQ Moto Urbano','PXQ Moto Poblacion'),
    IN p_modelo         ENUM('PXQ URB','PXQ POB'),
    IN p_base           INT,
    IN p_base_corta     VARCHAR(4),
    IN p_poblacion      INT,
    IN p_entrega        DECIMAL(10,2),
    IN p_recoleccion    DECIMAL(10,2),
    IN p_vigencia       INT,
    IN p_usuario        VARCHAR(100),
    OUT p_resultado     INT
)
sp_guardar_tarifas_deprisa_pxq:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_tarifa_id IS NULL OR p_tarifa_id = 0 THEN
        INSERT INTO tarifas_deprisa_PXQ (
            tipo, estructura, modelo, base, base_corta, 
            poblacion, entrega, recoleccion, vigencia
        ) VALUES (
            p_tipo, p_estructura, p_modelo, p_base, p_base_corta, 
            p_poblacion, p_entrega, p_recoleccion, p_vigencia
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM tarifas_deprisa_PXQ WHERE tarifa_id = p_tarifa_id;
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tarifas_deprisa_PXQ
    WHERE tarifa_id = p_tarifa_id
      AND (
           COALESCE(tipo, '')        <> COALESCE(p_tipo, '')
        OR COALESCE(estructura, '')  <> COALESCE(p_estructura, '')
        OR COALESCE(modelo, '')      <> COALESCE(p_modelo, '')
        OR COALESCE(base, 0)         <> COALESCE(p_base, 0)
        OR COALESCE(base_corta, '')  <> COALESCE(p_base_corta, '')
        OR COALESCE(poblacion, 0)    <> COALESCE(p_poblacion, 0)
        OR COALESCE(entrega, 0)      <> COALESCE(p_entrega, 0)
        OR COALESCE(recoleccion, 0)  <> COALESCE(p_recoleccion, 0)
        OR COALESCE(vigencia, 0)     <> COALESCE(p_vigencia, 0)
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    UPDATE tarifas_deprisa_PXQ
    SET
        tipo        = p_tipo,
        estructura  = p_estructura,
        modelo      = p_modelo,
        base        = p_base,
        base_corta  = p_base_corta,
        poblacion   = p_poblacion,
        entrega     = p_entrega,
        recoleccion = p_recoleccion,
        vigencia    = p_vigencia
    WHERE tarifa_id = p_tarifa_id;

    COMMIT;
    SET p_resultado = 1;
END //
DELIMITER ;


DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_parametros_empresa //

CREATE PROCEDURE sp_guardar_parametros_empresa(
    IN p_id_parametro       INT,
    IN p_nombre_parametro   VARCHAR(100),
    IN p_valor_parametro    DECIMAL(10,2),
    IN p_descripcion        TEXT,
    IN p_usuario            VARCHAR(100),
    OUT p_resultado         INT
)
sp_guardar_parametros_empresa:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_id_parametro IS NULL OR p_id_parametro = 0 THEN
        INSERT INTO parametros_empresa (
            nombre_parametro, 
            valor_parametro, 
            descripcion
        ) VALUES (
            p_nombre_parametro, 
            p_valor_parametro, 
            p_descripcion
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM parametros_empresa WHERE id_parametro = p_id_parametro;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM parametros_empresa
    WHERE id_parametro = p_id_parametro
      AND (
           COALESCE(nombre_parametro, '') <> COALESCE(p_nombre_parametro, '')
        OR COALESCE(valor_parametro, 0)   <> COALESCE(p_valor_parametro, 0)
        OR COALESCE(descripcion, '')      <> COALESCE(p_descripcion, '')
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    UPDATE parametros_empresa
    SET
        nombre_parametro = p_nombre_parametro,
        valor_parametro  = p_valor_parametro,
        descripcion      = p_descripcion
    WHERE id_parametro = p_id_parametro;

    COMMIT;
    SET p_resultado = 1;
END //

DELIMITER ;


DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_parametros_empresa //

CREATE PROCEDURE sp_guardar_parametros_empresa(
    IN p_id_parametro       INT,
    IN p_nombre_parametro   VARCHAR(100),
    IN p_valor_parametro    DECIMAL(10,2),
    IN p_descripcion        TEXT,
    IN p_usuario            VARCHAR(100),
    OUT p_resultado         INT
)
sp_guardar_parametros_empresa:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_id_parametro IS NULL OR p_id_parametro = 0 THEN
        INSERT INTO parametros_empresa (
            nombre_parametro, 
            valor_parametro, 
            descripcion
        ) VALUES (
            p_nombre_parametro, 
            p_valor_parametro, 
            p_descripcion
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM parametros_empresa WHERE id_parametro = p_id_parametro;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM parametros_empresa
    WHERE id_parametro = p_id_parametro
      AND (
           COALESCE(nombre_parametro, '') <> COALESCE(p_nombre_parametro, '')
        OR COALESCE(valor_parametro, 0)   <> COALESCE(p_valor_parametro, 0)
        OR COALESCE(descripcion, '')      <> COALESCE(p_descripcion, '')
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_parametros_empresa;
    END IF;

    UPDATE parametros_empresa
    SET
        nombre_parametro = p_nombre_parametro,
        valor_parametro  = p_valor_parametro,
        descripcion      = p_descripcion
    WHERE id_parametro = p_id_parametro;

    COMMIT;
    SET p_resultado = 1;
END //

DELIMITER ;


DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_tarifas_deprisa_pxq //

CREATE PROCEDURE sp_guardar_tarifas_deprisa_pxq(
    IN p_tarifa_id      INT,
    IN p_tipo           ENUM('CM','VN','MT'),
    IN p_estructura     ENUM('PXQ Camion Urbano','PXQ Poblaciones','PXQ Van Urbano','PXQ Moto Urbano','PXQ Moto Poblacion'),
    IN p_modelo         ENUM('PXQ URB','PXQ POB'),
    IN p_base           INT,
    IN p_base_corta     VARCHAR(4),
    IN p_poblacion      INT,
    IN p_entrega        DECIMAL(10,2),
    IN p_recoleccion    DECIMAL(10,2),
    IN p_vigencia       INT,
    IN p_usuario        VARCHAR(100),
    OUT p_resultado     INT
)
sp_guardar_tarifas_deprisa_pxq:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_tarifa_id IS NULL OR p_tarifa_id = 0 THEN
        INSERT INTO tarifas_deprisa_PXQ (
            tipo, estructura, modelo, base, base_corta, 
            poblacion, entrega, recoleccion, vigencia
        ) VALUES (
            p_tipo, p_estructura, p_modelo, p_base, p_base_corta, 
            p_poblacion, p_entrega, p_recoleccion, p_vigencia
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM tarifas_deprisa_PXQ WHERE tarifa_id = p_tarifa_id;
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tarifas_deprisa_PXQ
    WHERE tarifa_id = p_tarifa_id
      AND (
           COALESCE(tipo, '')        <> COALESCE(p_tipo, '')
        OR COALESCE(estructura, '')  <> COALESCE(p_estructura, '')
        OR COALESCE(modelo, '')      <> COALESCE(p_modelo, '')
        OR COALESCE(base, 0)         <> COALESCE(p_base, 0)
        OR COALESCE(base_corta, '')  <> COALESCE(p_base_corta, '')
        OR COALESCE(poblacion, 0)    <> COALESCE(p_poblacion, 0)
        OR COALESCE(entrega, 0)      <> COALESCE(p_entrega, 0)
        OR COALESCE(recoleccion, 0)  <> COALESCE(p_recoleccion, 0)
        OR COALESCE(vigencia, 0)     <> COALESCE(p_vigencia, 0)
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_tarifas_deprisa_pxq;
    END IF;

    UPDATE tarifas_deprisa_PXQ
    SET
        tipo        = p_tipo,
        estructura  = p_estructura,
        modelo      = p_modelo,
        base        = p_base,
        base_corta  = p_base_corta,
        poblacion   = p_poblacion,
        entrega     = p_entrega,
        recoleccion = p_recoleccion,
        vigencia    = p_vigencia
    WHERE tarifa_id = p_tarifa_id;

    COMMIT;
    SET p_resultado = 1;
END //
DELIMITER ;


DELIMITER //

CREATE PROCEDURE sp_guardar_tarifas_deprisa_pxh(
    IN p_tarifa_id      INT,
    IN p_tipo           ENUM('CM','VN','MT'),
    IN p_estructura     ENUM('PXH Camion Urbano','PXH Camion Poblacion Sabana','PXH Van Urbano','MENSUALIDAD'),
    IN p_modelo         ENUM('ATO','PXH ESP','PXH POB','PXH URB'),
    IN p_base           INT,
    IN p_tonelaje       INT,
    IN p_valor          DECIMAL(10,2),
    IN p_auxiliar       INT,
    IN p_vigencia       INT,
    IN p_usuario        VARCHAR(100),
    OUT p_resultado     INT
)
sp_guardar_tarifas_deprisa_pxh:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;

    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID es 0 o NULL)
    -- =============================================
    IF p_tarifa_id IS NULL OR p_tarifa_id = 0 THEN
    
        INSERT INTO tarifas_deprisa_PXH (
            tipo, 
            estructura, 
            modelo, 
            base, 
            tonelaje, 
            valor, 
            auxiliar, 
            vigencia
        ) VALUES (
            p_tipo, 
            p_estructura, 
            p_modelo, 
            p_base, 
            p_tonelaje, 
            p_valor, 
            p_auxiliar, 
            p_vigencia
        );
        
        SET p_resultado = 2; -- 2 indica Inserción exitosa
        COMMIT;
        LEAVE sp_guardar_tarifas_deprisa_pxh;
        
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    
    -- Validar que el registro exista
    SELECT COUNT(*) INTO v_existe FROM tarifas_deprisa_PXH WHERE tarifa_id = p_tarifa_id;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2; -- Código de error: ID proporcionado no existe
        LEAVE sp_guardar_tarifas_deprisa_pxh;
    END IF;

    -- Detectar cambios
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tarifas_deprisa_PXH
    WHERE tarifa_id = p_tarifa_id
      AND (
           COALESCE(tipo, '')        <> COALESCE(p_tipo, '')
        OR COALESCE(estructura, '')  <> COALESCE(p_estructura, '')
        OR COALESCE(modelo, '')      <> COALESCE(p_modelo, '')
        OR COALESCE(base, 0)         <> COALESCE(p_base, 0)
        OR COALESCE(tonelaje, 0)     <> COALESCE(p_tonelaje, 0)
        OR COALESCE(valor, 0)        <> COALESCE(p_valor, 0)
        OR COALESCE(auxiliar, 0)     <> COALESCE(p_auxiliar, 0)
        OR COALESCE(vigencia, 0)     <> COALESCE(p_vigencia, 0)
      );

    -- Si no hay cambios, rollback y 0
    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0; -- 0 indica Sin cambios
        LEAVE sp_guardar_tarifas_deprisa_pxh;
    END IF;

    -- Actualizar registro
    UPDATE tarifas_deprisa_PXH
    SET
        tipo        = p_tipo,
        estructura  = p_estructura,
        modelo      = p_modelo,
        base        = p_base,
        tonelaje    = p_tonelaje,
        valor       = p_valor,
        auxiliar    = p_auxiliar,
        vigencia    = p_vigencia
    WHERE tarifa_id = p_tarifa_id;

    COMMIT;
    SET p_resultado = 1; -- 1 indica Actualización exitosa
    
END sp_guardar_tarifas_deprisa_pxh//

DELIMITER ;



DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_tarifas_mensuales //

CREATE PROCEDURE sp_guardar_tarifas_mensuales(
    IN p_id                 INT,
    IN p_sector             VARCHAR(10),
    IN p_estacion           INT,
    IN p_ciudad_poblacion   INT,
    IN p_valor_cobro        DECIMAL(19,2),
    IN p_valor_pago         DECIMAL(19,2),
    IN p_usuario            VARCHAR(100),
    OUT p_resultado         INT
)
sp_guardar_tarifas_mensuales:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID 0 o NULL)
    -- =============================================
    IF p_id IS NULL OR p_id = 0 THEN
        INSERT INTO tarifas_mensuales (
            sector, 
            estacion, 
            ciudad_poblacion, 
            valor_cobro, 
            valor_pago
        ) VALUES (
            p_sector, 
            p_estacion, 
            p_ciudad_poblacion, 
            p_valor_cobro, 
            p_valor_pago
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_tarifas_mensuales;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM tarifas_mensuales WHERE id = p_id;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_tarifas_mensuales;
    END IF;

    -- Detectar cambios (Usamos <=> para manejar nulos correctamente)
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM tarifas_mensuales
    WHERE id = p_id
      AND (
           NOT (sector <=> p_sector)
        OR NOT (estacion <=> p_estacion)
        OR NOT (ciudad_poblacion <=> p_ciudad_poblacion)
        OR NOT (valor_cobro <=> p_valor_cobro)
        OR NOT (valor_pago <=> p_valor_pago)
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_tarifas_mensuales;
    END IF;

    UPDATE tarifas_mensuales
    SET
        sector           = p_sector,
        estacion         = p_estacion,
        ciudad_poblacion = p_ciudad_poblacion,
        valor_cobro      = p_valor_cobro,
        valor_pago       = p_valor_pago
    WHERE id = p_id;

    COMMIT;
    SET p_resultado = 1;
END //

DELIMITER ;


DELIMITER //

DROP PROCEDURE IF EXISTS sp_guardar_metodo_pago //

CREATE PROCEDURE sp_guardar_metodo_pago(
    IN p_id_metodo      INT,
    IN p_id_ciudad      INT,
    IN p_sector         VARCHAR(50),
    IN p_modelo         VARCHAR(100),
    IN p_concepto       VARCHAR(50),
    IN p_metodo_pago    VARCHAR(20),
    IN p_vehiculo       VARCHAR(5),
    IN p_usuario        VARCHAR(100),
    OUT p_resultado     INT
)
sp_guardar_metodo_pago:BEGIN
    DECLARE v_cambios_detectados TINYINT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = -1;
    END;

    START TRANSACTION;
    SET @usuario_actual = p_usuario;

    -- =============================================
    -- CASO 1: INSERCIÓN (ID 0 o NULL)
    -- =============================================
    IF p_id_metodo IS NULL OR p_id_metodo = 0 THEN
        INSERT INTO metodo_pago (
            id_ciudad, 
            sector, 
            modelo, 
            concepto, 
            metodo_pago, 
            vehiculo
        ) VALUES (
            p_id_ciudad, 
            p_sector, 
            p_modelo, 
            p_concepto, 
            p_metodo_pago, 
            p_vehiculo
        );
        SET p_resultado = 2; 
        COMMIT;
        LEAVE sp_guardar_metodo_pago;
    END IF;

    -- =============================================
    -- CASO 2: ACTUALIZACIÓN (ID > 0)
    -- =============================================
    SELECT COUNT(*) INTO v_existe FROM metodo_pago WHERE id_metodo = p_id_metodo;
    
    IF v_existe = 0 THEN
        ROLLBACK;
        SET p_resultado = -2;
        LEAVE sp_guardar_metodo_pago;
    END IF;

    -- Detectar cambios (Usamos <=> para manejar nulos)
    SELECT COUNT(*) INTO v_cambios_detectados
    FROM metodo_pago
    WHERE id_metodo = p_id_metodo
      AND (
           NOT (id_ciudad <=> p_id_ciudad)
        OR NOT (sector <=> p_sector)
        OR NOT (modelo <=> p_modelo)
        OR NOT (concepto <=> p_concepto)
        OR NOT (metodo_pago <=> p_metodo_pago)
        OR NOT (vehiculo <=> p_vehiculo)
      );

    IF v_cambios_detectados = 0 THEN
        ROLLBACK;
        SET p_resultado = 0;
        LEAVE sp_guardar_metodo_pago;
    END IF;

    UPDATE metodo_pago
    SET
        id_ciudad   = p_id_ciudad,
        sector      = p_sector,
        modelo      = p_modelo,
        concepto    = p_concepto,
        metodo_pago = p_metodo_pago,
        vehiculo    = p_vehiculo
    WHERE id_metodo = p_id_metodo;

    COMMIT;
    SET p_resultado = 1;
END //

DELIMITER ;








