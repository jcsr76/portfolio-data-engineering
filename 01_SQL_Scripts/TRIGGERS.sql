-- ##ejecutar antes de probar un procedimiento almacenado o un trigger##
SET @usuario_actual = 'Administrador';
SELECT @usuario_actual;  


-- Trigger 1: AFTER INSERT ON operaciones
-- Este trigger registrará los valores insertados, uno por cada campo auditado:
DROP TRIGGER IF EXISTS trg_operaciones_insert;

DELIMITER //

CREATE TRIGGER trg_operaciones_insert
AFTER INSERT ON operaciones
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');  -- Asignar 'Desconocido' si @usuario_actual es NULL

  INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
  VALUES 
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'servicio', NULL, NEW.servicio),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'driver', NULL, NEW.driver),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'vehiculo', NULL, NEW.vehiculo),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'estacion', NULL, NEW.estacion),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'fecha', NULL, NEW.fecha),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'proveedor', NULL, NEW.proveedor),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'tonelaje', NULL, NEW.tonelaje),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'sector', NULL, NEW.sector),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'placa', NULL, NEW.placa),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'hora_inicio', NULL, NEW.hora_inicio),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'nombre_ruta', NULL, NEW.nombre_ruta),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'clasificacion_uso_PxH', NULL, NEW.clasificacion_uso_PxH),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'cc_conductor', NULL, NEW.cc_conductor),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'cc_aux_1', NULL, NEW.cc_aux_1),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'cc_aux_2', NULL, NEW.cc_aux_2),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'cantidad_envios', NULL, NEW.cantidad_envios),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'km_inicial', NULL, NEW.km_inicial),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'tipo_pago', NULL, NEW.tipo_pago),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'remesa', NULL, NEW.remesa),
    (v_usuario, 'Inserción', 'operaciones', NEW.operacion_id, 'manifiesto', NULL, NEW.manifiesto);
END//

DELIMITER ;


-- ##Este trigger registrará en auditoria cuando se completen los campos faltantes para el cierre de operacion: o en la conciliacion de la operación##


DROP TRIGGER IF EXISTS trg_operaciones_update;

DELIMITER //

CREATE TRIGGER trg_operaciones_update
AFTER UPDATE ON operaciones
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');  -- Asignar 'Desconocido' si @usuario_actual es NULL

  -- Si hora_final o km_final son NULL, consideramos que es Cierre_Operacion
  IF (NEW.hora_final IS NULL OR NEW.km_final IS NULL) THEN
    -- Lógica para Cierre_Operacion, donde los campos pueden estar NULL
    IF NOT (OLD.km_final <=> NEW.km_final) THEN
      INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
      ) VALUES (
        v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'km_final', OLD.km_final, NEW.km_final
      );
    END IF;

    IF NOT (OLD.hora_final <=> NEW.hora_final) THEN
      INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
      ) VALUES (
        v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'hora_final', OLD.hora_final, NEW.hora_final
      );
    END IF;

  ELSE
    -- Lógica para Conciliacion_Operacion, donde los campos no deben ser NULL
    IF NEW.hora_final IS NULL OR NEW.km_final IS NULL THEN
      -- Si hora_final o km_final son NULL, lanzamos un error
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los campos hora_final y km_final no pueden ser NULL en Conciliacion_Operacion';
    ELSE
      -- Registrar cambios en `hora_final` y `km_final` si son válidos
      IF NOT (OLD.hora_final <=> NEW.hora_final) THEN
        INSERT INTO auditoria (
          usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
        ) VALUES (
          v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'hora_final', OLD.hora_final, NEW.hora_final
        );
      END IF;

      IF NOT (OLD.km_final <=> NEW.km_final) THEN
        INSERT INTO auditoria (
          usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
        ) VALUES (
          v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'km_final', OLD.km_final, NEW.km_final
        );
      END IF;
    END IF;
  END IF;

  -- Registrar cambios en otros campos (tonelaje, hora_inicio, cantidad_devoluciones, etc.)
  -- Estos cambios no necesitan distinción entre formularios
  IF NOT (OLD.tonelaje <=> NEW.tonelaje) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'tonelaje', OLD.tonelaje, NEW.tonelaje
    );
  END IF;

  -- Registrar cambios en `hora_inicio`
  IF NOT (OLD.hora_inicio <=> NEW.hora_inicio) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'hora_inicio', OLD.hora_inicio, NEW.hora_inicio
    );
  END IF;

  -- Registrar cambios en `cantidad_devoluciones`
  IF NOT (OLD.cantidad_devoluciones <=> NEW.cantidad_devoluciones) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'cantidad_devoluciones', OLD.cantidad_devoluciones, NEW.cantidad_devoluciones
    );
  END IF;

  -- Registrar cambios en `cantidad_recolecciones`
  IF NOT (OLD.cantidad_recolecciones <=> NEW.cantidad_recolecciones) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'cantidad_recolecciones', OLD.cantidad_recolecciones, NEW.cantidad_recolecciones
    );
  END IF;

  -- Registrar cambios en `cantidad_no_recogidos`
  IF NOT (OLD.cantidad_no_recogidos <=> NEW.cantidad_no_recogidos) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'cantidad_no_recogidos', OLD.cantidad_no_recogidos, NEW.cantidad_no_recogidos
    );
  END IF;

  -- Registrar cambios en `horas_no_operativas`
  IF NOT (OLD.horas_no_operativas <=> NEW.horas_no_operativas) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'horas_no_operativas', OLD.horas_no_operativas, NEW.horas_no_operativas
    );
  END IF;

  -- Registrar eliminación de `cc_aux_1` si se asigna NULL
  IF OLD.cc_aux_1 IS NOT NULL AND NEW.cc_aux_1 IS NULL THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Eliminación', 'operaciones', NEW.operacion_id, 'cc_aux_1', OLD.cc_aux_1, 'NULL'
    );
  END IF;

  -- Registrar eliminación de `cc_aux_2` si se asigna NULL
  IF OLD.cc_aux_2 IS NOT NULL AND NEW.cc_aux_2 IS NULL THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Eliminación', 'operaciones', NEW.operacion_id, 'cc_aux_2', OLD.cc_aux_2, 'NULL'
    );
  END IF;
  
  -- Auditar cantidad_envios
  IF NOT (OLD.cantidad_envios <=> NEW.cantidad_envios) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'operaciones', NEW.operacion_id, 'cantidad_envios', OLD.cantidad_envios, NEW.cantidad_envios
    );
  END IF;

END //

DELIMITER ;



-- ##Trigger INSERT operaciones_avansat##
DROP TRIGGER IF EXISTS trg_operaciones_avansat_insert;

DELIMITER //

CREATE TRIGGER trg_operaciones_avansat_insert
AFTER INSERT ON operaciones_avansat
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');

  INSERT INTO auditoria (
    usuario, evento, tabla_afectada, registro_id, campo_afectado,
    valor_anterior, valor_nuevo
  )
  VALUES (
    v_usuario,
    'Inserción',
    'operaciones_avansat',
    CONCAT(NEW.manifiesto, '|', NEW.fecha_manifiesto, '|', NEW.placa, '|', NEW.remesa),
    'registro_completo',
    NULL,
    'INSERT'
  );
END;
//
DELIMITER ;


-- ##Trigger UPDATE operaciones_avansat##
DROP TRIGGER IF EXISTS trg_operaciones_avansat_update;

DELIMITER //

