-- SP Carga Inicial talento Humano
DELIMITER //

CREATE PROCEDURE insertar_colaborador_carga_inicial (
    IN p_id_colaborador INT,
    IN p_tipo_id ENUM('CC','TI','CE','PA','PEP','PPT'),
    IN p_id_cc VARCHAR(20),
    IN p_lugar_expedicion INT,
    IN p_fecha_expedicion DATE,
    IN p_primer_nombre VARCHAR(100),
    IN p_segundo_nombre VARCHAR(100),
    IN p_primer_apellido VARCHAR(100),
    IN p_segundo_apellido VARCHAR(100),
    IN p_formacion_academica ENUM('Primaria','Bachillerato','Tecnico','Tecnologo','Pregrado','Especializacion','Postgrado','Maestria','Doctorado', 'No Disponible'),
    IN p_estado_formacion_academica ENUM('Termino','En curso','Incompleta', 'No Disponible'),
    IN p_fecha_nacimiento DATE,
    IN p_sexo VARCHAR(10),
    IN p_grupo_sanguineo ENUM('A','B','AB','O', 'N/D'),
    IN p_rh ENUM('+','-', 'N/D'),
    IN p_estado_civil ENUM('soltero(a)','casado(a)','union libre','viudo(a)','divorciado(a)', 'No Disponible'),
    IN p_direccion VARCHAR(255),
    IN p_barrio VARCHAR(200),
    IN p_estrato VARCHAR(10),
    IN p_ciudad_nacimiento INT,
    IN p_departamento_nacimiento INT,
    IN p_pais_nacimiento INT,
    IN p_estatus_colaborador ENUM('Activo','Inactivo','Retirado'),
    IN p_departamento INT,
    IN p_cargo INT,
    IN p_sede INT,
    IN p_planta VARCHAR(20),
    IN p_fecha_emo DATE,
    IN p_fecha_proximo_emo DATE,
    IN p_fecha_elaboracion_carnet DATE,
    IN p_ruta_induccion TINYINT,
    IN p_contacto_emergencia VARCHAR(150),
    IN p_telefono_contacto_emergencia VARCHAR(150)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del colaborador. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Validar que no exista el ID del colaborador ni la cédula
    IF EXISTS (SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe un colaborador con ese ID.';
    END IF;

    IF EXISTS (SELECT 1 FROM colaboradores WHERE id_cc = p_id_cc) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe un colaborador con esa identificación.';
    END IF;

    INSERT INTO colaboradores (
        id_colaborador, tipo_id, id_cc, lugar_expedicion, fecha_expedicion,
        primer_nombre, segundo_nombre, primer_apellido, segundo_apellido,
        formacion_academica, estado_formacion_academica, fecha_nacimiento,
        sexo, grupo_sanguineo, rh, estado_civil, direccion, barrio, estrato,
        ciudad_nacimiento, departamento_nacimiento, pais_nacimiento,
        estatus_colaborador, departamento, cargo, sede, planta,
        fecha_emo, fecha_proximo_emo, fecha_elaboracion_carnet,
        ruta_induccion, contacto_emergencia, telefono_contacto_emergencia
    ) VALUES (
        p_id_colaborador, p_tipo_id, p_id_cc, p_lugar_expedicion, p_fecha_expedicion,
        p_primer_nombre, p_segundo_nombre, p_primer_apellido, p_segundo_apellido,
        p_formacion_academica, p_estado_formacion_academica, p_fecha_nacimiento,
        p_sexo, p_grupo_sanguineo, p_rh, p_estado_civil, p_direccion, p_barrio, p_estrato,
        p_ciudad_nacimiento, p_departamento_nacimiento, p_pais_nacimiento,
        p_estatus_colaborador, p_departamento, p_cargo, p_sede, p_planta,
        p_fecha_emo, p_fecha_proximo_emo, p_fecha_elaboracion_carnet,
        p_ruta_induccion, p_contacto_emergencia, p_telefono_contacto_emergencia
    );

    COMMIT;
END //

DELIMITER ;

-- Actualizacion id_jefe para cada id_colaborador
DELIMITER //

CREATE PROCEDURE actualizar_jefe_colaborador (
    IN p_id_colaborador INT,
    IN p_id_jefe INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la actualización del jefe. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que exista el colaborador
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador no existe.';
    END IF;

    -- Verificar que exista el jefe (opcional pero recomendable)
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_jefe
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El jefe no existe.';
    END IF;

    -- Actualizar jefe
    UPDATE colaboradores
    SET id_jefe = p_id_jefe
    WHERE id_colaborador = p_id_colaborador;

    COMMIT;
END //

DELIMITER ;

-- Ingresar datos de contratos carga inicial
DROP PROCEDURE IF EXISTS insertar_contrato_colaborador;

DELIMITER //

CREATE PROCEDURE insertar_contrato_colaborador (
    IN p_id_colaborador INT,
    IN p_fecha_ingreso DATE,
    IN p_tipo_contrato ENUM('Indefinido','Obra o Labor','Aprendizaje','Termino fijo','Obra o Labor - Medio Tiempo', 'Aprendizaje - Medio Tiempo'),
    IN p_termino_meses DATE,
    IN p_forma_pago ENUM('Mensual','Quincenal','Semanal','Diario'),
    IN p_id_centro_costo INT,
    IN p_salario_base DECIMAL(12,2),
    IN p_aux_alimentacion DECIMAL(12,2),
    IN p_aux_transporte DECIMAL(12,2),
    IN p_salario_integral TINYINT,
    IN p_rodamiento DECIMAL(12,2),
    IN p_turno VARCHAR(50),
    IN p_contrato TINYINT,
    IN p_fecha_afiliacion_arl DATE,
    IN p_fecha_afiliacion_eps DATE,
    IN p_fecha_afiliacion_ccf DATE,
    IN p_num_ultimo_otro_si INT,
    IN p_dias_pp INT  -- <--- NUEVO PARÁMETRO AGREGADO
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del contrato. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Validar que el colaborador exista
    IF NOT EXISTS (SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    INSERT INTO contratos (
        id_colaborador, fecha_ingreso, tipo_contrato, termino_meses,
        forma_pago, id_centro_costo, salario_base, aux_alimentacion,
        aux_transporte, salario_integral, rodamiento, turno, contrato,
        fecha_afiliacion_arl, fecha_afiliacion_eps, fecha_afiliacion_ccf,
        num_ultimo_otro_si,
        dias_pp  -- <--- NUEVO CAMPO INSERTADO
    ) VALUES (
        p_id_colaborador, p_fecha_ingreso, p_tipo_contrato, p_termino_meses,
        p_forma_pago, p_id_centro_costo, p_salario_base, p_aux_alimentacion,
        p_aux_transporte, p_salario_integral, p_rodamiento, p_turno, p_contrato,
        p_fecha_afiliacion_arl, p_fecha_afiliacion_eps, p_fecha_afiliacion_ccf,
        p_num_ultimo_otro_si,
        p_dias_pp -- <--- VALOR DEL NUEVO CAMPO
    );

    COMMIT;
END //

DELIMITER ;



-- Insertar carga inicial de contactos_colaboradores
DELIMITER //

CREATE PROCEDURE insertar_contacto_colaborador (
    IN p_id_colaborador INT,
    IN p_tipo ENUM('email_personal','email_corporativo','movil_personal','movil_corporativo','whatsapp','telefono_fijo'),
    IN p_valor VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del contacto. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que exista el colaborador
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador no existe.';
    END IF;

    INSERT INTO contactos_colaboradores (
        id_colaborador, tipo, valor
    ) VALUES (
        p_id_colaborador, p_tipo, p_valor
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar carga inicial seguridad_social
DELIMITER //

CREATE PROCEDURE insertar_seguridad_social (
    IN p_id_empleado INT,
    IN p_cesantias VARCHAR(100),
    IN p_pension VARCHAR(100),
    IN p_eps VARCHAR(100),
    IN p_arl VARCHAR(100),
    IN p_riesgo ENUM('I','II','III','IV','V'),
    IN p_ccf VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción de la seguridad social. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que el empleado exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_empleado
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El empleado especificado no existe.';
    END IF;

    INSERT INTO seguridad_social (
        id_empleado, cesantias, pension, eps, arl, riesgo, ccf
    ) VALUES (
        p_id_empleado, p_cesantias, p_pension, p_eps, p_arl, p_riesgo, p_ccf
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar datos de Bancos colaboradores carga inicial
DELIMITER //

CREATE PROCEDURE insertar_cuenta_bancaria_colaborador (
    IN p_id_colaborador INT,
    IN p_banco_id INT,
    IN p_tipo_cuenta ENUM('Ahorros','Corriente'),
    IN p_num_cuenta VARCHAR(100),
    IN p_cta_contable_banco VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción de la cuenta bancaria. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que exista el colaborador si se especifica
    IF p_id_colaborador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    -- Verificar que exista el banco si se especifica
    IF p_banco_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bancos WHERE banco_id = p_banco_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El banco especificado no existe.';
    END IF;

    INSERT INTO cuentas_bancarias_colaboradores (
        id_colaborador, banco_id, tipo_cuenta, num_cuenta, cta_contable_banco
    ) VALUES (
        p_id_colaborador, p_banco_id, p_tipo_cuenta, p_num_cuenta, p_cta_contable_banco
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar datos de beneficiarios de colaboradores carga inicial
DELIMITER //

CREATE PROCEDURE insertar_beneficiario_colaborador (
    IN p_id_colaborador INT,
    IN p_nombre VARCHAR(100),
    IN p_genero ENUM('M','F','Otro'),
    IN p_fecha_nacimiento DATE
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del beneficiario. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que el colaborador exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    INSERT INTO beneficiarios (
        id_colaborador, nombre, genero, fecha_nacimiento
    ) VALUES (
        p_id_colaborador, p_nombre, p_genero, p_fecha_nacimiento
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar informacion de periodos de prueba carga inicial
DELIMITER //

CREATE PROCEDURE insertar_pp_colaborador (
    IN p_id_colaborador INT,
    IN p_dias_pp INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del PP. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Validar que el colaborador exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    INSERT INTO pp (
        id_colaborador, dias_pp
    ) VALUES (
        p_id_colaborador, p_dias_pp
    );

    COMMIT;
END //

DELIMITER ;

-- Insertar datos de conductores carga inicial
DELIMITER //

CREATE PROCEDURE insertar_conductor_colaborador (
    IN p_id_colaborador INT,
    IN p_tipo_licencia ENUM('A1','A2','B1','B2','B3','C1','C2','C3'),
    IN p_observaciones_restricciones VARCHAR(255),
    IN p_fecha_vencimiento_lic DATE
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción del conductor. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Validar que el colaborador exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    -- Validar que no haya ya un registro para ese colaborador (restricción UNIQUE)
    IF EXISTS (
        SELECT 1 FROM conductores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe un conductor asociado a este colaborador.';
    END IF;

    INSERT INTO conductores (
        id_colaborador, tipo_licencia, observaciones_restricciones, fecha_vencimiento_lic
    ) VALUES (
        p_id_colaborador, p_tipo_licencia, p_observaciones_restricciones, p_fecha_vencimiento_lic
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar tallas de colaboradores carga inicial
DELIMITER //

CREATE PROCEDURE insertar_tallas_dotacion (
    IN p_id_colaborador INT,
    IN p_talla_pantalon VARCHAR(5),
    IN p_talla_camisa VARCHAR(5),
    IN p_talla_botas VARCHAR(5)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción de tallas de dotación. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que el colaborador exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    INSERT INTO tallas_dotacion (
        id_colaborador, talla_pantalon, talla_camisa, talla_botas
    ) VALUES (
        p_id_colaborador, p_talla_pantalon, p_talla_camisa, p_talla_botas
    );

    COMMIT;
END //

DELIMITER ;


-- Insertar datos colaboradores retirados retirados
DELIMITER //

CREATE PROCEDURE insertar_colaborador_retirado (
    IN p_id_colaborador INT,
    IN p_fecha_retiro DATE,
    IN p_motivo VARCHAR(255),
    IN p_detalles TEXT,
    IN p_registrado_por VARCHAR(100),
    IN p_paz_salvo ENUM('Paz y Salvo OK','Pendiente Paz y Salvo','Paz y Salvo no Encontrado','N/A','Informacion no Disponible')
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error durante la inserción en colaboradores_retirados. Transacción revertida.';
    END;

    START TRANSACTION;

    -- Verificar que el colaborador exista
    IF NOT EXISTS (
        SELECT 1 FROM colaboradores WHERE id_colaborador = p_id_colaborador
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El colaborador especificado no existe.';
    END IF;

    INSERT INTO colaboradores_retirados (
        id_colaborador, fecha_retiro, motivo, detalles, registrado_por, paz_salvo
    ) VALUES (
        p_id_colaborador, p_fecha_retiro, p_motivo, p_detalles, p_registrado_por, p_paz_salvo
    );

    COMMIT;
END //

DELIMITER ;


-- SP Carga Inicial Seguridad

DELIMITER $$

CREATE PROCEDURE sp_insertar_vehiculo_tercero_carga_inicial (
    IN p_id_vehiculo INT,
    IN p_placa VARCHAR(10),
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(50),
    IN p_anio INT,
    IN p_id_tipologia INT,
    IN p_id_base INT,
    IN p_capacidad DECIMAL(10,2),
    IN p_fecha_vencimiento_soat DATE
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;         -- relanza la excepción
    END;

    START TRANSACTION;

    INSERT INTO vehiculos_terceros (
      id_vehiculo, placa, marca, modelo, anio,
      id_tipologia, id_base, capacidad, estado,
      fecha_vencimiento_soat, registrado_por,
      fecha_creacion, fecha_ultima_actualizacion, ANS
    ) VALUES (
      p_id_vehiculo, p_placa, p_marca, p_modelo, p_anio,
      p_id_tipologia, p_id_base, p_capacidad, 'Habilitado',
      p_fecha_vencimiento_soat, NULL, NULL, NULL, 0
    );

    COMMIT;
END$$

DELIMITER ;

-- Carga inicial proveedores vehiculos terceros
DELIMITER $$


-- SP insertar provvedores de vehiculos terceros
CREATE PROCEDURE sp_insertar_proveedor_vehiculo_carga_inicial (
    IN p_id_persona INT,
    IN p_nombre VARCHAR(100),
    IN p_identificacion VARCHAR(20),
    IN p_telefono1 VARCHAR(20),
    IN p_direccion VARCHAR(255),
    IN p_ciudad INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO proveedores_vehiculos_terceros (
        id_persona,
        nombre,
        identificacion,
        telefono1,
        direccion,
        ciudad,
        estado,
        registrado_por,
        fecha_creacion,
        fecha_ultima_actualizacion
    ) VALUES (
        p_id_persona,
        p_nombre,
        p_identificacion,
        p_telefono1,
        p_direccion,
        p_ciudad,
        'Habilitado',
        NULL,
        NULL,
        NULL
    );

    COMMIT;
END$$

DELIMITER ;


-- SP insertar vehiculo-persona
DELIMITER //

CREATE PROCEDURE sp_insertar_vehiculo_persona_carga_inicial (
    IN p_id_vehiculo INT,
    IN p_id_persona INT,
    IN p_rol ENUM('Propietario', 'Tenedor', 'Conductor')
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO vehiculo_persona (
        id_vehiculo,
        id_persona,
        roles
    ) VALUES (
        p_id_vehiculo,
        p_id_persona,
        p_rol
    );

    COMMIT;
END //

DELIMITER ;


-- SP Carga inicial histórico despachos Operaciones Deprisa
-- Elimina el procedimiento si ya existe para evitar errores en la recreación
DROP PROCEDURE IF EXISTS sp_insertar_operacion;	

-- Cambia el delimitador para que MySQL no se confunda con los ';' dentro del procedimiento
DELIMITER //

CREATE PROCEDURE sp_insertar_operacion(
    IN p_servicio INT,
    IN p_driver INT,
    IN p_vehiculo ENUM('CAMION','MOTO','VAN'),
    IN p_estacion INT,
    IN p_fecha DATE,
    IN p_proveedor ENUM('PYP','TCR','FDZ1','FDZ2'),
    IN p_tonelaje INT,
    IN p_sector VARCHAR(50),
    IN p_placa VARCHAR(10),
    IN p_hora_inicio TIME,
    IN p_hora_final TIME,
    IN p_horas_no_operativas FLOAT,
    IN p_nombre_ruta TEXT,
    IN p_clasificacion_uso_PxH ENUM(
        '1. Solo UM','2. Solo PM','3. Mixto (UM-PM)',
        '4. Vehiculo circular','5. Aeropuerto',
        '6. Vehiculo dedicado cliente'
    ),
    IN p_cc_conductor VARCHAR(20),
    IN p_cc_aux_1 VARCHAR(20),
    IN p_cc_aux_2 VARCHAR(20),
    IN p_cantidad_envios INT,
    IN p_cantidad_devoluciones INT,
    IN p_cantidad_recolecciones INT,
    IN p_cantidad_no_recogidos INT,
    IN p_km_inicial FLOAT,
    IN p_km_final FLOAT,
    IN p_tipo_pago ENUM('MENSUAL','CAJA MENOR','TRANS PRONTO PAGO','NO'),
    IN p_remesa VARCHAR(20),
    IN p_manifiesto VARCHAR(20),
    -- Nuevos parámetros para historico_operaciones
    IN p_total_cobro INT,
    IN p_total_turno INT,
    IN p_cobro_auxiliar INT,
    IN p_cobro_sin_auxiliar INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: inserción fallida, transacción revertida.';
    END;

    START TRANSACTION;

    -- Inserción en tabla operaciones
    INSERT INTO operaciones (
        servicio, driver, vehiculo, estacion, fecha, proveedor, tonelaje,
        sector, placa, hora_inicio, hora_final, horas_no_operativas,
        nombre_ruta, clasificacion_uso_PxH, cc_conductor, cc_aux_1,
        cc_aux_2, cantidad_envios, cantidad_devoluciones, cantidad_recolecciones,
        cantidad_no_recogidos, km_inicial, km_final, tipo_pago, remesa, manifiesto
    )
    VALUES (
        p_servicio, p_driver, p_vehiculo, p_estacion, p_fecha, p_proveedor,
        p_tonelaje, p_sector, p_placa, p_hora_inicio, p_hora_final,
        p_horas_no_operativas, p_nombre_ruta, p_clasificacion_uso_PxH,
        p_cc_conductor, p_cc_aux_1, p_cc_aux_2, p_cantidad_envios,
        p_cantidad_devoluciones, p_cantidad_recolecciones,
        p_cantidad_no_recogidos, p_km_inicial, p_km_final,
        p_tipo_pago, p_remesa, p_manifiesto
    );

    -- Capturar el ID generado
    SET @v_operacion_id = LAST_INSERT_ID();

    -- Inserción en tabla historico_operaciones
    INSERT INTO historico_operaciones (
        operacion_id,
        total_cobro,
        total_turno,
        cobro_auxiliar,
        cobro_sin_auxiliar
    )
    VALUES (
        @v_operacion_id,
        p_total_cobro,
        p_total_turno,
        p_cobro_auxiliar,
        p_cobro_sin_auxiliar
    );

    COMMIT;
END //

DELIMITER ;