CREATE TRIGGER trg_operaciones_avansat_update
AFTER UPDATE ON operaciones_avansat
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  DECLARE v_registro_id VARCHAR(255);

  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');
  SET v_registro_id = CONCAT(NEW.manifiesto, '|', NEW.fecha_manifiesto, '|', NEW.placa, '|', NEW.remesa);

  IF (OLD.remolque IS NULL AND NEW.remolque IS NOT NULL) OR (OLD.remolque IS NOT NULL AND NEW.remolque IS NULL) OR (OLD.remolque <> NEW.remolque) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'remolque', OLD.remolque, NEW.remolque);
  END IF;

  IF (OLD.configuracion IS NULL AND NEW.configuracion IS NOT NULL) OR (OLD.configuracion IS NOT NULL AND NEW.configuracion IS NULL) OR (OLD.configuracion <> NEW.configuracion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'configuracion', OLD.configuracion, NEW.configuracion);
  END IF;

  IF (OLD.tipo_vinculacion IS NULL AND NEW.tipo_vinculacion IS NOT NULL) OR (OLD.tipo_vinculacion IS NOT NULL AND NEW.tipo_vinculacion IS NULL) OR (OLD.tipo_vinculacion <> NEW.tipo_vinculacion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tipo_vinculacion', OLD.tipo_vinculacion, NEW.tipo_vinculacion);
  END IF;

  IF (OLD.orden_cargue IS NULL AND NEW.orden_cargue IS NOT NULL) OR (OLD.orden_cargue IS NOT NULL AND NEW.orden_cargue IS NULL) OR (OLD.orden_cargue <> NEW.orden_cargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'orden_cargue', OLD.orden_cargue, NEW.orden_cargue);
  END IF;

  IF (OLD.remision IS NULL AND NEW.remision IS NOT NULL) OR (OLD.remision IS NOT NULL AND NEW.remision IS NULL) OR (OLD.remision <> NEW.remision) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'remision', OLD.remision, NEW.remision);
  END IF;

  IF (OLD.fecha_remesa IS NULL AND NEW.fecha_remesa IS NOT NULL) OR (OLD.fecha_remesa IS NOT NULL AND NEW.fecha_remesa IS NULL) OR (OLD.fecha_remesa <> NEW.fecha_remesa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_remesa', OLD.fecha_remesa, NEW.fecha_remesa);
  END IF;

  IF (OLD.fecha_salida_despacho IS NULL AND NEW.fecha_salida_despacho IS NOT NULL) OR (OLD.fecha_salida_despacho IS NOT NULL AND NEW.fecha_salida_despacho IS NULL) OR (OLD.fecha_salida_despacho <> NEW.fecha_salida_despacho) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_salida_despacho', OLD.fecha_salida_despacho, NEW.fecha_salida_despacho);
  END IF;

  IF (OLD.fecha_llegada_despacho IS NULL AND NEW.fecha_llegada_despacho IS NOT NULL) OR (OLD.fecha_llegada_despacho IS NOT NULL AND NEW.fecha_llegada_despacho IS NULL) OR (OLD.fecha_llegada_despacho <> NEW.fecha_llegada_despacho) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_llegada_despacho', OLD.fecha_llegada_despacho, NEW.fecha_llegada_despacho);
  END IF;

  IF (OLD.cumplida IS NULL AND NEW.cumplida IS NOT NULL) OR (OLD.cumplida IS NOT NULL AND NEW.cumplida IS NULL) OR (OLD.cumplida <> NEW.cumplida) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cumplida', OLD.cumplida, NEW.cumplida);
  END IF;

  IF (OLD.fecha_llegada_cargue IS NULL AND NEW.fecha_llegada_cargue IS NOT NULL) OR (OLD.fecha_llegada_cargue IS NOT NULL AND NEW.fecha_llegada_cargue IS NULL) OR (OLD.fecha_llegada_cargue <> NEW.fecha_llegada_cargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_llegada_cargue', OLD.fecha_llegada_cargue, NEW.fecha_llegada_cargue);
  END IF;

  IF (OLD.fecha_salida_cargue IS NULL AND NEW.fecha_salida_cargue IS NOT NULL) OR (OLD.fecha_salida_cargue IS NOT NULL AND NEW.fecha_salida_cargue IS NULL) OR (OLD.fecha_salida_cargue <> NEW.fecha_salida_cargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_salida_cargue', OLD.fecha_salida_cargue, NEW.fecha_salida_cargue);
  END IF;

  IF (OLD.fecha_llegada_descargue IS NULL AND NEW.fecha_llegada_descargue IS NOT NULL) OR (OLD.fecha_llegada_descargue IS NOT NULL AND NEW.fecha_llegada_descargue IS NULL) OR (OLD.fecha_llegada_descargue <> NEW.fecha_llegada_descargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_llegada_descargue', OLD.fecha_llegada_descargue, NEW.fecha_llegada_descargue);
  END IF;

  IF (OLD.fecha_salida_descargue IS NULL AND NEW.fecha_salida_descargue IS NOT NULL) OR (OLD.fecha_salida_descargue IS NOT NULL AND NEW.fecha_salida_descargue IS NULL) OR (OLD.fecha_salida_descargue <> NEW.fecha_salida_descargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_salida_descargue', OLD.fecha_salida_descargue, NEW.fecha_salida_descargue);
  END IF;

  IF (OLD.factura IS NULL AND NEW.factura IS NOT NULL) OR (OLD.factura IS NOT NULL AND NEW.factura IS NULL) OR (OLD.factura <> NEW.factura) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'factura', OLD.factura, NEW.factura);
  END IF;

  IF (OLD.fecha_factura IS NULL AND NEW.fecha_factura IS NOT NULL) OR (OLD.fecha_factura IS NOT NULL AND NEW.fecha_factura IS NULL) OR (OLD.fecha_factura <> NEW.fecha_factura) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_factura', OLD.fecha_factura, NEW.fecha_factura);
  END IF;

  IF (OLD.fecha_vencimiento IS NULL AND NEW.fecha_vencimiento IS NOT NULL) OR (OLD.fecha_vencimiento IS NOT NULL AND NEW.fecha_vencimiento IS NULL) OR (OLD.fecha_vencimiento <> NEW.fecha_vencimiento) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_vencimiento', OLD.fecha_vencimiento, NEW.fecha_vencimiento);
  END IF;

  IF (OLD.val_inicial_remesa IS NULL AND NEW.val_inicial_remesa IS NOT NULL) OR (OLD.val_inicial_remesa IS NOT NULL AND NEW.val_inicial_remesa IS NULL) OR (OLD.val_inicial_remesa <> NEW.val_inicial_remesa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_inicial_remesa', OLD.val_inicial_remesa, NEW.val_inicial_remesa);
  END IF;

  IF (OLD.val_facturado_separado IS NULL AND NEW.val_facturado_separado IS NOT NULL) OR (OLD.val_facturado_separado IS NOT NULL AND NEW.val_facturado_separado IS NULL) OR (OLD.val_facturado_separado <> NEW.val_facturado_separado) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_facturado_separado', OLD.val_facturado_separado, NEW.val_facturado_separado);
  END IF;

  IF (OLD.val_facturado_remesa IS NULL AND NEW.val_facturado_remesa IS NOT NULL) OR (OLD.val_facturado_remesa IS NOT NULL AND NEW.val_facturado_remesa IS NULL) OR (OLD.val_facturado_remesa <> NEW.val_facturado_remesa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_facturado_remesa', OLD.val_facturado_remesa, NEW.val_facturado_remesa);
  END IF;

  IF (OLD.val_declarado_remesa IS NULL AND NEW.val_declarado_remesa IS NOT NULL) OR (OLD.val_declarado_remesa IS NOT NULL AND NEW.val_declarado_remesa IS NULL) OR (OLD.val_declarado_remesa <> NEW.val_declarado_remesa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_declarado_remesa', OLD.val_declarado_remesa, NEW.val_declarado_remesa);
  END IF;

  IF (OLD.nombre_ser_especial IS NULL AND NEW.nombre_ser_especial IS NOT NULL) OR (OLD.nombre_ser_especial IS NOT NULL AND NEW.nombre_ser_especial IS NULL) OR (OLD.nombre_ser_especial <> NEW.nombre_ser_especial) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nombre_ser_especial', OLD.nombre_ser_especial, NEW.nombre_ser_especial);
  END IF;

  IF (OLD.val_servicios IS NULL AND NEW.val_servicios IS NOT NULL) OR (OLD.val_servicios IS NOT NULL AND NEW.val_servicios IS NULL) OR (OLD.val_servicios <> NEW.val_servicios) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_servicios', OLD.val_servicios, NEW.val_servicios);
  END IF;

  IF (OLD.val_produccion IS NULL AND NEW.val_produccion IS NOT NULL) OR (OLD.val_produccion IS NOT NULL AND NEW.val_produccion IS NULL) OR (OLD.val_produccion <> NEW.val_produccion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'val_produccion', OLD.val_produccion, NEW.val_produccion);
  END IF;

  IF (OLD.cantidad_facturada IS NULL AND NEW.cantidad_facturada IS NOT NULL) OR (OLD.cantidad_facturada IS NOT NULL AND NEW.cantidad_facturada IS NULL) OR (OLD.cantidad_facturada <> NEW.cantidad_facturada) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cantidad_facturada', OLD.cantidad_facturada, NEW.cantidad_facturada);
  END IF;

  IF (OLD.costo_unitario IS NULL AND NEW.costo_unitario IS NOT NULL) OR (OLD.costo_unitario IS NOT NULL AND NEW.costo_unitario IS NULL) OR (OLD.costo_unitario <> NEW.costo_unitario) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'costo_unitario', OLD.costo_unitario, NEW.costo_unitario);
  END IF;

  IF (OLD.retefuente_factura IS NULL AND NEW.retefuente_factura IS NOT NULL) OR (OLD.retefuente_factura IS NOT NULL AND NEW.retefuente_factura IS NULL) OR (OLD.retefuente_factura <> NEW.retefuente_factura) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'retefuente_factura', OLD.retefuente_factura, NEW.retefuente_factura);
  END IF;

  IF (OLD.ica_factura IS NULL AND NEW.ica_factura IS NOT NULL) OR (OLD.ica_factura IS NOT NULL AND NEW.ica_factura IS NULL) OR (OLD.ica_factura <> NEW.ica_factura) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'ica_factura', OLD.ica_factura, NEW.ica_factura);
  END IF;

  IF (OLD.iva_factura IS NULL AND NEW.iva_factura IS NOT NULL) OR (OLD.iva_factura IS NOT NULL AND NEW.iva_factura IS NULL) OR (OLD.iva_factura <> NEW.iva_factura) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'iva_factura', OLD.iva_factura, NEW.iva_factura);
  END IF;

  IF (OLD.facturado_a IS NULL AND NEW.facturado_a IS NOT NULL) OR (OLD.facturado_a IS NOT NULL AND NEW.facturado_a IS NULL) OR (OLD.facturado_a <> NEW.facturado_a) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'facturado_a', OLD.facturado_a, NEW.facturado_a);
  END IF;

  IF (OLD.sede IS NULL AND NEW.sede IS NOT NULL) OR (OLD.sede IS NOT NULL AND NEW.sede IS NULL) OR (OLD.sede <> NEW.sede) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'sede', OLD.sede, NEW.sede);
  END IF;

  IF (OLD.agencia_despacho IS NULL AND NEW.agencia_despacho IS NOT NULL) OR (OLD.agencia_despacho IS NOT NULL AND NEW.agencia_despacho IS NULL) OR (OLD.agencia_despacho <> NEW.agencia_despacho) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'agencia_despacho', OLD.agencia_despacho, NEW.agencia_despacho);
  END IF;

  IF (OLD.remitente IS NULL AND NEW.remitente IS NOT NULL) OR (OLD.remitente IS NOT NULL AND NEW.remitente IS NULL) OR (OLD.remitente <> NEW.remitente) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'remitente', OLD.remitente, NEW.remitente);
  END IF;

  IF (OLD.empaque IS NULL AND NEW.empaque IS NOT NULL) OR (OLD.empaque IS NOT NULL AND NEW.empaque IS NULL) OR (OLD.empaque <> NEW.empaque) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'empaque', OLD.empaque, NEW.empaque);
  END IF;

  IF (OLD.unidad_servicio IS NULL AND NEW.unidad_servicio IS NOT NULL) OR (OLD.unidad_servicio IS NOT NULL AND NEW.unidad_servicio IS NULL) OR (OLD.unidad_servicio <> NEW.unidad_servicio) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'unidad_servicio', OLD.unidad_servicio, NEW.unidad_servicio);
  END IF;

  IF (OLD.tn_pedido IS NULL AND NEW.tn_pedido IS NOT NULL) OR (OLD.tn_pedido IS NOT NULL AND NEW.tn_pedido IS NULL) OR (OLD.tn_pedido <> NEW.tn_pedido) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tn_pedido', OLD.tn_pedido, NEW.tn_pedido);
  END IF;

  IF (OLD.tn_o_cargue IS NULL AND NEW.tn_o_cargue IS NOT NULL) OR (OLD.tn_o_cargue IS NOT NULL AND NEW.tn_o_cargue IS NULL) OR (OLD.tn_o_cargue <> NEW.tn_o_cargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tn_o_cargue', OLD.tn_o_cargue, NEW.tn_o_cargue);
  END IF;

  IF (OLD.tn_remesa IS NULL AND NEW.tn_remesa IS NOT NULL) OR (OLD.tn_remesa IS NOT NULL AND NEW.tn_remesa IS NULL) OR (OLD.tn_remesa <> NEW.tn_remesa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tn_remesa', OLD.tn_remesa, NEW.tn_remesa);
  END IF;

  IF (OLD.tn_cumplido IS NULL AND NEW.tn_cumplido IS NOT NULL) OR (OLD.tn_cumplido IS NOT NULL AND NEW.tn_cumplido IS NULL) OR (OLD.tn_cumplido <> NEW.tn_cumplido) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tn_cumplido', OLD.tn_cumplido, NEW.tn_cumplido);
  END IF;

  IF (OLD.pendiente IS NULL AND NEW.pendiente IS NOT NULL) OR (OLD.pendiente IS NOT NULL AND NEW.pendiente IS NULL) OR (OLD.pendiente <> NEW.pendiente) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'pendiente', OLD.pendiente, NEW.pendiente);
  END IF;

  IF (OLD.cantidad_cumplida IS NULL AND NEW.cantidad_cumplida IS NOT NULL) OR (OLD.cantidad_cumplida IS NOT NULL AND NEW.cantidad_cumplida IS NULL) OR (OLD.cantidad_cumplida <> NEW.cantidad_cumplida) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cantidad_cumplida', OLD.cantidad_cumplida, NEW.cantidad_cumplida);
  END IF;

  IF (OLD.flete_manifiesto IS NULL AND NEW.flete_manifiesto IS NOT NULL) OR (OLD.flete_manifiesto IS NOT NULL AND NEW.flete_manifiesto IS NULL) OR (OLD.flete_manifiesto <> NEW.flete_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'flete_manifiesto', OLD.flete_manifiesto, NEW.flete_manifiesto);
  END IF;

  IF (OLD.retefuente_manifiesto IS NULL AND NEW.retefuente_manifiesto IS NOT NULL) OR (OLD.retefuente_manifiesto IS NOT NULL AND NEW.retefuente_manifiesto IS NULL) OR (OLD.retefuente_manifiesto <> NEW.retefuente_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'retefuente_manifiesto', OLD.retefuente_manifiesto, NEW.retefuente_manifiesto);
  END IF;

  IF (OLD.ica_manifiesto IS NULL AND NEW.ica_manifiesto IS NOT NULL) OR (OLD.ica_manifiesto IS NOT NULL AND NEW.ica_manifiesto IS NULL) OR (OLD.ica_manifiesto <> NEW.ica_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'ica_manifiesto', OLD.ica_manifiesto, NEW.ica_manifiesto);
  END IF;

  IF (OLD.usuario_cumplido_manifiesto IS NULL AND NEW.usuario_cumplido_manifiesto IS NOT NULL) OR (OLD.usuario_cumplido_manifiesto IS NOT NULL AND NEW.usuario_cumplido_manifiesto IS NULL) OR (OLD.usuario_cumplido_manifiesto <> NEW.usuario_cumplido_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'usuario_cumplido_manifiesto', OLD.usuario_cumplido_manifiesto, NEW.usuario_cumplido_manifiesto);
  END IF;

  IF (OLD.fecha_cumplido_manifiesto IS NULL AND NEW.fecha_cumplido_manifiesto IS NOT NULL) OR (OLD.fecha_cumplido_manifiesto IS NOT NULL AND NEW.fecha_cumplido_manifiesto IS NULL) OR (OLD.fecha_cumplido_manifiesto <> NEW.fecha_cumplido_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_cumplido_manifiesto', OLD.fecha_cumplido_manifiesto, NEW.fecha_cumplido_manifiesto);
  END IF;

  IF (OLD.anticipo IS NULL AND NEW.anticipo IS NOT NULL) OR (OLD.anticipo IS NOT NULL AND NEW.anticipo IS NULL) OR (OLD.anticipo <> NEW.anticipo) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'anticipo', OLD.anticipo, NEW.anticipo);
  END IF;

  IF (OLD.nro_anticipos IS NULL AND NEW.nro_anticipos IS NOT NULL) OR (OLD.nro_anticipos IS NOT NULL AND NEW.nro_anticipos IS NULL) OR (OLD.nro_anticipos <> NEW.nro_anticipos) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_anticipos', OLD.nro_anticipos, NEW.nro_anticipos);
  END IF;

  IF (OLD.nro_comprob IS NULL AND NEW.nro_comprob IS NOT NULL) OR (OLD.nro_comprob IS NOT NULL AND NEW.nro_comprob IS NULL) OR (OLD.nro_comprob <> NEW.nro_comprob) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_comprob', OLD.nro_comprob, NEW.nro_comprob);
  END IF;

  IF (OLD.valor_flete_liquidacion IS NULL AND NEW.valor_flete_liquidacion IS NOT NULL) OR (OLD.valor_flete_liquidacion IS NOT NULL AND NEW.valor_flete_liquidacion IS NULL) OR (OLD.valor_flete_liquidacion <> NEW.valor_flete_liquidacion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'valor_flete_liquidacion', OLD.valor_flete_liquidacion, NEW.valor_flete_liquidacion);
  END IF;

  IF (OLD.valor_liquidado IS NULL AND NEW.valor_liquidado IS NOT NULL) OR (OLD.valor_liquidado IS NOT NULL AND NEW.valor_liquidado IS NULL) OR (OLD.valor_liquidado <> NEW.valor_liquidado) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'valor_liquidado', OLD.valor_liquidado, NEW.valor_liquidado);
  END IF;

  IF (OLD.retefuente_liquid IS NULL AND NEW.retefuente_liquid IS NOT NULL) OR (OLD.retefuente_liquid IS NOT NULL AND NEW.retefuente_liquid IS NULL) OR (OLD.retefuente_liquid <> NEW.retefuente_liquid) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'retefuente_liquid', OLD.retefuente_liquid, NEW.retefuente_liquid);
  END IF;

  IF (OLD.ica_liquid IS NULL AND NEW.ica_liquid IS NOT NULL) OR (OLD.ica_liquid IS NOT NULL AND NEW.ica_liquid IS NULL) OR (OLD.ica_liquid <> NEW.ica_liquid) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'ica_liquid', OLD.ica_liquid, NEW.ica_liquid);
  END IF;

  IF (OLD.cree_liquid IS NULL AND NEW.cree_liquid IS NOT NULL) OR (OLD.cree_liquid IS NOT NULL AND NEW.cree_liquid IS NULL) OR (OLD.cree_liquid <> NEW.cree_liquid) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cree_liquid', OLD.cree_liquid, NEW.cree_liquid);
  END IF;

  IF (OLD.fecha_liquid IS NULL AND NEW.fecha_liquid IS NOT NULL) OR (OLD.fecha_liquid IS NOT NULL AND NEW.fecha_liquid IS NULL) OR (OLD.fecha_liquid <> NEW.fecha_liquid) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_liquid', OLD.fecha_liquid, NEW.fecha_liquid);
  END IF;

  IF (OLD.nro_comprob1 IS NULL AND NEW.nro_comprob1 IS NOT NULL) OR (OLD.nro_comprob1 IS NOT NULL AND NEW.nro_comprob1 IS NULL) OR (OLD.nro_comprob1 <> NEW.nro_comprob1) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_comprob1', OLD.nro_comprob1, NEW.nro_comprob1);
  END IF;

  IF (OLD.faltantes_liquidacion IS NULL AND NEW.faltantes_liquidacion IS NOT NULL) OR (OLD.faltantes_liquidacion IS NOT NULL AND NEW.faltantes_liquidacion IS NULL) OR (OLD.faltantes_liquidacion <> NEW.faltantes_liquidacion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'faltantes_liquidacion', OLD.faltantes_liquidacion, NEW.faltantes_liquidacion);
  END IF;

  IF (OLD.valor_descontar IS NULL AND NEW.valor_descontar IS NOT NULL) OR (OLD.valor_descontar IS NOT NULL AND NEW.valor_descontar IS NULL) OR (OLD.valor_descontar <> NEW.valor_descontar) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'valor_descontar', OLD.valor_descontar, NEW.valor_descontar);
  END IF;

  IF (OLD.servicio_integral IS NULL AND NEW.servicio_integral IS NOT NULL) OR (OLD.servicio_integral IS NOT NULL AND NEW.servicio_integral IS NULL) OR (OLD.servicio_integral <> NEW.servicio_integral) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'servicio_integral', OLD.servicio_integral, NEW.servicio_integral);
  END IF;

  IF (OLD.nombre_ser_especial2 IS NULL AND NEW.nombre_ser_especial2 IS NOT NULL) OR (OLD.nombre_ser_especial2 IS NOT NULL AND NEW.nombre_ser_especial2 IS NULL) OR (OLD.nombre_ser_especial2 <> NEW.nombre_ser_especial2) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nombre_ser_especial2', OLD.nombre_ser_especial2, NEW.nombre_ser_especial2);
  END IF;

  IF (OLD.ser_especial_manifiesto IS NULL AND NEW.ser_especial_manifiesto IS NOT NULL) OR (OLD.ser_especial_manifiesto IS NOT NULL AND NEW.ser_especial_manifiesto IS NULL) OR (OLD.ser_especial_manifiesto <> NEW.ser_especial_manifiesto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'ser_especial_manifiesto', OLD.ser_especial_manifiesto, NEW.ser_especial_manifiesto);
  END IF;

  IF (OLD.valor_pagado IS NULL AND NEW.valor_pagado IS NOT NULL) OR (OLD.valor_pagado IS NOT NULL AND NEW.valor_pagado IS NULL) OR (OLD.valor_pagado <> NEW.valor_pagado) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'valor_pagado', OLD.valor_pagado, NEW.valor_pagado);
  END IF;

  IF (OLD.fecha_pago IS NULL AND NEW.fecha_pago IS NOT NULL) OR (OLD.fecha_pago IS NOT NULL AND NEW.fecha_pago IS NULL) OR (OLD.fecha_pago <> NEW.fecha_pago) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_pago', OLD.fecha_pago, NEW.fecha_pago);
  END IF;

  IF (OLD.nro_comprob2 IS NULL AND NEW.nro_comprob2 IS NOT NULL) OR (OLD.nro_comprob2 IS NOT NULL AND NEW.nro_comprob2 IS NULL) OR (OLD.nro_comprob2 <> NEW.nro_comprob2) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_comprob2', OLD.nro_comprob2, NEW.nro_comprob2);
  END IF;

  IF (OLD.banco IS NULL AND NEW.banco IS NOT NULL) OR (OLD.banco IS NOT NULL AND NEW.banco IS NULL) OR (OLD.banco <> NEW.banco) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'banco', OLD.banco, NEW.banco);
  END IF;

  IF (OLD.cuenta_bancaria IS NULL AND NEW.cuenta_bancaria IS NOT NULL) OR (OLD.cuenta_bancaria IS NOT NULL AND NEW.cuenta_bancaria IS NULL) OR (OLD.cuenta_bancaria <> NEW.cuenta_bancaria) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cuenta_bancaria', OLD.cuenta_bancaria, NEW.cuenta_bancaria);
  END IF;

  IF (OLD.nro_cheque IS NULL AND NEW.nro_cheque IS NOT NULL) OR (OLD.nro_cheque IS NOT NULL AND NEW.nro_cheque IS NULL) OR (OLD.nro_cheque <> NEW.nro_cheque) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_cheque', OLD.nro_cheque, NEW.nro_cheque);
  END IF;

  IF (OLD.tipo_pago IS NULL AND NEW.tipo_pago IS NOT NULL) OR (OLD.tipo_pago IS NOT NULL AND NEW.tipo_pago IS NULL) OR (OLD.tipo_pago <> NEW.tipo_pago) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'tipo_pago', OLD.tipo_pago, NEW.tipo_pago);
  END IF;

  IF (OLD.origen IS NULL AND NEW.origen IS NOT NULL) OR (OLD.origen IS NOT NULL AND NEW.origen IS NULL) OR (OLD.origen <> NEW.origen) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'origen', OLD.origen, NEW.origen);
  END IF;

  IF (OLD.destino IS NULL AND NEW.destino IS NOT NULL) OR (OLD.destino IS NOT NULL AND NEW.destino IS NULL) OR (OLD.destino <> NEW.destino) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'destino', OLD.destino, NEW.destino);
  END IF;

  IF (OLD.producto IS NULL AND NEW.producto IS NOT NULL) OR (OLD.producto IS NOT NULL AND NEW.producto IS NULL) OR (OLD.producto <> NEW.producto) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'producto', OLD.producto, NEW.producto);
  END IF;

  IF (OLD.conductor IS NULL AND NEW.conductor IS NOT NULL) OR (OLD.conductor IS NOT NULL AND NEW.conductor IS NULL) OR (OLD.conductor <> NEW.conductor) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'conductor', OLD.conductor, NEW.conductor);
  END IF;

  IF (OLD.cc_conductor IS NULL AND NEW.cc_conductor IS NOT NULL) OR (OLD.cc_conductor IS NOT NULL AND NEW.cc_conductor IS NULL) OR (OLD.cc_conductor <> NEW.cc_conductor) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cc_conductor', OLD.cc_conductor, NEW.cc_conductor);
  END IF;

  IF (OLD.celular IS NULL AND NEW.celular IS NOT NULL) OR (OLD.celular IS NOT NULL AND NEW.celular IS NULL) OR (OLD.celular <> NEW.celular) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'celular', OLD.celular, NEW.celular);
  END IF;

  IF (OLD.poseedor IS NULL AND NEW.poseedor IS NOT NULL) OR (OLD.poseedor IS NOT NULL AND NEW.poseedor IS NULL) OR (OLD.poseedor <> NEW.poseedor) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'poseedor', OLD.poseedor, NEW.poseedor);
  END IF;

  IF (OLD.cc_nit_poseedor IS NULL AND NEW.cc_nit_poseedor IS NOT NULL) OR (OLD.cc_nit_poseedor IS NOT NULL AND NEW.cc_nit_poseedor IS NULL) OR (OLD.cc_nit_poseedor <> NEW.cc_nit_poseedor) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'cc_nit_poseedor', OLD.cc_nit_poseedor, NEW.cc_nit_poseedor);
  END IF;

  IF (OLD.nro_pedido IS NULL AND NEW.nro_pedido IS NOT NULL) OR (OLD.nro_pedido IS NOT NULL AND NEW.nro_pedido IS NULL) OR (OLD.nro_pedido <> NEW.nro_pedido) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_pedido', OLD.nro_pedido, NEW.nro_pedido);
  END IF;

  IF (OLD.observacion_llegada IS NULL AND NEW.observacion_llegada IS NOT NULL) OR (OLD.observacion_llegada IS NOT NULL AND NEW.observacion_llegada IS NULL) OR (OLD.observacion_llegada <> NEW.observacion_llegada) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'observacion_llegada', OLD.observacion_llegada, NEW.observacion_llegada);
  END IF;

  IF (OLD.vlr_tarifa_cotizacion_cliente IS NULL AND NEW.vlr_tarifa_cotizacion_cliente IS NOT NULL) OR (OLD.vlr_tarifa_cotizacion_cliente IS NOT NULL AND NEW.vlr_tarifa_cotizacion_cliente IS NULL) OR (OLD.vlr_tarifa_cotizacion_cliente <> NEW.vlr_tarifa_cotizacion_cliente) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'vlr_tarifa_cotizacion_cliente', OLD.vlr_tarifa_cotizacion_cliente, NEW.vlr_tarifa_cotizacion_cliente);
  END IF;

  IF (OLD.descripcion_tarifa IS NULL AND NEW.descripcion_tarifa IS NOT NULL) OR (OLD.descripcion_tarifa IS NOT NULL AND NEW.descripcion_tarifa IS NULL) OR (OLD.descripcion_tarifa <> NEW.descripcion_tarifa) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'descripcion_tarifa', OLD.descripcion_tarifa, NEW.descripcion_tarifa);
  END IF;

  IF (OLD.fecha_recaudo IS NULL AND NEW.fecha_recaudo IS NOT NULL) OR (OLD.fecha_recaudo IS NOT NULL AND NEW.fecha_recaudo IS NULL) OR (OLD.fecha_recaudo <> NEW.fecha_recaudo) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_recaudo', OLD.fecha_recaudo, NEW.fecha_recaudo);
  END IF;

  IF (OLD.nro_comprobante_recaudo IS NULL AND NEW.nro_comprobante_recaudo IS NOT NULL) OR (OLD.nro_comprobante_recaudo IS NOT NULL AND NEW.nro_comprobante_recaudo IS NULL) OR (OLD.nro_comprobante_recaudo <> NEW.nro_comprobante_recaudo) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'nro_comprobante_recaudo', OLD.nro_comprobante_recaudo, NEW.nro_comprobante_recaudo);
  END IF;

  IF (OLD.creado_por IS NULL AND NEW.creado_por IS NOT NULL) OR (OLD.creado_por IS NOT NULL AND NEW.creado_por IS NULL) OR (OLD.creado_por <> NEW.creado_por) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'creado_por', OLD.creado_por, NEW.creado_por);
  END IF;

  IF (OLD.estado IS NULL AND NEW.estado IS NOT NULL) OR (OLD.estado IS NOT NULL AND NEW.estado IS NULL) OR (OLD.estado <> NEW.estado) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'estado', OLD.estado, NEW.estado);
  END IF;

  IF (OLD.documento_destinatario IS NULL AND NEW.documento_destinatario IS NOT NULL) OR (OLD.documento_destinatario IS NOT NULL AND NEW.documento_destinatario IS NULL) OR (OLD.documento_destinatario <> NEW.documento_destinatario) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'documento_destinatario', OLD.documento_destinatario, NEW.documento_destinatario);
  END IF;

  IF (OLD.destinatario IS NULL AND NEW.destinatario IS NOT NULL) OR (OLD.destinatario IS NOT NULL AND NEW.destinatario IS NULL) OR (OLD.destinatario <> NEW.destinatario) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'destinatario', OLD.destinatario, NEW.destinatario);
  END IF;

  IF (OLD.costo_produccion IS NULL AND NEW.costo_produccion IS NOT NULL) OR (OLD.costo_produccion IS NOT NULL AND NEW.costo_produccion IS NULL) OR (OLD.costo_produccion <> NEW.costo_produccion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'costo_produccion', OLD.costo_produccion, NEW.costo_produccion);
  END IF;

  IF (OLD.prorrateo_costo_estimado_propio IS NULL AND NEW.prorrateo_costo_estimado_propio IS NOT NULL) OR (OLD.prorrateo_costo_estimado_propio IS NOT NULL AND NEW.prorrateo_costo_estimado_propio IS NULL) OR (OLD.prorrateo_costo_estimado_propio <> NEW.prorrateo_costo_estimado_propio) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'prorrateo_costo_estimado_propio', OLD.prorrateo_costo_estimado_propio, NEW.prorrateo_costo_estimado_propio);
  END IF;

  IF (OLD.prorrateo_costo_estimado_tercero IS NULL AND NEW.prorrateo_costo_estimado_tercero IS NOT NULL) OR (OLD.prorrateo_costo_estimado_tercero IS NOT NULL AND NEW.prorrateo_costo_estimado_tercero IS NULL) OR (OLD.prorrateo_costo_estimado_tercero <> NEW.prorrateo_costo_estimado_tercero) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'prorrateo_costo_estimado_tercero', OLD.prorrateo_costo_estimado_tercero, NEW.prorrateo_costo_estimado_tercero);
  END IF;

  IF (OLD.prorrateo_utilidad_estimada IS NULL AND NEW.prorrateo_utilidad_estimada IS NOT NULL) OR (OLD.prorrateo_utilidad_estimada IS NOT NULL AND NEW.prorrateo_utilidad_estimada IS NULL) OR (OLD.prorrateo_utilidad_estimada <> NEW.prorrateo_utilidad_estimada) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'prorrateo_utilidad_estimada', OLD.prorrateo_utilidad_estimada, NEW.prorrateo_utilidad_estimada);
  END IF;

  IF (OLD.fecha_hora_entrada_cargue IS NULL AND NEW.fecha_hora_entrada_cargue IS NOT NULL) OR (OLD.fecha_hora_entrada_cargue IS NOT NULL AND NEW.fecha_hora_entrada_cargue IS NULL) OR (OLD.fecha_hora_entrada_cargue <> NEW.fecha_hora_entrada_cargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_hora_entrada_cargue', OLD.fecha_hora_entrada_cargue, NEW.fecha_hora_entrada_cargue);
  END IF;

  IF (OLD.fecha_hora_entrada_descargue IS NULL AND NEW.fecha_hora_entrada_descargue IS NOT NULL) OR (OLD.fecha_hora_entrada_descargue IS NOT NULL AND NEW.fecha_hora_entrada_descargue IS NULL) OR (OLD.fecha_hora_entrada_descargue <> NEW.fecha_hora_entrada_descargue) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'operaciones_avansat', v_registro_id, 'fecha_hora_entrada_descargue', OLD.fecha_hora_entrada_descargue, NEW.fecha_hora_entrada_descargue);
  END IF;

END;//
DELIMITER ;



-- #### Trigger para insercion de datos en vehiculos_propios #########


-- Elimina el trigger si ya existe para poder crearlo de nuevo
DROP TRIGGER IF EXISTS trg_vehiculos_propios_after_insert;

DELIMITER //

CREATE TRIGGER trg_vehiculos_propios_after_insert
AFTER INSERT ON vehiculos_propios
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');

    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    )
    VALUES (
        v_usuario,
        'Inserción',
        'vehiculos_propios',
        NEW.id_vehiculo,
        'Todos',
        NULL,
        CONCAT(
            'Placa: ', NEW.placa,
            ', Id Tipología: ', NEW.id_tipologia,
            ', Marca: ', NEW.marca,
            ', Modelo: ', NEW.modelo,
            ', Kilometraje: ', IFNULL(NEW.kilometraje, 'NULL'),
            ', Fecha Últ. Mantenimiento: ', IFNULL(DATE_FORMAT(NEW.fecha_ult_med, '%Y-%m-%d %H:%i:%s'), 'NULL'),
            ', Año: ', NEW.anio,
            ', Tipo Combustible: ', IFNULL(NEW.tipo_combustible, 'NULL'),
            ', Max KM Diario: ', IFNULL(NEW.max_km_diario, 'NULL'),
            ', Prom KM Diario: ', IFNULL(NEW.prom_km_diario, 'NULL'),
            ', ID Base: ', IFNULL(NEW.id_base, 'NULL'),
            ', Centro Costo: ', IFNULL(NEW.centro_costo, 'NULL'),
            ', VIN: ', IFNULL(NEW.vin, 'NULL'),
            ', Propietario: ', IFNULL(NEW.propietario, 'NULL'),
            ', Motor: ', IFNULL(NEW.motor, 'NULL'),
            ', Capacidad: ', IFNULL(NEW.capacidad, 'NULL'),
            ', Núm. Chasis: ', IFNULL(NEW.num_chasis, 'NULL'),
            ', Núm. Serial: ', IFNULL(NEW.num_serial, 'NULL'),
            ', Fecha Compra: ', IFNULL(DATE_FORMAT(NEW.fecha_compra, '%Y-%m-%d'), 'NULL'),
            ', Costo: ', IFNULL(NEW.costo, 'NULL'),
            ', Fecha Creación: ', IFNULL(DATE_FORMAT(NEW.fecha_creacion, '%Y-%m-%d %H:%i:%s'), 'NULL'),
            ', Creado por: ', IFNULL(NEW.creado_por, 'NULL')
        )
    );
END //

DELIMITER ;


-- ######### Tirgger para actualizacion de registros en la tabla vehiclos_propios


-- Elimina el trigger si ya existe para poder crearlo de nuevo
DROP TRIGGER IF EXISTS trg_vehiculos_propios_after_update;

DELIMITER //

CREATE TRIGGER trg_vehiculos_propios_after_update
AFTER UPDATE ON vehiculos_propios
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el usuario
    DECLARE v_usuario VARCHAR(100);
    -- Asigna el valor de la variable de sesión @usuario_actual, o 'Desconocido' si es NULL
    SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');

    -- Placa
    IF NOT (OLD.placa <=> NEW.placa) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'placa', OLD.placa, NEW.placa);
    END IF;

    -- id_tipologia
    IF NOT (OLD.id_tipologia <=> NEW.id_tipologia) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_tipologia, 'id_tipologia', OLD.id_tipologia, NEW.id_tipologia);
    END IF;

    -- marca
    IF NOT (OLD.marca <=> NEW.marca) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'marca', OLD.marca, NEW.marca);
    END IF;

    -- modelo
    IF NOT (OLD.modelo <=> NEW.modelo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'modelo', OLD.modelo, NEW.modelo);
    END IF;

    -- kilometraje
    IF NOT (OLD.kilometraje <=> NEW.kilometraje) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'kilometraje', OLD.kilometraje, NEW.kilometraje);
    END IF;

    -- fecha_ult_med
    IF NOT (OLD.fecha_ult_med <=> NEW.fecha_ult_med) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'fecha_ult_med', OLD.fecha_ult_med, NEW.fecha_ult_med);
    END IF;

    -- anio
    IF NOT (OLD.anio <=> NEW.anio) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'anio', OLD.anio, NEW.anio);
    END IF;

    -- tipo_combustible
    IF NOT (OLD.tipo_combustible <=> NEW.tipo_combustible) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'tipo_combustible', OLD.tipo_combustible, NEW.tipo_combustible);
    END IF;

    -- max_km_diario
    IF NOT (OLD.max_km_diario <=> NEW.max_km_diario) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'max_km_diario', OLD.max_km_diario, NEW.max_km_diario);
    END IF;

    -- prom_km_diario
    IF NOT (OLD.prom_km_diario <=> NEW.prom_km_diario) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'prom_km_diario', OLD.prom_km_diario, NEW.prom_km_diario);
    END IF;

    -- id_base
    IF NOT (OLD.id_base <=> NEW.id_base) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'id_base', OLD.id_base, NEW.id_base);
    END IF;

    -- centro_costo
    IF NOT (OLD.centro_costo <=> NEW.centro_costo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'centro_costo', OLD.centro_costo, NEW.centro_costo);
    END IF;

    -- vin
    IF NOT (OLD.vin <=> NEW.vin) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'vin', OLD.vin, NEW.vin);
    END IF;

    -- propietario
    IF NOT (OLD.propietario <=> NEW.propietario) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'propietario', OLD.propietario, NEW.propietario);
    END IF;

    -- motor
    IF NOT (OLD.motor <=> NEW.motor) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'motor', OLD.motor, NEW.motor);
    END IF;

    -- capacidad
    IF NOT (OLD.capacidad <=> NEW.capacidad) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'capacidad', OLD.capacidad, NEW.capacidad);
    END IF;

    -- num_chasis
    IF NOT (OLD.num_chasis <=> NEW.num_chasis) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'num_chasis', OLD.num_chasis, NEW.num_chasis);
    END IF;

    -- num_serial
    IF NOT (OLD.num_serial <=> NEW.num_serial) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'num_serial', OLD.num_serial, NEW.num_serial);
    END IF;

    -- fecha_compra
    IF NOT (OLD.fecha_compra <=> NEW.fecha_compra) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'fecha_compra', OLD.fecha_compra, NEW.fecha_compra);
    END IF;

    -- costo
    IF NOT (OLD.costo <=> NEW.costo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'costo', OLD.costo, NEW.costo);
    END IF;

    -- fecha_creacion
    IF NOT (OLD.fecha_creacion <=> NEW.fecha_creacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'fecha_creacion', OLD.fecha_creacion, NEW.fecha_creacion);
    END IF;

    -- creado_por
    IF NOT (OLD.creado_por <=> NEW.creado_por) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'vehiculos_propios', NEW.id_vehiculo, 'creado_por', OLD.creado_por, NEW.creado_por);
    END IF;

END //

DELIMITER ;



-- Trigger para generar el Lote cuando se ingrese dotación de empleados al inventario

DROP TRIGGER IF EXISTS trg_before_insert_inventario_dotacion;

DELIMITER //

CREATE TRIGGER trg_before_insert_inventario_dotacion
BEFORE INSERT ON inventario_dotacion
FOR EACH ROW
BEGIN
    DECLARE letra_tipo CHAR(2);
    DECLARE fecha_hora_lote VARCHAR(14); -- formato: yymmddHHMMSS

    -- Determinar letra según tipo
    SET letra_tipo = CASE NEW.tipo
        WHEN 'Camisa' THEN 'CA'
        WHEN 'Pantalón' THEN 'PA'
        WHEN 'Botas' THEN 'BO'
        WHEN 'Buso' THEN 'BU'
        WHEN 'Camiseta' THEN 'CM'
        ELSE 'X' -- en caso de un tipo inválido, opcional
    END;

    -- Generar fecha y hora actual en formato yymmddHHMMSS
    SET fecha_hora_lote = DATE_FORMAT(NOW(), '%y%m%d%H%i%s');

    -- Concatenar y asignar al campo lote
    SET NEW.lote = CONCAT('L', letra_tipo, fecha_hora_lote);
END //

DELIMITER ;


-- Trigger para insercion y/o actualizacion de datos en tabla bitacora_operacion_trafico

DELIMITER //

-- Elimina triggers previos si existen

DROP TRIGGER IF EXISTS trg_audit_update_bitacora;

-- Trigger de auditoría para INSERT

DELIMITER //

CREATE TRIGGER trg_audit_insert_bitacora
AFTER INSERT ON bitacora_operacion_trafico
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (
    usuario,
    evento,
    tabla_afectada,
    registro_id
  ) VALUES (
    COALESCE(@usuario_actual,'UNKNOWN'),
    'Inserción',
    'bitacora_operacion_trafico',
    CAST(NEW.entrada_id AS CHAR)
  );
END//

DELIMITER ;

-- Trigger de auditoría para UPDATE  OJO HAY ALGO QUIE NO FUNCIONA PARA CREAR ESTE TRIGGER

DELIMITER //

CREATE TRIGGER trg_audit_update_bitacora
AFTER UPDATE ON bitacora_operacion_trafico
FOR EACH ROW
BEGIN
  IF NOT (OLD.fecha <=> NEW.fecha) THEN
    INSERT INTO auditoria(
      usuario, evento, tabla_afectada, registro_id,
      campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      COALESCE(@usuario_actual,'UNKNOWN'),
      'Actualización',
      'bitacora_operacion_trafico',
      CAST(OLD.entrada_id AS CHAR),
      'fecha',
      CAST(OLD.fecha   AS CHAR),
      CAST(NEW.fecha   AS CHAR)
    );
  END IF;

  IF NOT (OLD.turno <=> NEW.turno) THEN
    INSERT INTO auditoria(
      usuario, evento, tabla_afectada, registro_id,
      campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      COALESCE(@usuario_actual,'UNKNOWN'),
      'Actualización',
      'bitacora_operacion_trafico',
      CAST(OLD.entrada_id AS CHAR),
      'turno',
      OLD.turno,
      NEW.turno
    );
  END IF;

  IF NOT (OLD.controlador_entrega <=> NEW.controlador_entrega) THEN
    INSERT INTO auditoria(
      usuario, evento, tabla_afectada, registro_id,
      campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      COALESCE(@usuario_actual,'UNKNOWN'),
      'Actualización',
      'bitacora_operacion_trafico',
      CAST(OLD.entrada_id AS CHAR),
      'controlador_entrega',
      CAST(OLD.controlador_entrega AS CHAR),
      CAST(NEW.controlador_entrega AS CHAR)
    );
  END IF;

  IF NOT (OLD.controlador_recibe <=> NEW.controlador_recibe) THEN
    INSERT INTO auditoria(
      usuario, evento, tabla_afectada, registro_id,
      campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      COALESCE(@usuario_actual,'UNKNOWN'),
      'Actualización',
      'bitacora_operacion_trafico',
      CAST(OLD.entrada_id AS CHAR),
      'controlador_recibe',
      CAST(OLD.controlador_recibe AS CHAR),
      CAST(NEW.controlador_recibe AS CHAR)
    );
  END IF;

  IF NOT (OLD.observaciones <=> NEW.observaciones) THEN
    INSERT INTO auditoria(
      usuario, evento, tabla_afectada, registro_id,
      campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      COALESCE(@usuario_actual,'UNKNOWN'),
      'Actualización',
      'bitacora_operacion_trafico',
      CAST(OLD.entrada_id AS CHAR),
      'observaciones',
      OLD.observaciones,
      NEW.observaciones
    );
  END IF;
END//

DELIMITER ;


-- Trigger de INSERT en trafico_avansat:

DROP TRIGGER IF EXISTS trg_insert_trafico_avansat;

DELIMITER //
CREATE TRIGGER trg_insert_trafico_avansat
AFTER INSERT ON trafico_avansat
FOR EACH ROW
BEGIN
    /* 1. Intenta usar la variable de sesión que el SP insertó */
    /* 2. Si no existe, usa CURRENT_USER()                     */
    /* 3. Fallback final: 'sistema'                            */
    DECLARE v_usuario VARCHAR(100);

    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    INSERT INTO auditoria
        (usuario, evento, tabla_afectada, registro_id,
         campo_afectado, valor_anterior, valor_nuevo)
    VALUES
        (v_usuario,
         'Inserción',
         'trafico_avansat',
         NEW.detalle_id,
         NULL, NULL, NULL);
END//
DELIMITER ;





-- Trigger de UPDATE en trafico_avansat:

DROP TRIGGER IF EXISTS trg_update_trafico_avansat;

DELIMITER //

CREATE TRIGGER trg_update_trafico_avansat
AFTER UPDATE ON trafico_avansat
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);

    -- Extraer usuario de sesión
    SET v_usuario = SUBSTRING_INDEX(USER(), '@', 1);

    INSERT INTO auditoria (
        usuario,
        accion,
        tabla_afectada,
        fecha_hora,
        descripcion
    ) VALUES (
        v_usuario,
        'UPDATE',
        'trafico_avansat',
        NOW(),
        CONCAT(
            'Se actualizó detalle_id=', NEW.detalle_id,
            '. Antes: entrada_id=', OLD.entrada_id,
            ', cliente=', IFNULL(OLD.cliente, 'NULL'),
            ', cant_vehiculos=', IFNULL(OLD.cant_vehiculos, 'NULL'),
            '. Después: entrada_id=', NEW.entrada_id,
            ', cliente=', IFNULL(NEW.cliente, 'NULL'),
            ', cant_vehiculos=', IFNULL(NEW.cant_vehiculos, 'NULL')
        )
    );
END//

DELIMITER ;


-- Trigger de INSERT en no_planillados_avansat:

DROP TRIGGER IF EXISTS trg_insert_no_planillados_avansat;
DELIMITER //
CREATE TRIGGER trg_insert_no_planillados_avansat
AFTER INSERT ON no_planillados_avansat
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el nombre del usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Asigna el usuario. Prioriza la variable de sesión @usuario_actual,
    -- luego el usuario de la conexión de MySQL, y finalmente 'sistema' como último recurso.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Inserta el registro de auditoría para el nuevo registro.
    INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id,
        campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
        v_usuario,
        'Inserción',
        'no_planillados_avansat',
        NEW.no_planillado_id, -- Usa la PK del nuevo registro.
        NULL, NULL, NULL -- No hay valores anteriores en una inserción.
    );
END //
DELIMITER ;

-- Trigger de UPDATE en no_planillados_avansat:

DROP TRIGGER IF EXISTS trg_update_no_planillados_avansat;
DELIMITER //
CREATE TRIGGER trg_update_no_planillados_avansat
AFTER UPDATE ON no_planillados_avansat
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el nombre del usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Asigna el usuario usando la misma lógica de prioridades.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Comprueba si el campo 'placa' ha cambiado.
    -- El operador <=> maneja correctamente los valores NULL.
    IF NOT (OLD.placa <=> NEW.placa) THEN
        INSERT INTO auditoria (
            usuario, evento, tabla_afectada, registro_id,
            campo_afectado, valor_anterior, valor_nuevo
        ) VALUES (
            v_usuario,
            'Actualización',
            'no_planillados_avansat',
            NEW.no_planillado_id, -- Usa la PK del registro actualizado.
            'placa', 
            OLD.placa, 
            NEW.placa
        );
    END IF;

    -- Comprueba si el campo 'detalle' ha cambiado.
    IF NOT (OLD.detalle <=> NEW.detalle) THEN
        INSERT INTO auditoria (
            usuario, evento, tabla_afectada, registro_id,
            campo_afectado, valor_anterior, valor_nuevo
        ) VALUES (
            v_usuario,
            'Actualización',
            'no_planillados_avansat',
            NEW.no_planillado_id,
            'detalle', 
            OLD.detalle, 
            NEW.detalle
        );
    END IF;
    
    -- Puedes añadir más bloques IF para auditar otros campos como 'entrada_id' si es necesario.

END //
DELIMITER ;


-- Tirgger INSERT tabla escoltas
-- Elimina el trigger si ya existe para evitar errores.
DROP TRIGGER IF EXISTS trg_insert_escoltas;

-- Cambia el delimitador para definir el cuerpo del trigger.
DELIMITER //

CREATE TRIGGER trg_insert_escoltas
AFTER INSERT ON escoltas
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el nombre del usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Obtiene el usuario de la sesión, con CURRENT_USER() y 'sistema' como respaldo.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Inserta el registro de auditoría correspondiente a la nueva fila.
    INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id,
        campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
        v_usuario,
        'Inserción',
        'escoltas',
        NEW.novedad_escolta_id, -- Clave primaria del nuevo registro.
        NULL, NULL, NULL      -- No hay valores previos en una inserción.
    );
END //

-- Restablece el delimitador estándar.
DELIMITER ;



-- Tirgger UPDATE tabla escoltas
-- Elimina el trigger si ya existe.
DROP TRIGGER IF EXISTS trg_update_escoltas;

-- Cambia el delimitador.
DELIMITER //

CREATE TRIGGER trg_update_escoltas
AFTER UPDATE ON escoltas
FOR EACH ROW
BEGIN
    -- Declara la variable para el usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Asigna el usuario de la sesión.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Compara el valor antiguo y nuevo del campo 'detalle'.
    -- El operador <=> maneja correctamente los valores NULL.
    IF NOT (OLD.detalle <=> NEW.detalle) THEN
        INSERT INTO auditoria (
            usuario, evento, tabla_afectada, registro_id,
            campo_afectado, valor_anterior, valor_nuevo
        ) VALUES (
            v_usuario,
            'Actualización',
            'escoltas',
            NEW.novedad_escolta_id, -- Clave primaria del registro modificado.
            'detalle',             -- Nombre del campo que cambió.
            OLD.detalle,           -- Valor antes del cambio.
            NEW.detalle            -- Valor después del cambio.
        );
    END IF;

    -- Puedes añadir más bloques IF aquí para auditar otros campos si los agregas en el futuro.

END //

-- Restablece el delimitador.
DELIMITER ;


-- Trigger tabla botones_panico INSEERT
-- Elimina el trigger si ya existe para evitar errores.
DROP TRIGGER IF EXISTS trg_insert_boton_panico;

-- Cambia el delimitador para definir el cuerpo del trigger.
DELIMITER //

CREATE TRIGGER trg_insert_boton_panico
AFTER INSERT ON botones_panico
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el nombre del usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Obtiene el usuario de la sesión, con CURRENT_USER() y 'sistema' como respaldo.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Inserta el registro de auditoría para la nueva fila.
    INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id,
        campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
        v_usuario,
        'Inserción',
        'botones_panico',
        NEW.id_prueba, -- Clave primaria del nuevo registro.
        NULL, NULL, NULL -- No hay valores previos en una inserción.
    );
END //

-- Restablece el delimitador estándar.
DELIMITER ;


-- Trigger tabla botones_panico UPDATE
-- Elimina el trigger si ya existe.
DROP TRIGGER IF EXISTS trg_update_boton_panico;

-- Cambia el delimitador.
DELIMITER //

CREATE TRIGGER trg_update_boton_panico
AFTER UPDATE ON botones_panico
FOR EACH ROW
BEGIN
    -- Declara la variable para el usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Asigna el usuario de la sesión.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Compara cada campo para registrar los cambios. El operador <=> maneja correctamente los NULL.
    IF NOT (OLD.fecha <=> NEW.fecha) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'fecha', OLD.fecha, NEW.fecha);
    END IF;

    IF NOT (OLD.hora_solicitud_activacion <=> NEW.hora_solicitud_activacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'hora_solicitud_activacion', OLD.hora_solicitud_activacion, NEW.hora_solicitud_activacion);
    END IF;

    IF NOT (OLD.tiempo_respuesta <=> NEW.tiempo_respuesta) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'tiempo_respuesta', OLD.tiempo_respuesta, NEW.tiempo_respuesta);
    END IF;
    
    IF NOT (OLD.placa_vehiculo <=> NEW.placa_vehiculo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'placa_vehiculo', OLD.placa_vehiculo, NEW.placa_vehiculo);
    END IF;

    IF NOT (OLD.empresa_satelital <=> NEW.empresa_satelital) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'empresa_satelital', OLD.empresa_satelital, NEW.empresa_satelital);
    END IF;
    
    IF NOT (OLD.tipo_flota <=> NEW.tipo_flota) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'tipo_flota', OLD.tipo_flota, NEW.tipo_flota);
    END IF;
    
    IF NOT (OLD.ubicaciones_vehiculo <=> NEW.ubicaciones_vehiculo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'ubicaciones_vehiculo', OLD.ubicaciones_vehiculo, NEW.ubicaciones_vehiculo);
    END IF;
    
    IF NOT (OLD.novedades <=> NEW.novedades) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'novedades', OLD.novedades, NEW.novedades);
    END IF;
    
    IF NOT (OLD.observaciones <=> NEW.observaciones) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'observaciones', OLD.observaciones, NEW.observaciones);
    END IF;
    
    IF NOT (OLD.gestion <=> NEW.gestion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'gestion', OLD.gestion, NEW.gestion);
    END IF;
    
    IF NOT (OLD.fecha_cierre_novedad <=> NEW.fecha_cierre_novedad) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'fecha_cierre_novedad', OLD.fecha_cierre_novedad, NEW.fecha_cierre_novedad);
    END IF;
    
    IF NOT (OLD.controlador <=> NEW.controlador) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'botones_panico', NEW.id_prueba, 'controlador', OLD.controlador, NEW.controlador);
    END IF;

END //

-- Restablece el delimitador.
DELIMITER ;

-- ##################### triggers para INSERT y UPDATE tabla backoffice  ##############################

-- Trigger AFTER INSERT en backoffice
DROP TRIGGER IF EXISTS trg_backoffice_after_insert;
DELIMITER //
CREATE TRIGGER trg_backoffice_after_insert
AFTER INSERT ON backoffice
FOR EACH ROW
BEGIN
  DECLARE v_registro_id VARCHAR(50);
  SET v_registro_id = NEW.backoffice_id;

  INSERT INTO auditoria (
    usuario,
    evento,
    tabla_afectada,
    registro_id,
    campo_afectado,
    valor_anterior,
    valor_nuevo
  ) VALUES
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'fecha',        NULL, NEW.fecha),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'estacion',     NULL, NEW.estacion),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'servicio',     NULL, NEW.servicio),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'driver',       NULL, NEW.driver),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'tipo_pago',    NULL, NEW.tipo_pago),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'proveedor',    NULL, NEW.proveedor),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'backof_1',     NULL, NEW.backof_1),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'hora_inicial', NULL, NEW.hora_inicial),
    (@usuario_actual, 'Inserción', 'backoffice', v_registro_id, 'hora_final',   NULL, NEW.hora_final);
END//
DELIMITER ;

-- Trigger AFTER UPDATE en backoffice
DROP TRIGGER IF EXISTS trg_backoffice_after_update;
DELIMITER //
CREATE TRIGGER trg_backoffice_after_update
AFTER UPDATE ON backoffice
FOR EACH ROW
BEGIN
DECLARE v_registro_id VARCHAR(50);
SET v_registro_id = NEW.backoffice_id;

IF NOT (OLD.fecha <=> NEW.fecha) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'fecha',
OLD.fecha,
NEW.fecha
);
END IF;

IF NOT (OLD.estacion <=> NEW.estacion) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'estacion',
OLD.estacion,
NEW.estacion
);
END IF;

IF NOT (OLD.servicio <=> NEW.servicio) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'servicio',
OLD.servicio,
NEW.servicio
);
END IF;

IF NOT (OLD.driver <=> NEW.driver) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'driver',
OLD.driver,
NEW.driver
);
END IF;

IF NOT (OLD.tipo_pago <=> NEW.tipo_pago) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'tipo_pago',
OLD.tipo_pago,
NEW.tipo_pago
);
END IF;

IF NOT (OLD.proveedor <=> NEW.proveedor) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'proveedor',
OLD.proveedor,
NEW.proveedor
);
END IF;

IF NOT (OLD.backof_1 <=> NEW.backof_1) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'backof_1',
OLD.backof_1,
NEW.backof_1
);
END IF;

IF NOT (OLD.hora_inicial <=> NEW.hora_inicial) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'hora_inicial',
OLD.hora_inicial,
NEW.hora_inicial
);
END IF;

IF NOT (OLD.hora_final <=> NEW.hora_final) THEN
INSERT INTO auditoria (
usuario,
evento,
tabla_afectada,
registro_id,
campo_afectado,
valor_anterior,
valor_nuevo
) VALUES (
@usuario_actual,
'Actualización',
'backoffice',
v_registro_id,
'hora_final',
OLD.hora_final,
NEW.hora_final
);
END IF;
END//
DELIMITER ;


-- Triggers para tabla caja_menor_operaciones

DELIMITER //

-- Trigger para auditoría AFTER INSERT en caja_menor_operaciones

DROP TRIGGER IF EXISTS trg_cmo_insert;
DROP TRIGGER IF EXISTS trg_cmo_update;

CREATE TRIGGER trg_cmo_insert
AFTER INSERT ON caja_menor_operaciones
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    ) VALUES (
        @usuario_actual,
        'Inserción',
        'caja_menor_operaciones',
        NEW.transaccion_id,
        NULL,
        NULL,
        NULL
    );
END;
//

-- Trigger para auditoría AFTER UPDATE en caja_menor_operaciones
CREATE TRIGGER trg_cmo_update
AFTER UPDATE ON caja_menor_operaciones
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    ) VALUES (
        @usuario_actual,
        'Actualización',
        'caja_menor_operaciones',
        NEW.transaccion_id,
        NULL,
        NULL,
        NULL
    );
END;
//

DELIMITER ;

-- Triggers para tabla ordenes_trabajo_vehiculo

-- Insercion de datos

DELIMITER //

CREATE TRIGGER trg_ot_vehiculo_insert
AFTER INSERT ON ordenes_trabajo_vehiculo
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');
  
  -- Auditoría de inserción de OT
  INSERT INTO auditoria (
    usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
  ) VALUES (
    v_usuario, 'Inserción', 'ordenes_trabajo_vehiculo', NEW.ot_id, 'numero_ot', NULL, NEW.numero_ot
  );
  
  INSERT INTO auditoria (
    usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
  ) VALUES (
    v_usuario, 'Inserción', 'ordenes_trabajo_vehiculo', NEW.ot_id, 'operacion_id', NULL, NEW.operacion_id
  );
END //

DELIMITER ;


-- Trigger actualizacion OT
DELIMITER //

CREATE TRIGGER trg_ot_vehiculo_update
AFTER UPDATE ON ordenes_trabajo_vehiculo
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');

  -- Auditoría de cambio en numero_ot
  IF NOT (OLD.numero_ot <=> NEW.numero_ot) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'ordenes_trabajo_vehiculo', NEW.ot_id, 'numero_ot', OLD.numero_ot, NEW.numero_ot
    );
  END IF;

  -- Auditoría de cambio en operacion_id
  IF NOT (OLD.operacion_id <=> NEW.operacion_id) THEN
    INSERT INTO auditoria (
      usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
      v_usuario, 'Actualización', 'ordenes_trabajo_vehiculo', NEW.ot_id, 'operacion_id', OLD.operacion_id, NEW.operacion_id
    );
  END IF;
END //

DELIMITER;

-- Triggers de INSERT y UPDATE tabala auxiliares_terceros

-- Eliminar el trigger si ya existe para evitar errores
DROP TRIGGER IF EXISTS trg_audit_insert_auxiliares;

DELIMITER //

CREATE TRIGGER trg_audit_insert_auxiliares
AFTER INSERT ON auxiliares_terceros
FOR EACH ROW
BEGIN
  -- Auditoría de la creación de un nuevo registro de auxiliar
  INSERT INTO auditoria (
    usuario,
    evento,
    tabla_afectada,
    registro_id,
    campo_afectado,
    valor_anterior,
    valor_nuevo
  ) VALUES (
    IFNULL(@usuario_actual, 'Desconocido'),
    'Inserción',
    'auxiliares_terceros',
    NEW.auxiliar_id,
    'N/A',
    NULL,
    CONCAT('Se creó el registro para el auxiliar con ID: ', NEW.auxiliar_id)
  );
END //

DELIMITER ;

-- Eliminar el trigger si ya existe para evitar errores
DROP TRIGGER IF EXISTS trg_audit_update_auxiliares;

DELIMITER //

CREATE TRIGGER trg_audit_update_auxiliares
AFTER UPDATE ON auxiliares_terceros
FOR EACH ROW
BEGIN
  DECLARE v_usuario VARCHAR(100);
  SET v_usuario = IFNULL(@usuario_actual, 'Desconocido');

  -- Auditoría para el campo 'fecha'
  IF NOT (OLD.fecha <=> NEW.fecha) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'fecha', OLD.fecha, NEW.fecha);
  END IF;

  -- Auditoría para el campo 'tipo_documento'
  IF NOT (OLD.tipo_documento <=> NEW.tipo_documento) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'tipo_documento', OLD.tipo_documento, NEW.tipo_documento);
  END IF;

  -- Auditoría para el campo 'documento'
  IF NOT (OLD.documento <=> NEW.documento) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'documento', OLD.documento, NEW.documento);
  END IF;

  -- Auditoría para el campo 'fecha_nacimiento'
  IF NOT (OLD.fecha_nacimiento <=> NEW.fecha_nacimiento) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'fecha_nacimiento', OLD.fecha_nacimiento, NEW.fecha_nacimiento);
  END IF;

  -- Auditoría para el campo 'nombre'
  IF NOT (OLD.nombre <=> NEW.nombre) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'nombre', OLD.nombre, NEW.nombre);
  END IF;

  -- Auditoría para el campo 'grupo_sanguineo'
  IF NOT (OLD.grupo_sanguineo <=> NEW.grupo_sanguineo) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'grupo_sanguineo', OLD.grupo_sanguineo, NEW.grupo_sanguineo);
  END IF;

  -- Auditoría para el campo 'rh'
  IF NOT (OLD.rh <=> NEW.rh) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'rh', OLD.rh, NEW.rh);
  END IF;

  -- Auditoría para el campo 'direccion'
  IF NOT (OLD.direccion <=> NEW.direccion) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'direccion', OLD.direccion, NEW.direccion);
  END IF;

  -- Auditoría para el campo 'ciudad'
  IF NOT (OLD.ciudad <=> NEW.ciudad) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'ciudad', OLD.ciudad, NEW.ciudad);
  END IF;

  -- Auditoría para el campo 'eps'
  IF NOT (OLD.eps <=> NEW.eps) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'eps', OLD.eps, NEW.eps);
  END IF;

  -- Auditoría para el campo 'arl'
  IF NOT (OLD.arl <=> NEW.arl) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'arl', OLD.arl, NEW.arl);
  END IF;
  
  -- Auditoría para el campo 'estatus'
  IF NOT (OLD.estatus <=> NEW.estatus) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'estatus', OLD.estatus, NEW.estatus);
  END IF;

  -- Auditoría para el campo 'fecha_nuevo_estatus'
  IF NOT (OLD.fecha_nuevo_estatus <=> NEW.fecha_nuevo_estatus) THEN
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Actualización', 'auxiliares_terceros', NEW.auxiliar_id, 'fecha_nuevo_estatus', OLD.fecha_nuevo_estatus, NEW.fecha_nuevo_estatus);
  END IF;

END //

DELIMITER ;


-- Trigers para eliminación de usuarios de la tabla usuarios y de pypdb con registro en auditoria
/* =========================================================================
   1. Trigger en COLABORADORES: baja del colaborador  NO ESTÁ CREADO POR PRECAUCION, DEFINIR SI SE CREA O NO
   ========================================================================= */
/*–– 1. Elimina el trigger previo si existe ––*/
DROP TRIGGER IF EXISTS trg_baja_colaborador;

DELIMITER //

CREATE TRIGGER trg_baja_colaborador
AFTER UPDATE ON colaboradores
FOR EACH ROW
BEGIN
    /*  A) Declaración de variables  — SIEMPRE va primero  */
    DECLARE v_id_usuario INT;
    DECLARE v_mysql_user VARCHAR(50);

    /*  B) Lógica del trigger  */
    IF OLD.estatus_colaborador = 'Activo'
       AND NEW.estatus_colaborador = 'Retirado' THEN

        /* 1. Cargar id_usuario y usuario asociados al colaborador */
        SELECT id_usuario, usuario
          INTO v_id_usuario, v_mysql_user
          FROM usuarios
         WHERE id_colaborador = OLD.id_colaborador
         LIMIT 1;

        /* 2. Registrar auditoría */
        INSERT INTO auditoria (
            usuario,
            evento,
            tabla_afectada,
            registro_id,
            campo_afectado,
            valor_anterior,
            valor_nuevo
        ) VALUES (
            SYSTEM_USER(),      -- quién ejecuta
            'Eliminación',
            'usuarios',
            v_id_usuario,
            'usuario',
            v_mysql_user,
            NULL
        );

        /* 3. Borrar fila en usuarios */
        DELETE FROM usuarios
         WHERE id_colaborador = OLD.id_colaborador;

        /* 4. Revocar la cuenta MySQL */
        CALL sp_drop_mysql_user(v_mysql_user);
    END IF;
END;
//
DELIMITER ;




/* =========================================================================
   2. Triggers de AUDITORÍA para la tabla USUARIOS
   ========================================================================= */

DELIMITER //

/* 2.1 AFTER INSERT */
CREATE TRIGGER trg_audit_usuarios_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (
      usuario,
      evento,
      tabla_afectada,
      registro_id,
      campo_afectado,
      valor_anterior,
      valor_nuevo
  ) VALUES (
      SYSTEM_USER(),
      'Inserción',
      'usuarios',
      NEW.id_usuario,
      NULL,
      NULL,
      CONCAT('usuario=', NEW.usuario)
  );
END;
//

/* 2.2 AFTER UPDATE */
CREATE TRIGGER trg_audit_usuarios_update
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (
      usuario,
      evento,
      tabla_afectada,
      registro_id,
      campo_afectado,
      valor_anterior,
      valor_nuevo
  ) VALUES (
      SYSTEM_USER(),
      'Actualización',
      'usuarios',
      OLD.id_usuario,
      'usuario',
      OLD.usuario,
      NEW.usuario
  );
END;
//

/* 2.3 AFTER DELETE */
CREATE TRIGGER trg_audit_usuarios_delete
AFTER DELETE ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (
      usuario,
      evento,
      tabla_afectada,
      registro_id,
      campo_afectado,
      valor_anterior,
      valor_nuevo
  ) VALUES (
      SYSTEM_USER(),
      'Eliminación',
      'usuarios',
      OLD.id_usuario,
      'usuario',
      OLD.usuario,
      NULL
  );
END;
//
DELIMITER ;


-- Trigger para auditar inserciones en la tabla 'colaboradores'
DELIMITER //

CREATE TRIGGER auditoria_insert_colaboradores
AFTER INSERT ON colaboradores
FOR EACH ROW
BEGIN
    -- Usamos @usuario_actual que se setea en el Stored Procedure
    INSERT INTO auditoria (
        usuario, 
        evento, 
        tabla_afectada, 
        registro_id, 
        campo_afectado,
        valor_anterior,
        valor_nuevo
    )
    VALUES (
        -- Si @usuario_actual no existe, usa el usuario de conexión (Fallback)
        IFNULL(@usuario_actual, CURRENT_USER()), 
        'Inserción', 
        'colaboradores', 
        -- Usamos el ID autonumérico para referencia exacta
        NEW.id_colaborador, 
        'All',
        'N/A', -- Valor anterior siempre N/A en una inserción
        'Fila Creada' -- El valor nuevo es la creación de la fila
    );
END //

DELIMITER ;

-- trigger para auditar la inserción de datos en la tabla seguridad_social
DELIMITER //

CREATE TRIGGER trg_audit_insert_seguridad_social
AFTER INSERT ON seguridad_social
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'seguridad_social',
        NEW.id_seguridad, -- El ID del nuevo registro
        'All',            -- Campo afectado: 'All' como solicitaste
        'N/A',            -- Valor anterior: 'N/A' como solicitaste
        'Fila Creada',    -- Valor nuevo: 'Fila Creada' como solicitaste
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;

-- trigger para auditar la inserción de datos en la tabla contactos_colaboradores
DELIMITER //

CREATE TRIGGER trg_audit_insert_contactos_colaboradores
AFTER INSERT ON contactos_colaboradores
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'contactos_colaboradores',
        NEW.id_contacto, -- El ID del nuevo contacto
        'All',
        'N/A',
        'Fila Creada',
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;

-- Trigger de Auditoría para la Tabla contratos Inserción
DELIMITER //

CREATE TRIGGER trg_audit_insert_contratos
AFTER INSERT ON contratos
FOR EACH ROW
BEGIN
    -- Inserta un registro genérico en la tabla de auditoría
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        -- Lee la variable de sesión, si no existe, guarda 'sistema'
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'contratos',
        NEW.id_contrato, -- La clave primaria del nuevo contrato insertado
        'All',
        'N/A',
        'Fila Creada',
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;



-- Trigger de Auditoría para la Tabla pp (Periodo de Prueba)
DELIMITER //

CREATE TRIGGER trg_audit_insert_pp
AFTER INSERT ON pp
FOR EACH ROW
BEGIN
    -- Inserta un registro genérico en la tabla de auditoría
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'pp',
        NEW.id_pp, -- La clave primaria del nuevo registro de periodo de prueba
        'All',
        'N/A',
        'Fila Creada',
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;

-- Trigger de auditoria para la tabla beneficiarios
DELIMITER //

CREATE TRIGGER trg_audit_insert_beneficiarios
AFTER INSERT ON beneficiarios
FOR EACH ROW
BEGIN
    -- Inserta un registro en la tabla de auditoría por cada nuevo beneficiario.
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        -- Lee la variable de sesión, si no existe, guarda 'sistema' como fallback.
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'beneficiarios',
        NEW.id_beneficiario, -- Captura el ID autoincremental del nuevo beneficiario.
        'All',
        'N/A',
        'Fila Creada',
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;

-- Trigger de auditoria de insercion tabla datos bancarios colaboradores
DELIMITER //

CREATE TRIGGER trg_audit_insert_cuentas_bancarias
AFTER INSERT ON cuentas_bancarias_colaboradores
FOR EACH ROW
BEGIN
    -- Inserta un registro en la tabla de auditoría por cada nueva cuenta bancaria.
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        -- Lee la variable de sesión, si no existe, guarda 'sistema' como respaldo.
        COALESCE(@usuario_actual, 'sistema'),
        'Inserción',
        'cuentas_bancarias_colaboradores',
        NEW.cuenta_id, -- Captura el ID autoincremental de la nueva cuenta.
        'All',
        'N/A',
        'Fila Creada',
        CURRENT_TIMESTAMP
    );
END//

DELIMITER ;


-- Trigger de actualización de campos en registro de colanboradores
-- Trigger de auditoría para actualización de tabla colaboradores
DELIMITER //

CREATE TRIGGER trg_audit_update_colaboradores
AFTER UPDATE ON colaboradores
FOR EACH ROW
BEGIN
    -- Se inserta un registro en auditoria por CADA CAMPO QUE CAMBIÓ
    
    -- 1. tipo_id
    IF OLD.tipo_id != NEW.tipo_id THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'tipo_id', OLD.tipo_id, NEW.tipo_id, CURRENT_TIMESTAMP);
    END IF;
    
    -- 2. id_cc
    IF OLD.id_cc != NEW.id_cc THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'id_cc', OLD.id_cc, NEW.id_cc, CURRENT_TIMESTAMP);
    END IF;
    
    -- 3. lugar_expedicion
    IF OLD.lugar_expedicion != NEW.lugar_expedicion THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'lugar_expedicion', CAST(OLD.lugar_expedicion AS CHAR), CAST(NEW.lugar_expedicion AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 4. fecha_expedicion
    IF OLD.fecha_expedicion != NEW.fecha_expedicion THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'fecha_expedicion', CAST(OLD.fecha_expedicion AS CHAR), CAST(NEW.fecha_expedicion AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 5. primer_nombre
    IF OLD.primer_nombre != NEW.primer_nombre THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'primer_nombre', OLD.primer_nombre, NEW.primer_nombre, CURRENT_TIMESTAMP);
    END IF;
    
    -- 6. segundo_nombre
    IF OLD.segundo_nombre != NEW.segundo_nombre THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'segundo_nombre', OLD.segundo_nombre, NEW.segundo_nombre, CURRENT_TIMESTAMP);
    END IF;
    
    -- 7. primer_apellido
    IF OLD.primer_apellido != NEW.primer_apellido THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'primer_apellido', OLD.primer_apellido, NEW.primer_apellido, CURRENT_TIMESTAMP);
    END IF;
    
    -- 8. segundo_apellido
    IF OLD.segundo_apellido != NEW.segundo_apellido THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'segundo_apellido', OLD.segundo_apellido, NEW.segundo_apellido, CURRENT_TIMESTAMP);
    END IF;
    
    -- 9. formacion_academica
    IF OLD.formacion_academica != NEW.formacion_academica THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'formacion_academica', OLD.formacion_academica, NEW.formacion_academica, CURRENT_TIMESTAMP);
    END IF;
    
    -- 10. estado_formacion_academica
    IF OLD.estado_formacion_academica != NEW.estado_formacion_academica THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'estado_formacion_academica', OLD.estado_formacion_academica, NEW.estado_formacion_academica, CURRENT_TIMESTAMP);
    END IF;
    
    -- 11. fecha_nacimiento
    IF OLD.fecha_nacimiento != NEW.fecha_nacimiento THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'fecha_nacimiento', CAST(OLD.fecha_nacimiento AS CHAR), CAST(NEW.fecha_nacimiento AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 12. sexo
    IF OLD.sexo != NEW.sexo THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'sexo', OLD.sexo, NEW.sexo, CURRENT_TIMESTAMP);
    END IF;
    
    -- 13. grupo_sanguineo
    IF OLD.grupo_sanguineo != NEW.grupo_sanguineo THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'grupo_sanguineo', OLD.grupo_sanguineo, NEW.grupo_sanguineo, CURRENT_TIMESTAMP);
    END IF;
    
    -- 14. rh
    IF OLD.rh != NEW.rh THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'rh', OLD.rh, NEW.rh, CURRENT_TIMESTAMP);
    END IF;
    
    -- 15. estado_civil
    IF OLD.estado_civil != NEW.estado_civil THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'estado_civil', OLD.estado_civil, NEW.estado_civil, CURRENT_TIMESTAMP);
    END IF;
    
    -- 16. direccion
    IF OLD.direccion != NEW.direccion THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'direccion', OLD.direccion, NEW.direccion, CURRENT_TIMESTAMP);
    END IF;
    
    -- 17. barrio
    IF OLD.barrio != NEW.barrio THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'barrio', OLD.barrio, NEW.barrio, CURRENT_TIMESTAMP);
    END IF;
    
    -- 18. estrato
    IF OLD.estrato != NEW.estrato THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'estrato', OLD.estrato, NEW.estrato, CURRENT_TIMESTAMP);
    END IF;
    
    -- 19. ciudad_nacimiento
    IF OLD.ciudad_nacimiento != NEW.ciudad_nacimiento THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'ciudad_nacimiento', CAST(OLD.ciudad_nacimiento AS CHAR), CAST(NEW.ciudad_nacimiento AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 20. departamento_nacimiento
    IF OLD.departamento_nacimiento != NEW.departamento_nacimiento THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'departamento_nacimiento', CAST(OLD.departamento_nacimiento AS CHAR), CAST(NEW.departamento_nacimiento AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 21. pais_nacimiento
    IF OLD.pais_nacimiento != NEW.pais_nacimiento THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'pais_nacimiento', CAST(OLD.pais_nacimiento AS CHAR), CAST(NEW.pais_nacimiento AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 22. estatus_colaborador
    IF OLD.estatus_colaborador != NEW.estatus_colaborador THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'estatus_colaborador', OLD.estatus_colaborador, NEW.estatus_colaborador, CURRENT_TIMESTAMP);
    END IF;
    
    -- 23. departamento
    IF OLD.departamento != NEW.departamento THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'departamento', CAST(OLD.departamento AS CHAR), CAST(NEW.departamento AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 24. cargo
    IF OLD.cargo != NEW.cargo THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'cargo', CAST(OLD.cargo AS CHAR), CAST(NEW.cargo AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 25. sede
    IF OLD.sede != NEW.sede THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'sede', CAST(OLD.sede AS CHAR), CAST(NEW.sede AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 26. planta
    IF OLD.planta != NEW.planta THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'planta', OLD.planta, NEW.planta, CURRENT_TIMESTAMP);
    END IF;
    
    -- 27. id_jefe
    IF OLD.id_jefe != NEW.id_jefe THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'id_jefe', CAST(OLD.id_jefe AS CHAR), CAST(NEW.id_jefe AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 28. fecha_emo
    IF OLD.fecha_emo != NEW.fecha_emo THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'fecha_emo', CAST(OLD.fecha_emo AS CHAR), CAST(NEW.fecha_emo AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 29. fecha_proximo_emo
    IF OLD.fecha_proximo_emo != NEW.fecha_proximo_emo THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'fecha_proximo_emo', CAST(OLD.fecha_proximo_emo AS CHAR), CAST(NEW.fecha_proximo_emo AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 30. fecha_elaboracion_carnet
    IF OLD.fecha_elaboracion_carnet != NEW.fecha_elaboracion_carnet THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'fecha_elaboracion_carnet', CAST(OLD.fecha_elaboracion_carnet AS CHAR), CAST(NEW.fecha_elaboracion_carnet AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 31. ruta_induccion
    IF OLD.ruta_induccion != NEW.ruta_induccion THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'ruta_induccion', CAST(OLD.ruta_induccion AS CHAR), CAST(NEW.ruta_induccion AS CHAR), CURRENT_TIMESTAMP);
    END IF;
    
    -- 32. contacto_emergencia
    IF OLD.contacto_emergencia != NEW.contacto_emergencia THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'contacto_emergencia', OLD.contacto_emergencia, NEW.contacto_emergencia, CURRENT_TIMESTAMP);
    END IF;
    
    -- 33. telefono_contacto_emergencia
    IF OLD.telefono_contacto_emergencia != NEW.telefono_contacto_emergencia THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (COALESCE(@usuario_actual, 'sistema'), 'Actualización', 'colaboradores', CAST(NEW.id_colaborador AS CHAR), 'telefono_contacto_emergencia', OLD.telefono_contacto_emergencia, NEW.telefono_contacto_emergencia, CURRENT_TIMESTAMP);
    END IF;
    
END//

DELIMITER ;





-- #################################################################################################################################################################

-- Trigger para corroborar que candado satelital está disponible
DELIMITER //
CREATE TRIGGER validar_candado_operativo
BEFORE INSERT ON movimiento_candados
FOR EACH ROW
BEGIN
    DECLARE estado_actual ENUM('EN OPERACION', 'FUERA DE OPERACION', 'MANTENIMIENTO');
    SELECT estatus INTO estado_actual
    FROM candados_satelitales
    WHERE candado_id = NEW.candado_id;

    IF estado_actual != 'EN OPERACION' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede asignar un candado que no está en operación';
    END IF;
END //
DELIMITER ;



-- TRIGGERS DE AUDITORÍA: UNO POR CADA TABLA


-- Trigger para crear el nombre de la regala para la tabla regla_tarifas
DELIMITER //
CREATE TRIGGER trg_reglas_tarifas_set_regla
BEFORE INSERT ON reglas_tarifas
FOR EACH ROW
BEGIN
    DECLARE origen_iata VARCHAR(5);
    DECLARE destino_iata VARCHAR(5);

    -- Obtener códigos IATA desde la tabla ciudades (ajustado el nombre del campo)
    SELECT iata_abreviatura INTO origen_iata 
    FROM ciudades 
    WHERE id_ciudad = NEW.id_origen;

    SELECT iata_abreviatura INTO destino_iata 
    FROM ciudades 
    WHERE id_ciudad = NEW.id_destino;

    -- Construir la regla concatenada
    SET NEW.regla = CONCAT(origen_iata, '-', destino_iata, NEW.driver, NEW.concepto, NEW.tonelaje);
END//
DELIMITER ;



-- Auditoría para ciudades
DELIMITER //
CREATE TRIGGER auditoria_insert_ciudades
AFTER INSERT ON ciudades
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'ciudades', NEW.id_ciudad, 'All');
END //
DELIMITER ;

DELIMITER //  -- Corregir
CREATE TRIGGER auditoria_update_ciudades
AFTER UPDATE ON ciudades
FOR EACH ROW
BEGIN
    IF OLD.nombre <> NEW.nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'ciudades', OLD.id_ciudad, 'nombre', OLD.nombre, NEW.nombre);
    END IF;
    IF OLD.departamento <> NEW.departamento THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'ciudades', OLD.id_ciudad, 'departamento', OLD.departamento, NEW.departamento);
    END IF;
    IF OLD.codigo_postal <> NEW.codigo_postal THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'ciudades', OLD.id_ciudad, 'codigo_postal', OLD.codigo_postal, NEW.codigo_postal);
    END IF;
    IF OLD.latitud <> NEW.latitud THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'ciudades', OLD.id_ciudad, 'latitud', OLD.latitud, NEW.latitud);
    END IF;
    IF OLD.longitud <> NEW.longitud THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'ciudades', OLD.id_ciudad, 'longitud', OLD.longitud, NEW.longitud);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_ciudades
AFTER DELETE ON ciudades
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'ciudades', OLD.id_ciudad, 'All');
END //
DELIMITER ;

-- Auditoría para departamentos
DELIMITER //
CREATE TRIGGER auditoria_insert_departamentos
AFTER INSERT ON departamentos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'departamentos', NEW.departamento_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_departamentos
AFTER UPDATE ON departamentos
FOR EACH ROW
BEGIN
    IF OLD.nombre <> NEW.nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'departamentos', OLD.departamento_id, 'nombre', OLD.nombre, NEW.nombre);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_departamentos
AFTER DELETE ON departamentos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'departamentos', OLD.departamento_id, 'All');
END //
DELIMITER ;

-- Auditoría para roles
DELIMITER //
CREATE TRIGGER auditoria_insert_roles
AFTER INSERT ON roles
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'roles', NEW.id_rol, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_roles
AFTER UPDATE ON roles
FOR EACH ROW
BEGIN
    IF OLD.cargo <> NEW.cargo THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'roles', OLD.id_rol, 'cargo', OLD.cargo, NEW.cargo);
    END IF;
    IF OLD.rol <> NEW.rol THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'roles', OLD.id_rol, 'rol', OLD.rol, NEW.rol);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_roles
AFTER DELETE ON roles
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'roles', OLD.id_rol, 'All');
END //
DELIMITER ;

-- Auditoría para sedes
DELIMITER //
CREATE TRIGGER auditoria_insert_sedes
AFTER INSERT ON sedes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'sedes', NEW.id_sede, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_sedes
AFTER UPDATE ON sedes
FOR EACH ROW
BEGIN
    IF OLD.nombre <> NEW.nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'sedes', OLD.id_sede, 'nombre', OLD.nombre, NEW.nombre);
    END IF;
    IF OLD.ciudad <> NEW.ciudad THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'sedes', OLD.id_sede, 'ciudad', OLD.ciudad, NEW.ciudad);
    END IF;
    IF OLD.tipo <> NEW.tipo THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'sedes', OLD.id_sede, 'tipo', OLD.tipo, NEW.tipo);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_sedes
AFTER DELETE ON sedes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'sedes', OLD.id_sede, 'All');
END //
DELIMITER ;



DELIMITER // -- Corregir
CREATE TRIGGER auditoria_update_colaboradores
AFTER UPDATE ON colaboradores
FOR EACH ROW
BEGIN
    IF OLD.primer_nombre <> NEW.primer_nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'primer_nombre', OLD.primer_nombre, NEW.primer_nombre);
    END IF;
    IF OLD.segundo_nombre <> NEW.segundo_nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'segundo_nombre', OLD.segundo_nombre, NEW.segundo_nombre);
    END IF;
    IF OLD.primer_apellido <> NEW.primer_apellido THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'primer_apellido', OLD.primer_apellido, NEW.primer_apellido);
    END IF;
    IF OLD.segundo_apellido <> NEW.segundo_apellido THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'segundo_apellido', OLD.segundo_apellido, NEW.segundo_apellido);
    END IF;
    IF OLD.email <> NEW.email THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'email', OLD.email, NEW.email);
    END IF;
    IF OLD.telefono <> NEW.telefono THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'telefono', OLD.telefono, NEW.telefono);
    END IF;
    IF OLD.fecha_nacimiento <> NEW.fecha_nacimiento THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'fecha_nacimiento', OLD.fecha_nacimiento, NEW.fecha_nacimiento);
    END IF;
    IF OLD.fecha_contratacion <> NEW.fecha_contratacion THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'fecha_contratacion', OLD.fecha_contratacion, NEW.fecha_contratacion);
    END IF;
    IF OLD.fecha_retiro <> NEW.fecha_retiro THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'fecha_retiro', OLD.fecha_retiro, NEW.fecha_retiro);
    END IF;
    IF OLD.estatus_colaborador <> NEW.estatus_colaborador THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'estatus_colaborador', OLD.estatus_colaborador, NEW.estatus_colaborador);
    END IF;
    IF OLD.salario <> NEW.salario THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'salario', OLD.salario, NEW.salario);
    END IF;
    IF OLD.departamento <> NEW.departamento THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'departamento', OLD.departamento, NEW.departamento);
    END IF;
    IF OLD.rol <> NEW.rol THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'rol', OLD.rol, NEW.rol);
    END IF;
    IF OLD.sede <> NEW.sede THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'colaboradores', OLD.id_cc, 'sede', OLD.sede, NEW.sede);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_colaboradores
AFTER DELETE ON colaboradores
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'colaboradores', OLD.id_cc, 'All');
END //
DELIMITER ;

-- Auditoría para incapacidades
DELIMITER //
CREATE TRIGGER auditoria_insert_incapacidades
AFTER INSERT ON incapacidades
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'incapacidades', NEW.incapacidad_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_incapacidades
AFTER UPDATE ON incapacidades
FOR EACH ROW
BEGIN
    IF OLD.id_colaborador <> NEW.id_colaborador THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'incapacidades', OLD.incapacidad_id, 'id_colaborador', OLD.id_colaborador, NEW.id_colaborador);
    END IF;
    IF OLD.fecha_inicio_incapacidad <> NEW.fecha_inicio_incapacidad THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'incapacidades', OLD.incapacidad_id, 'fecha_inicio_incapacidad', OLD.fecha_inicio_incapacidad, NEW.fecha_inicio_incapacidad);
    END IF;
    IF OLD.fecha_fin_incapacidad <> NEW.fecha_fin_incapacidad THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'incapacidades', OLD.incapacidad_id, 'fecha_fin_incapacidad', OLD.fecha_fin_incapacidad, NEW.fecha_fin_incapacidad);
    END IF;
    IF OLD.tipo_tratamiento <> NEW.tipo_tratamiento THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'incapacidades', OLD.incapacidad_id, 'tipo_tratamiento', OLD.tipo_tratamiento, NEW.tipo_tratamiento);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_incapacidades
AFTER DELETE ON incapacidades
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'incapacidades', OLD.incapacidad_id, 'All');
END //
DELIMITER ;

-- Auditoría para vehiculos
DELIMITER //
CREATE TRIGGER auditoria_insert_vehiculos
AFTER INSERT ON vehiculos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'vehiculos', NEW.placa, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_vehiculos
AFTER UPDATE ON vehiculos
FOR EACH ROW
BEGIN
    IF OLD.marca <> NEW.marca THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'vehiculos', OLD.placa, 'marca', OLD.marca, NEW.marca);
    END IF;
    IF OLD.modelo <> NEW.modelo THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'vehiculos', OLD.placa, 'modelo', OLD.modelo, NEW.modelo);
    END IF;
    IF OLD.anio <> NEW.anio THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'vehiculos', OLD.placa, 'anio', OLD.anio, NEW.anio);
    END IF;
    IF OLD.capacidad <> NEW.capacidad THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'vehiculos', OLD.placa, 'capacidad', OLD.capacidad, NEW.capacidad);
    END IF;
    IF OLD.estado <> NEW.estado THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'vehiculos', OLD.placa, 'estado', OLD.estado, NEW.estado);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_vehiculos
AFTER DELETE ON vehiculos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'vehiculos', OLD.placa, 'All');
END //
DELIMITER ;

-- Auditoría para rutas
DELIMITER //
CREATE TRIGGER auditoria_insert_rutas
AFTER INSERT ON rutas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'rutas', NEW.ruta_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_rutas
AFTER UPDATE ON rutas
FOR EACH ROW
BEGIN
    IF OLD.origen <> NEW.origen THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'rutas', OLD.ruta_id, 'origen', OLD.origen, NEW.origen);
    END IF;
    IF OLD.destino <> NEW.destino THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'rutas', OLD.ruta_id, 'destino', OLD.destino, NEW.destino);
    END IF;
    IF OLD.distancia_km <> NEW.distancia_km THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'rutas', OLD.ruta_id, 'distancia_km', OLD.distancia_km, NEW.distancia_km);
    END IF;
    IF OLD.tiempo_estimado <> NEW.tiempo_estimado THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'rutas', OLD.ruta_id, 'tiempo_estimado', OLD.tiempo_estimado, NEW.tiempo_estimado);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_rutas
AFTER DELETE ON rutas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'rutas', OLD.ruta_id, 'All');
END //
DELIMITER ;

-- Auditoría para clientes
DELIMITER //
CREATE TRIGGER auditoria_insert_clientes
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'clientes', NEW.cliente_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_clientes
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF OLD.nombre <> NEW.nombre THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'clientes', OLD.cliente_id, 'nombre', OLD.nombre, NEW.nombre);
    END IF;
    IF OLD.contacto <> NEW.contacto THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'clientes', OLD.cliente_id, 'contacto', OLD.contacto, NEW.contacto);
    END IF;
    IF OLD.telefono <> NEW.telefono THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'clientes', OLD.cliente_id, 'telefono', OLD.telefono, NEW.telefono);
    END IF;
    IF OLD.email <> NEW.email THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'clientes', OLD.cliente_id, 'email', OLD.email, NEW.email);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_clientes
AFTER DELETE ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'clientes', OLD.cliente_id, 'All');
END //
DELIMITER ;

-- Auditoría para conductores
DELIMITER // -- corregir
CREATE TRIGGER auditoria_insert_conductores
AFTER INSERT ON conductores
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'conductores', NEW.conductor_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_conductores  -- corregir
AFTER UPDATE ON conductores
FOR EACH ROW
BEGIN
    IF OLD.licencia <> NEW.licencia THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'conductores', OLD.conductor_id, 'licencia', OLD.licencia, NEW.licencia);
    END IF;
    IF OLD.tipo_licencia <> NEW.tipo_licencia THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'conductores', OLD.conductor_id, 'tipo_licencia', OLD.tipo_licencia, NEW.tipo_licencia);
    END IF;
    IF OLD.fecha_vencimiento_lic <> NEW.fecha_vencimiento_lic THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'conductores', OLD.conductor_id, 'fecha_vencimiento_lic', OLD.fecha_vencimiento_lic, NEW.fecha_vencimiento_lic);
    END IF;
END //
DELIMITER ;

DELIMITER //  -- corregir
CREATE TRIGGER auditoria_delete_conductores
AFTER DELETE ON conductores
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'conductores', OLD.conductor_id, 'All');
END //
DELIMITER ;

-- Auditoría para envios
DELIMITER //
CREATE TRIGGER auditoria_insert_envios
AFTER INSERT ON envios
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Inserción', 'envios', NEW.envio_id, 'All');
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_update_envios
AFTER UPDATE ON envios
FOR EACH ROW
BEGIN
    IF OLD.guia_id <> NEW.guia_id THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'guia_id', OLD.guia_id, NEW.guia_id);
    END IF;
    IF OLD.cliente_id <> NEW.cliente_id THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'cliente_id', OLD.cliente_id, NEW.cliente_id);
    END IF;
    IF OLD.conductor_id <> NEW.conductor_id THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'conductor_id', OLD.conductor_id, NEW.conductor_id);
    END IF;
    IF OLD.vehiculo_placa <> NEW.vehiculo_placa THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'vehiculo_placa', OLD.vehiculo_placa, NEW.vehiculo_placa);
    END IF;
    IF OLD.ruta_id <> NEW.ruta_id THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'ruta_id', OLD.ruta_id, NEW.ruta_id);
    END IF;
    IF OLD.fecha_salida <> NEW.fecha_salida THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'fecha_salida', OLD.fecha_salida, NEW.fecha_salida);
    END IF;
    IF OLD.fecha_llegada <> NEW.fecha_llegada THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'fecha_llegada', OLD.fecha_llegada, NEW.fecha_llegada);
    END IF;
    IF OLD.estado <> NEW.estado THEN
      INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
      VALUES(CURRENT_USER(), 'Actualización', 'envios', OLD.envio_id, 'estado', OLD.estado, NEW.estado);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_delete_envios
AFTER DELETE ON envios
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(usuario, evento, tabla_afectada, registro_id, campo_afectado)
    VALUES(CURRENT_USER(), 'Eliminación', 'envios', OLD.envio_id, 'All');
END //
DELIMITER ;

-- Crear trigger para que al colocar fecha de retiro de un colaborador pase a estatus 'Inactivo' 
DELIMITER // -- Corregir

CREATE TRIGGER trg_colaborador_inactivo
BEFORE UPDATE ON colaboradores
FOR EACH ROW
BEGIN
    IF NEW.fecha_retiro IS NOT NULL THEN
         SET NEW.estatus_colaborador = 'Inactivo';
    END IF;
END //
DELIMITER ;



-- Trigger INSER tabla pausas_activas
-- Elimina el trigger si ya existe para evitar errores al recrearlo.
DROP TRIGGER IF EXISTS trg_insert_pausa_activa;

-- Cambia el delimitador para definir el cuerpo del trigger.
DELIMITER //

CREATE TRIGGER trg_insert_pausa_activa
AFTER INSERT ON pausas_acivas
FOR EACH ROW
BEGIN
    -- Declara una variable para almacenar el nombre del usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Obtiene el usuario de la sesión, con CURRENT_USER() y 'sistema' como respaldo.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Inserta el registro de auditoría para la nueva fila.
    INSERT INTO auditoria (
        usuario, evento, tabla_afectada, registro_id,
        campo_afectado, valor_anterior, valor_nuevo
    ) VALUES (
        v_usuario,
        'Inserción',
        'pausas_activas',
        NEW.pausa_id, -- Clave primaria del nuevo registro.
        NULL, NULL, NULL -- No hay valores previos en una inserción.
    );
END //

-- Restablece el delimitador estándar.
DELIMITER ;


-- Trigger UPDATE tabla pausas activas
-- Elimina el trigger si ya existe para evitar errores.
DROP TRIGGER IF EXISTS trg_update_pausa_activa;

-- Cambia el delimitador.
DELIMITER //

CREATE TRIGGER trg_update_pausa_activa
AFTER UPDATE ON pausas_acivas
FOR EACH ROW
BEGIN
    -- Declara la variable para el usuario.
    DECLARE v_usuario VARCHAR(100);

    -- Asigna el usuario de la sesión.
    SET v_usuario = COALESCE(@usuario_actual, CURRENT_USER(), 'sistema');

    -- Compara cada campo para registrar los cambios. El operador <=> maneja correctamente los NULL.
    IF NOT (OLD.fecha <=> NEW.fecha) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'fecha', OLD.fecha, NEW.fecha);
    END IF;

    IF NOT (OLD.hora <=> NEW.hora) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'hora', OLD.hora, NEW.hora);
    END IF;

    IF NOT (OLD.tiempo_conduccion <=> NEW.tiempo_conduccion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'tiempo_conduccion', OLD.tiempo_conduccion, NEW.tiempo_conduccion);
    END IF;
    
    IF NOT (OLD.pausa_real <=> NEW.pausa_real) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'pausa_real', OLD.pausa_real, NEW.pausa_real);
    END IF;

    IF NOT (OLD.origen <=> NEW.origen) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'origen', OLD.origen, NEW.origen);
    END IF;
    
    IF NOT (OLD.destino <=> NEW.destino) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'destino', OLD.destino, NEW.destino);
    END IF;
    
    IF NOT (OLD.placa <=> NEW.placa) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'placa', OLD.placa, NEW.placa);
    END IF;
    
    IF NOT (OLD.novedad <=> NEW.novedad) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'novedad', OLD.novedad, NEW.novedad);
    END IF;
    
    IF NOT (OLD.observaciones <=> NEW.observaciones) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'observaciones', OLD.observaciones, NEW.observaciones);
    END IF;
    
    IF NOT (OLD.fecha_reporte <=> NEW.fecha_reporte) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'fecha_reporte', OLD.fecha_reporte, NEW.fecha_reporte);
    END IF;
    
    IF NOT (OLD.controlador <=> NEW.controlador) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'pausas_activas', NEW.pausa_id, 'controlador', OLD.controlador, NEW.controlador);
    END IF;

END //

-- Restablece el delimitador.
DELIMITER ;


-- Trigger de Actualizacion de datos de contacto del colaborador

DELIMITER //

CREATE TRIGGER trg_audit_update_contactos_colaboradores
AFTER UPDATE ON contactos_colaboradores
FOR EACH ROW
BEGIN
    -- Variable para registrar los campos que han cambiado.
    DECLARE campos_cambiados VARCHAR(255) DEFAULT '';
    DECLARE valores_antiguos TEXT DEFAULT '';
    DECLARE valores_nuevos TEXT DEFAULT '';

    -- Verificar si el campo 'tipo' ha cambiado.
    IF NOT (NEW.tipo <=> OLD.tipo) THEN
        SET campos_cambiados = 'tipo';
        SET valores_antiguos = OLD.tipo;
        SET valores_nuevos = NEW.tipo;
    END IF;

    -- Verificar si el campo 'valor' ha cambiado.
    IF NOT (NEW.valor <=> OLD.valor) THEN
        IF campos_cambiados <> '' THEN
            SET campos_cambiados = CONCAT(campos_cambiados, ', valor');
            SET valores_antiguos = CONCAT(valores_antiguos, ', ', OLD.valor);
            SET valores_nuevos = CONCAT(valores_nuevos, ', ', NEW.valor);
        ELSE
            SET campos_cambiados = 'valor';
            SET valores_antiguos = OLD.valor;
            SET valores_nuevos = NEW.valor;
        END IF;
    END IF;

    -- Si se detectó al menos un cambio, insertar en la tabla de auditoría.
    IF campos_cambiados <> '' THEN
        INSERT INTO auditoria (
            usuario,
            evento,
            tabla_afectada,
            registro_id,
            campo_afectado,
            valor_anterior,
            valor_nuevo
        ) VALUES (
            @usuario_actual,
            'Actualización',
            'contactos_colaboradores',
            OLD.id_contacto, -- Se usa OLD.id_contacto ya que la PK no debería cambiar.
            campos_cambiados,
            valores_antiguos,
            valores_nuevos
        );
    END IF;
END//

DELIMITER ;

-- Trigger para registrar eliminacion de datos de contacto de un colaborador
DELIMITER //

CREATE TRIGGER trg_audit_delete_contactos_colaboradores
AFTER DELETE ON contactos_colaboradores
FOR EACH ROW
BEGIN
    -- En un trigger de eliminación, solo tenemos acceso a los datos del registro borrado (OLD).
    -- Todos los campos se consideran "valor_anterior", y "valor_nuevo" no aplica.
    
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    ) VALUES (
        @usuario_actual,       -- Captura el usuario establecido en el SP 'sp_eliminar_contacto_colaborador'
        'Eliminación',
        'contactos_colaboradores',
        OLD.id_contacto,       -- El ID del registro que fue eliminado
        'TODOS',               -- Indica que el registro completo fue eliminado
        CONCAT(
            'id_colaborador: ', OLD.id_colaborador, 
            ', tipo: ', OLD.tipo, 
            ', valor: ', OLD.valor
        ),                     -- Concatena todos los valores del registro eliminado
        NULL                   -- No hay un "valor nuevo" en una eliminación
    );
END//

DELIMITER ;

-- Trigger de Actualización tabla seguridad_social
-- Primero, elimina el trigger anterior para evitar conflictos
DROP TRIGGER IF EXISTS trg_audit_update_seguridad_social;

DELIMITER //

-- Crear el nuevo trigger, más simple y robusto
CREATE TRIGGER trg_audit_update_seguridad_social
AFTER UPDATE ON seguridad_social
FOR EACH ROW
BEGIN
    -- Usamos COALESCE para protegernos contra un @usuario_actual nulo.
    DECLARE v_usuario_auditoria VARCHAR(100) DEFAULT COALESCE(@usuario_actual, 'SISTEMA');

    -- Compara cada campo individualmente. Si cambió, inserta una fila en la auditoría.
    
    IF NOT (NEW.cesantias <=> OLD.cesantias) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'cesantias', OLD.cesantias, NEW.cesantias);
    END IF;
    
    IF NOT (NEW.pension <=> OLD.pension) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'pension', OLD.pension, NEW.pension);
    END IF;
    
    IF NOT (NEW.eps <=> OLD.eps) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'eps', OLD.eps, NEW.eps);
    END IF;
    
    IF NOT (NEW.arl <=> OLD.arl) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'arl', OLD.arl, NEW.arl);
    END IF;
    
    IF NOT (NEW.riesgo <=> OLD.riesgo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'riesgo', OLD.riesgo, NEW.riesgo);
    END IF;
    
    IF NOT (NEW.ccf <=> OLD.ccf) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario_auditoria, 'Actualización', 'seguridad_social', OLD.id_seguridad, 'ccf', OLD.ccf, NEW.ccf);
    END IF;

END//

DELIMITER ;

-- Trigger de inserción modificaciones contratos
DELIMITER //

CREATE TRIGGER trg_contratos_modificaciones_after_insert
AFTER INSERT ON contratos_modificaciones
FOR EACH ROW
BEGIN
    -- Insertar un único registro en la tabla de auditoría para la nueva fila.
    -- Se usa la variable de sesión @usuario_actual que fijamos en el Stored Procedure.
    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo,
        fecha
    )
    VALUES (
        IF(@usuario_actual IS NULL, 'sistema', @usuario_actual),
        'Inserción',
        'contratos_modificaciones',
        NEW.id_modificacion,
        'All',
        'N/A',
        'Fila Creada',
        NOW()
    );
END//

DELIMITER ;

-- Trigger Actualización de modificaciones a contratos
DELIMITER //

CREATE TRIGGER trg_contratos_modificaciones_after_update
AFTER UPDATE ON contratos_modificaciones
FOR EACH ROW
BEGIN
    -- Variable para el usuario, usando la variable de sesión o 'sistema' como fallback.
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IF(@usuario_actual IS NULL, 'sistema', @usuario_actual);

    -- Comparar cada campo. Si ha cambiado, se inserta un registro en la auditoría.
    -- El operador <=> es seguro para comparar valores que podrían ser NULL.

    IF NOT (OLD.fecha_modificacion <=> NEW.fecha_modificacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'fecha_modificacion', OLD.fecha_modificacion, NEW.fecha_modificacion, NOW());
    END IF;

    IF NOT (OLD.tipo_modificacion <=> NEW.tipo_modificacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'tipo_modificacion', OLD.tipo_modificacion, NEW.tipo_modificacion, NOW());
    END IF;

    IF NOT (OLD.observaciones <=> NEW.observaciones) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'observaciones', OLD.observaciones, NEW.observaciones, NOW());
    END IF;

    IF NOT (OLD.cambio_salario <=> NEW.cambio_salario) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'cambio_salario', OLD.cambio_salario, NEW.cambio_salario, NOW());
    END IF;

    IF NOT (OLD.cambio_cargo <=> NEW.cambio_cargo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'cambio_cargo', OLD.cambio_cargo, NEW.cambio_cargo, NOW());
    END IF;
    
    IF NOT (OLD.cambio_fecha_fin <=> NEW.cambio_fecha_fin) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'cambio_fecha_fin', OLD.cambio_fecha_fin, NEW.cambio_fecha_fin, NOW());
    END IF;
    
    IF NOT (OLD.nuevo_aux_alimentacion <=> NEW.nuevo_aux_alimentacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'nuevo_aux_alimentacion', OLD.nuevo_aux_alimentacion, NEW.nuevo_aux_alimentacion, NOW());
    END IF;
    
    IF NOT (OLD.nuevo_aux_transporte <=> NEW.nuevo_aux_transporte) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'nuevo_aux_transporte', OLD.nuevo_aux_transporte, NEW.nuevo_aux_transporte, NOW());
    END IF;
    
    IF NOT (OLD.nuevo_rodamiento <=> NEW.nuevo_rodamiento) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'nuevo_rodamiento', OLD.nuevo_rodamiento, NEW.nuevo_rodamiento, NOW());
    END IF;
    
    IF NOT (OLD.nuevo_turno <=> NEW.nuevo_turno) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo, fecha)
        VALUES (v_usuario, 'Actualización', 'contratos_modificaciones', OLD.id_modificacion, 'nuevo_turno', OLD.nuevo_turno, NEW.nuevo_turno, NOW());
    END IF;

END//

DELIMITER ;


-- ##############################################################################################################################################################################################

-- Triggers actualizar tablas de talento humano
-- ==================================================================================================
-- TRIGGER 1: AUDITORÍA - INSERT en contratos_modificaciones
-- ==================================================================================================

DROP TRIGGER IF EXISTS trg_auditoria_insert_contratos_modificaciones;

DELIMITER //

CREATE TRIGGER trg_auditoria_insert_contratos_modificaciones
AFTER INSERT ON contratos_modificaciones
FOR EACH ROW
BEGIN
    -- Fijar el usuario para la auditoría (ya viene del SP)
    SET @usuario_actual = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la inserción (sin incluir fecha, usa DEFAULT CURRENT_TIMESTAMP)
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (
        @usuario_actual,
        'Inserción',
        'contratos_modificaciones',
        CAST(NEW.id_modificacion AS CHAR),
        'All',
        'N/A',
        'Fila Creada'
    );
END//

DELIMITER ;

DELIMITER ;

-- ==================================================================================================
-- TRIGGER 2: AUDITORÍA - UPDATE en contratos
-- ==================================================================================================

DROP TRIGGER IF EXISTS trg_auditoria_update_contratos;


DELIMITER //

CREATE TRIGGER trg_auditoria_update_contratos
AFTER UPDATE ON contratos
FOR EACH ROW
BEGIN
    -- Fijar el usuario para la auditoría (ya viene del SP)
    SET @usuario_actual = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Auditar cambios en fecha_ingreso (DATE)
    IF COALESCE(OLD.fecha_ingreso, '1900-01-01') <> COALESCE(NEW.fecha_ingreso, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'fecha_ingreso',
            CAST(COALESCE(OLD.fecha_ingreso, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.fecha_ingreso, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en tipo_contrato (ENUM)
    IF COALESCE(OLD.tipo_contrato, '') <> COALESCE(NEW.tipo_contrato, '') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'tipo_contrato',
            COALESCE(OLD.tipo_contrato, 'NULL'),
            COALESCE(NEW.tipo_contrato, 'NULL')
        );
    END IF;
    
    -- Auditar cambios en termino_meses (DATE)
    IF COALESCE(OLD.termino_meses, '1900-01-01') <> COALESCE(NEW.termino_meses, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'termino_meses',
            CAST(COALESCE(OLD.termino_meses, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.termino_meses, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en forma_pago (ENUM)
    IF COALESCE(OLD.forma_pago, '') <> COALESCE(NEW.forma_pago, '') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'forma_pago',
            COALESCE(OLD.forma_pago, 'NULL'),
            COALESCE(NEW.forma_pago, 'NULL')
        );
    END IF;
    
    -- Auditar cambios en id_centro_costo (INT)
    IF COALESCE(OLD.id_centro_costo, 0) <> COALESCE(NEW.id_centro_costo, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'id_centro_costo',
            CAST(COALESCE(OLD.id_centro_costo, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.id_centro_costo, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en salario_base (DECIMAL)
    IF COALESCE(OLD.salario_base, 0) <> COALESCE(NEW.salario_base, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'salario_base',
            CAST(COALESCE(OLD.salario_base, 0) AS CHAR),
            CAST(COALESCE(NEW.salario_base, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en aux_alimentacion (DECIMAL)
    IF COALESCE(OLD.aux_alimentacion, 0) <> COALESCE(NEW.aux_alimentacion, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'aux_alimentacion',
            CAST(COALESCE(OLD.aux_alimentacion, 0) AS CHAR),
            CAST(COALESCE(NEW.aux_alimentacion, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en aux_transporte (DECIMAL)
    IF COALESCE(OLD.aux_transporte, 0) <> COALESCE(NEW.aux_transporte, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'aux_transporte',
            CAST(COALESCE(OLD.aux_transporte, 0) AS CHAR),
            CAST(COALESCE(NEW.aux_transporte, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en salario_integral (TINYINT)
    IF COALESCE(OLD.salario_integral, 0) <> COALESCE(NEW.salario_integral, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'salario_integral',
            CAST(COALESCE(OLD.salario_integral, 0) AS CHAR),
            CAST(COALESCE(NEW.salario_integral, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en rodamiento (DECIMAL)
    IF COALESCE(OLD.rodamiento, 0) <> COALESCE(NEW.rodamiento, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'rodamiento',
            CAST(COALESCE(OLD.rodamiento, 0) AS CHAR),
            CAST(COALESCE(NEW.rodamiento, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en turno (VARCHAR)
    IF COALESCE(OLD.turno, '') <> COALESCE(NEW.turno, '') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'turno',
            COALESCE(OLD.turno, 'NULL'),
            COALESCE(NEW.turno, 'NULL')
        );
    END IF;
    
    -- Auditar cambios en contrato (TINYINT)
    IF COALESCE(OLD.contrato, 0) <> COALESCE(NEW.contrato, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'contrato',
            CAST(COALESCE(OLD.contrato, 0) AS CHAR),
            CAST(COALESCE(NEW.contrato, 0) AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en fecha_afiliacion_arl (DATE)
    IF COALESCE(OLD.fecha_afiliacion_arl, '1900-01-01') <> COALESCE(NEW.fecha_afiliacion_arl, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'fecha_afiliacion_arl',
            CAST(COALESCE(OLD.fecha_afiliacion_arl, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.fecha_afiliacion_arl, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en fecha_afiliacion_eps (DATE)
    IF COALESCE(OLD.fecha_afiliacion_eps, '1900-01-01') <> COALESCE(NEW.fecha_afiliacion_eps, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'fecha_afiliacion_eps',
            CAST(COALESCE(OLD.fecha_afiliacion_eps, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.fecha_afiliacion_eps, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en fecha_afiliacion_ccf (DATE)
    IF COALESCE(OLD.fecha_afiliacion_ccf, '1900-01-01') <> COALESCE(NEW.fecha_afiliacion_ccf, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'fecha_afiliacion_ccf',
            CAST(COALESCE(OLD.fecha_afiliacion_ccf, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.fecha_afiliacion_ccf, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en num_ultimo_otro_si (INT)
    IF COALESCE(OLD.num_ultimo_otro_si, 0) <> COALESCE(NEW.num_ultimo_otro_si, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'num_ultimo_otro_si',
            CAST(COALESCE(OLD.num_ultimo_otro_si, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.num_ultimo_otro_si, 'NULL') AS CHAR)
        );
    END IF;
    
    -- Auditar cambios en dias_pp (INT)
    IF COALESCE(OLD.dias_pp, 0) <> COALESCE(NEW.dias_pp, 0) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'contratos',
            CAST(NEW.id_contrato AS CHAR),
            'dias_pp',
            CAST(COALESCE(OLD.dias_pp, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.dias_pp, 'NULL') AS CHAR)
        );
    END IF;
    
END//

DELIMITER ;

-- ==================================================================================================
-- TRIGGER 3: AUDITORÍA - DELETE en contratos_modificaciones
-- ==================================================================================================

DROP TRIGGER IF EXISTS trg_auditoria_delete_contratos_modificaciones;

DELIMITER //

CREATE TRIGGER trg_auditoria_delete_contratos_modificaciones
AFTER DELETE ON contratos_modificaciones
FOR EACH ROW
BEGIN
    -- Fijar el usuario para la auditoría (ya viene del SP)
    SET @usuario_actual = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la eliminación (sin incluir fecha, usa DEFAULT CURRENT_TIMESTAMP)
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (
        @usuario_actual,
        'Eliminación',
        'contratos_modificaciones',
        CAST(OLD.id_modificacion AS CHAR),
        'All',
        'Fila Eliminada',
        'N/A'
    );
END//

DELIMITER ;


-- Trigger de actualizacion o eliminacion beneficiarios colaborador
-- ==================================================================================================
-- TRIGGER 1: AUDITORÍA - UPDATE en beneficiarios
-- ==================================================================================================

DROP TRIGGER IF EXISTS trg_auditoria_update_beneficiarios;

DELIMITER //

CREATE TRIGGER trg_auditoria_update_beneficiarios
AFTER UPDATE ON beneficiarios
FOR EACH ROW
BEGIN
    -- Fijar el usuario para la auditoría (ya viene del SP)
    SET @usuario_actual = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Auditar cambios en nombre (VARCHAR)
    IF COALESCE(OLD.nombre, '') <> COALESCE(NEW.nombre, '') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'beneficiarios',
            CAST(NEW.id_beneficiario AS CHAR),
            'nombre',
            COALESCE(OLD.nombre, 'NULL'),
            COALESCE(NEW.nombre, 'NULL')
        );
    END IF;
    
    -- Auditar cambios en genero (ENUM)
    IF COALESCE(OLD.genero, '') <> COALESCE(NEW.genero, '') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'beneficiarios',
            CAST(NEW.id_beneficiario AS CHAR),
            'genero',
            COALESCE(OLD.genero, 'NULL'),
            COALESCE(NEW.genero, 'NULL')
        );
    END IF;
    
    -- Auditar cambios en fecha_nacimiento (DATE)
    IF COALESCE(OLD.fecha_nacimiento, '1900-01-01') <> COALESCE(NEW.fecha_nacimiento, '1900-01-01') THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (
            @usuario_actual,
            'Actualización',
            'beneficiarios',
            CAST(NEW.id_beneficiario AS CHAR),
            'fecha_nacimiento',
            CAST(COALESCE(OLD.fecha_nacimiento, 'NULL') AS CHAR),
            CAST(COALESCE(NEW.fecha_nacimiento, 'NULL') AS CHAR)
        );
    END IF;
END//

DELIMITER ;

-- ==================================================================================================
-- TRIGGER 2: AUDITORÍA - DELETE en beneficiarios
-- ==================================================================================================

DROP TRIGGER IF EXISTS trg_auditoria_delete_beneficiarios;

DELIMITER //

CREATE TRIGGER trg_auditoria_delete_beneficiarios
AFTER DELETE ON beneficiarios
FOR EACH ROW
BEGIN
    -- Fijar el usuario para la auditoría (ya viene del SP)
    SET @usuario_actual = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la eliminación (sin incluir fecha, usa DEFAULT CURRENT_TIMESTAMP)
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (
        @usuario_actual,
        'Eliminación',
        'beneficiarios',
        CAST(OLD.id_beneficiario AS CHAR),
        'All',
        'Fila Eliminada',
        'N/A'
    );
END//

DELIMITER ;


-- Tirgger de actualizacion tabla tallas_dotacion de Colaboradores
DROP TRIGGER IF EXISTS tr_auditoria_actualizar_talla_dotacion;

DELIMITER //

CREATE TRIGGER tr_auditoria_actualizar_talla_dotacion
AFTER UPDATE ON tallas_dotacion
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar cambio en talla_pantalon
    IF OLD.talla_pantalon <> NEW.talla_pantalon OR (OLD.talla_pantalon IS NULL AND NEW.talla_pantalon IS NOT NULL) OR (OLD.talla_pantalon IS NOT NULL AND NEW.talla_pantalon IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tallas_dotacion', NEW.id_talla, 'talla_pantalon', COALESCE(OLD.talla_pantalon, 'NULL'), COALESCE(NEW.talla_pantalon, 'NULL'));
    END IF;
    
    -- Registrar cambio en talla_camisa
    IF OLD.talla_camisa <> NEW.talla_camisa OR (OLD.talla_camisa IS NULL AND NEW.talla_camisa IS NOT NULL) OR (OLD.talla_camisa IS NOT NULL AND NEW.talla_camisa IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tallas_dotacion', NEW.id_talla, 'talla_camisa', COALESCE(OLD.talla_camisa, 'NULL'), COALESCE(NEW.talla_camisa, 'NULL'));
    END IF;
    
    -- Registrar cambio en talla_botas
    IF OLD.talla_botas <> NEW.talla_botas OR (OLD.talla_botas IS NULL AND NEW.talla_botas IS NOT NULL) OR (OLD.talla_botas IS NOT NULL AND NEW.talla_botas IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tallas_dotacion', NEW.id_talla, 'talla_botas', COALESCE(OLD.talla_botas, 'NULL'), COALESCE(NEW.talla_botas, 'NULL'));
    END IF;

END//

DELIMITER ;

-- Trigger de actualizacion de tabla de datos bancarios de colaboradores
DROP TRIGGER IF EXISTS tr_auditoria_actualizar_cuenta_bancaria;

DELIMITER //

CREATE TRIGGER tr_auditoria_actualizar_cuenta_bancaria
AFTER UPDATE ON cuentas_bancarias_colaboradores
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar cambio en banco_id
    IF OLD.banco_id <> NEW.banco_id THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'cuentas_bancarias_colaboradores', NEW.cuenta_id, 'banco_id', OLD.banco_id, NEW.banco_id);
    END IF;
    
    -- Registrar cambio en tipo_cuenta
    IF OLD.tipo_cuenta <> NEW.tipo_cuenta OR (OLD.tipo_cuenta IS NULL AND NEW.tipo_cuenta IS NOT NULL) OR (OLD.tipo_cuenta IS NOT NULL AND NEW.tipo_cuenta IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'cuentas_bancarias_colaboradores', NEW.cuenta_id, 'tipo_cuenta', COALESCE(OLD.tipo_cuenta, 'NULL'), COALESCE(NEW.tipo_cuenta, 'NULL'));
    END IF;
    
    -- Registrar cambio en num_cuenta
    IF OLD.num_cuenta <> NEW.num_cuenta THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'cuentas_bancarias_colaboradores', NEW.cuenta_id, 'num_cuenta', OLD.num_cuenta, NEW.num_cuenta);
    END IF;
    
    -- Registrar cambio en cta_contable_banco
    IF OLD.cta_contable_banco <> NEW.cta_contable_banco OR (OLD.cta_contable_banco IS NULL AND NEW.cta_contable_banco IS NOT NULL) OR (OLD.cta_contable_banco IS NOT NULL AND NEW.cta_contable_banco IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'cuentas_bancarias_colaboradores', NEW.cuenta_id, 'cta_contable_banco', COALESCE(OLD.cta_contable_banco, 'NULL'), COALESCE(NEW.cta_contable_banco, 'NULL'));
    END IF;

END//

DELIMITER ;

-- trigger por eliminación de registro en la tabla de datos bancarios de los colaboradores
DROP TRIGGER IF EXISTS tr_auditoria_eliminar_cuenta_bancaria;

DELIMITER //

CREATE TRIGGER tr_auditoria_eliminar_cuenta_bancaria
BEFORE DELETE ON cuentas_bancarias_colaboradores
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la eliminación del registro completo
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Eliminación', 'cuentas_bancarias_colaboradores', OLD.cuenta_id, 'REGISTRO COMPLETO', 
            CONCAT('banco_id:', OLD.banco_id, '|tipo_cuenta:', OLD.tipo_cuenta, '|num_cuenta:', OLD.num_cuenta, '|cta_contable_banco:', OLD.cta_contable_banco),
            'ELIMINADO');

END//

DELIMITER ;

-- Trigger para eliminar registro de tallas de dotacion de un colaborador
DROP TRIGGER IF EXISTS tr_auditoria_eliminar_talla_dotacion;

DELIMITER //

CREATE TRIGGER tr_auditoria_eliminar_talla_dotacion
BEFORE DELETE ON tallas_dotacion
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la eliminación del registro completo
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Eliminación', 'tallas_dotacion', OLD.id_talla, 'REGISTRO COMPLETO', 
            CONCAT('talla_pantalon:', OLD.talla_pantalon, '|talla_camisa:', OLD.talla_camisa, '|talla_botas:', OLD.talla_botas),
            'ELIMINADO');

END//

DELIMITER ;

-- trigger de Insercion Tallas colaborador
DROP TRIGGER IF EXISTS tr_auditoria_insertar_talla_dotacion;

DELIMITER //

CREATE TRIGGER tr_auditoria_insertar_talla_dotacion
AFTER INSERT ON tallas_dotacion
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');
    
    -- Registrar la inserción del registro
    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
    VALUES (v_usuario, 'Inserción', 'tallas_dotacion', NEW.id_talla, 'REGISTRO COMPLETO', 
            'NULL', 
            CONCAT('talla_pantalon:', NEW.talla_pantalon, '|talla_camisa:', NEW.talla_camisa, '|talla_botas:', NEW.talla_botas));

END//

DELIMITER ;


-- Trigger de Inserción en tabla Inactividades
DROP TRIGGER IF EXISTS tr_auditoria_insertar_inactividad;

DELIMITER //

CREATE TRIGGER tr_auditoria_insertar_inactividad
AFTER INSERT ON tbl_inactividades
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);

    -- Usuario de sesión o SISTEMA
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');

    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    )
    VALUES (
        v_usuario,
        'Inserción',
        'tbl_inactividades',
        NEW.id_inactividad,
        'REGISTRO COMPLETO',
        'NULL',
        CONCAT(
            'id_colaborador:', NEW.id_colaborador,
            '|tipo_inactividad:', NEW.tipo_inactividad,
            '|fecha_inicio:', NEW.fecha_inicio,
            '|fecha_fin:', IFNULL(NEW.fecha_fin, 'NULL'),
            '|observaciones:', IFNULL(NEW.observaciones, 'NULL')
        )
    );
END//

DELIMITER ;


-- Trigger de Inserción en Colaboradores retirados
DROP TRIGGER IF EXISTS tr_auditoria_insertar_retiro;

DELIMITER //

CREATE TRIGGER tr_auditoria_insertar_retiro
AFTER INSERT ON colaboradores_retirados
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);

    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');

    INSERT INTO auditoria (
        usuario,
        evento,
        tabla_afectada,
        registro_id,
        campo_afectado,
        valor_anterior,
        valor_nuevo
    )
    VALUES (
        v_usuario,
        'Inserción',
        'colaboradores_retirados',
        NEW.id_retiro,
        'REGISTRO COMPLETO',
        'NULL',
        CONCAT(
            'id_colaborador:', NEW.id_colaborador,
            '|fecha_retiro:', NEW.fecha_retiro,
            '|motivo:', NEW.motivo,
            '|detalles:', IFNULL(NEW.detalles, 'NULL'),
            '|paz_salvo:', IFNULL(NEW.paz_salvo, 'NULL')
        )
    );
END//

DELIMITER ;

-- Trigger de actualizacion de registro en tabla tbl_inactividad
DROP TRIGGER IF EXISTS tr_auditoria_actualizar_inactividad;
DELIMITER //

CREATE TRIGGER tr_auditoria_actualizar_inactividad
AFTER UPDATE ON tbl_inactividades
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);

    -- Obtener el usuario de la variable de sesión
    SET v_usuario = COALESCE(@usuario_actual, 'SISTEMA');

    -- id_colaborador
    IF OLD.id_colaborador <> NEW.id_colaborador THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'id_colaborador',
                OLD.id_colaborador, NEW.id_colaborador);
    END IF;

    -- tipo_inactividad
    IF OLD.tipo_inactividad <> NEW.tipo_inactividad
       OR (OLD.tipo_inactividad IS NULL AND NEW.tipo_inactividad IS NOT NULL)
       OR (OLD.tipo_inactividad IS NOT NULL AND NEW.tipo_inactividad IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'tipo_inactividad',
                COALESCE(OLD.tipo_inactividad, 'NULL'),
                COALESCE(NEW.tipo_inactividad, 'NULL'));
    END IF;

    -- fecha_inicio
    IF OLD.fecha_inicio <> NEW.fecha_inicio
       OR (OLD.fecha_inicio IS NULL AND NEW.fecha_inicio IS NOT NULL)
       OR (OLD.fecha_inicio IS NOT NULL AND NEW.fecha_inicio IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'fecha_inicio',
                COALESCE(OLD.fecha_inicio, 'NULL'),
                COALESCE(NEW.fecha_inicio, 'NULL'));
    END IF;

    -- fecha_fin
    IF OLD.fecha_fin <> NEW.fecha_fin
       OR (OLD.fecha_fin IS NULL AND NEW.fecha_fin IS NOT NULL)
       OR (OLD.fecha_fin IS NOT NULL AND NEW.fecha_fin IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'fecha_fin',
                COALESCE(OLD.fecha_fin, 'NULL'),
                COALESCE(NEW.fecha_fin, 'NULL'));
    END IF;

    -- observaciones
    IF OLD.observaciones <> NEW.observaciones
       OR (OLD.observaciones IS NULL AND NEW.observaciones IS NOT NULL)
       OR (OLD.observaciones IS NOT NULL AND NEW.observaciones IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'observaciones',
                COALESCE(OLD.observaciones, 'NULL'),
                COALESCE(NEW.observaciones, 'NULL'));
    END IF;

    -- estado_actual
    IF OLD.estado_actual <> NEW.estado_actual
       OR (OLD.estado_actual IS NULL AND NEW.estado_actual IS NOT NULL)
       OR (OLD.estado_actual IS NOT NULL AND NEW.estado_actual IS NULL) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tbl_inactividades',
                NEW.id_inactividad, 'estado_actual',
                COALESCE(OLD.estado_actual, 'NULL'),
                COALESCE(NEW.estado_actual, 'NULL'));
    END IF;

END//

DELIMITER ;

-- Triggers insercion y actualizacion tarifas deprisa PxH
DELIMITER //

-- ======================================================
-- 1. TRIGGER DE INSERCIÓN (Nuevos registros)
-- ======================================================
DROP TRIGGER IF EXISTS trg_tarifas_pxh_insert //

CREATE TRIGGER trg_tarifas_pxh_insert
AFTER INSERT ON tarifas_deprisa_PXH
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    -- Intentar obtener el usuario de la variable de sesión, si no existe, usar 'Sistema'
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    INSERT INTO auditoria (
        usuario, 
        evento, 
        tabla_afectada, 
        registro_id, 
        valor_nuevo
    ) VALUES (
        v_usuario,
        'Inserción',
        'tarifas_deprisa_PXH',
        CAST(NEW.tarifa_id AS CHAR),
        CONCAT('Nueva Tarifa: ', NEW.tipo, ' - ', NEW.estructura, ' - ', NEW.modelo, ' - Valor: ', NEW.valor)
    );
END //

DELIMITER //

-- INSERT TRIGGER
DROP TRIGGER IF EXISTS trg_tarifas_pxq_insert //
CREATE TRIGGER trg_tarifas_pxq_insert
AFTER INSERT ON tarifas_deprisa_PXQ
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, valor_nuevo)
    VALUES (v_usuario, 'Inserción', 'tarifas_deprisa_PXQ', CAST(NEW.tarifa_id AS CHAR), 
            CONCAT('Nueva PXQ: ', NEW.tipo, ' - ', NEW.modelo, ' - Ent: ', IFNULL(NEW.entrega,0), ' - Rec: ', IFNULL(NEW.recoleccion,0)));
END //

-- UPDATE TRIGGER
DROP TRIGGER IF EXISTS trg_tarifas_pxq_update //
CREATE TRIGGER trg_tarifas_pxq_update
AFTER UPDATE ON tarifas_deprisa_PXQ
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    IF NOT (OLD.tipo <=> NEW.tipo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'tipo', OLD.tipo, NEW.tipo); END IF;
    IF NOT (OLD.estructura <=> NEW.estructura) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'estructura', OLD.estructura, NEW.estructura); END IF;
    IF NOT (OLD.modelo <=> NEW.modelo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'modelo', OLD.modelo, NEW.modelo); END IF;
    IF NOT (OLD.base <=> NEW.base) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'base', OLD.base, NEW.base); END IF;
    IF NOT (OLD.base_corta <=> NEW.base_corta) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'base_corta', OLD.base_corta, NEW.base_corta); END IF;
    IF NOT (OLD.poblacion <=> NEW.poblacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'poblacion', OLD.poblacion, NEW.poblacion); END IF;
    IF NOT (OLD.entrega <=> NEW.entrega) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'entrega', OLD.entrega, NEW.entrega); END IF;
    IF NOT (OLD.recoleccion <=> NEW.recoleccion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'recoleccion', OLD.recoleccion, NEW.recoleccion); END IF;
    IF NOT (OLD.vigencia <=> NEW.vigencia) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo) VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXQ', NEW.tarifa_id, 'vigencia', OLD.vigencia, NEW.vigencia); END IF;
END //
DELIMITER ;



-- ======================================================
-- 2. TRIGGER DE ACTUALIZACIÓN (Cambios campo por campo)
-- ======================================================
DELIMITER //

DROP TRIGGER IF EXISTS trg_tarifas_pxh_update //

CREATE TRIGGER trg_tarifas_pxh_update
AFTER UPDATE ON tarifas_deprisa_PXH
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    -- Comparar TIPO
    IF NOT (OLD.tipo <=> NEW.tipo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'tipo', OLD.tipo, NEW.tipo);
    END IF;

    -- Comparar ESTRUCTURA
    IF NOT (OLD.estructura <=> NEW.estructura) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'estructura', OLD.estructura, NEW.estructura);
    END IF;

    -- Comparar MODELO
    IF NOT (OLD.modelo <=> NEW.modelo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'modelo', OLD.modelo, NEW.modelo);
    END IF;

    -- Comparar BASE
    IF NOT (OLD.base <=> NEW.base) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'base', CAST(OLD.base AS CHAR), CAST(NEW.base AS CHAR));
    END IF;

    -- Comparar TONELAJE
    IF NOT (OLD.tonelaje <=> NEW.tonelaje) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'tonelaje', CAST(OLD.tonelaje AS CHAR), CAST(NEW.tonelaje AS CHAR));
    END IF;

    -- Comparar VALOR
    IF NOT (OLD.valor <=> NEW.valor) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'valor', CAST(OLD.valor AS CHAR), CAST(NEW.valor AS CHAR));
    END IF;

    -- Comparar AUXILIAR
    IF NOT (OLD.auxiliar <=> NEW.auxiliar) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'auxiliar', CAST(OLD.auxiliar AS CHAR), CAST(NEW.auxiliar AS CHAR));
    END IF;

    -- Comparar VIGENCIA
    IF NOT (OLD.vigencia <=> NEW.vigencia) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_deprisa_PXH', CAST(NEW.tarifa_id AS CHAR), 'vigencia', CAST(OLD.vigencia AS CHAR), CAST(NEW.vigencia AS CHAR));
    END IF;

END //

DELIMITER ;



DELIMITER //

DROP TRIGGER IF EXISTS trg_parametros_empresa_insert //

CREATE TRIGGER trg_parametros_empresa_insert
AFTER INSERT ON parametros_empresa
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, valor_nuevo)
    VALUES (v_usuario, 'Inserción', 'parametros_empresa', CAST(NEW.id_parametro AS CHAR), 
            CONCAT('Nuevo Parametro: ', NEW.nombre_parametro, ' - Valor: ', NEW.valor_parametro));
END //

DROP TRIGGER IF EXISTS trg_parametros_empresa_update //

CREATE TRIGGER trg_parametros_empresa_update
AFTER UPDATE ON parametros_empresa
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    -- Comparar NOMBRE
    IF NOT (OLD.nombre_parametro <=> NEW.nombre_parametro) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'parametros_empresa', CAST(NEW.id_parametro AS CHAR), 'nombre_parametro', OLD.nombre_parametro, NEW.nombre_parametro);
    END IF;

    -- Comparar VALOR
    IF NOT (OLD.valor_parametro <=> NEW.valor_parametro) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'parametros_empresa', CAST(NEW.id_parametro AS CHAR), 'valor_parametro', CAST(OLD.valor_parametro AS CHAR), CAST(NEW.valor_parametro AS CHAR));
    END IF;

    -- Comparar DESCRIPCION
    IF NOT (OLD.descripcion <=> NEW.descripcion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'parametros_empresa', CAST(NEW.id_parametro AS CHAR), 'descripcion', OLD.descripcion, NEW.descripcion);
    END IF;

END //

DELIMITER ;


-- Trigger parametros Tarifas Mensuales

DELIMITER //

-- INSERT
DROP TRIGGER IF EXISTS trg_tarifas_mensuales_insert //

CREATE TRIGGER trg_tarifas_mensuales_insert
AFTER INSERT ON tarifas_mensuales
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, valor_nuevo)
    VALUES (v_usuario, 'Inserción', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 
            CONCAT('Nueva Tarifa M.: Sector ', IFNULL(NEW.sector,'N/A'), ' - Cobro: ', IFNULL(NEW.valor_cobro,0)));
END //

-- UPDATE
DROP TRIGGER IF EXISTS trg_tarifas_mensuales_update //

CREATE TRIGGER trg_tarifas_mensuales_update
AFTER UPDATE ON tarifas_mensuales
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    -- Sector
    IF NOT (OLD.sector <=> NEW.sector) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 'sector', OLD.sector, NEW.sector);
    END IF;

    -- Estacion
    IF NOT (OLD.estacion <=> NEW.estacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 'estacion', CAST(OLD.estacion AS CHAR), CAST(NEW.estacion AS CHAR));
    END IF;

    -- Ciudad/Poblacion
    IF NOT (OLD.ciudad_poblacion <=> NEW.ciudad_poblacion) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 'ciudad_poblacion', CAST(OLD.ciudad_poblacion AS CHAR), CAST(NEW.ciudad_poblacion AS CHAR));
    END IF;

    -- Valor Cobro
    IF NOT (OLD.valor_cobro <=> NEW.valor_cobro) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 'valor_cobro', CAST(OLD.valor_cobro AS CHAR), CAST(NEW.valor_cobro AS CHAR));
    END IF;
    
    -- Valor Pago
    IF NOT (OLD.valor_pago <=> NEW.valor_pago) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'tarifas_mensuales', CAST(NEW.id AS CHAR), 'valor_pago', CAST(OLD.valor_pago AS CHAR), CAST(NEW.valor_pago AS CHAR));
    END IF;

END //

DELIMITER ;


-- Trigger metodos de pago

DELIMITER //

-- INSERT
DROP TRIGGER IF EXISTS trg_metodo_pago_insert //

CREATE TRIGGER trg_metodo_pago_insert
AFTER INSERT ON metodo_pago
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, valor_nuevo)
    VALUES (v_usuario, 'Inserción', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 
            CONCAT('Nuevo Metodo: Modelo ', NEW.modelo, ' - Pago: ', IFNULL(NEW.metodo_pago,'N/A')));
END //

-- UPDATE
DROP TRIGGER IF EXISTS trg_metodo_pago_update //

CREATE TRIGGER trg_metodo_pago_update
AFTER UPDATE ON metodo_pago
FOR EACH ROW
BEGIN
    DECLARE v_usuario VARCHAR(100);
    SET v_usuario = IFNULL(@usuario_actual, SUBSTRING_INDEX(USER(),'@',1));

    -- Comparar campos
    IF NOT (OLD.id_ciudad <=> NEW.id_ciudad) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'id_ciudad', CAST(OLD.id_ciudad AS CHAR), CAST(NEW.id_ciudad AS CHAR)); END IF;

    IF NOT (OLD.sector <=> NEW.sector) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'sector', OLD.sector, NEW.sector); END IF;

    IF NOT (OLD.modelo <=> NEW.modelo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'modelo', OLD.modelo, NEW.modelo); END IF;

    IF NOT (OLD.concepto <=> NEW.concepto) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'concepto', OLD.concepto, NEW.concepto); END IF;

    IF NOT (OLD.metodo_pago <=> NEW.metodo_pago) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'metodo_pago', OLD.metodo_pago, NEW.metodo_pago); END IF;
        
    IF NOT (OLD.vehiculo <=> NEW.vehiculo) THEN
        INSERT INTO auditoria (usuario, evento, tabla_afectada, registro_id, campo_afectado, valor_anterior, valor_nuevo)
        VALUES (v_usuario, 'Actualización', 'metodo_pago', CAST(NEW.id_metodo AS CHAR), 'vehiculo', OLD.vehiculo, NEW.vehiculo); END IF;

END //

DELIMITER ;








