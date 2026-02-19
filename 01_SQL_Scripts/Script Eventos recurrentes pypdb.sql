
-- ############ Evento para borrar registros con 30 dias o mas de antigüedad de la tabla auditoria generados por ETL de python #########
DELIMITER //

CREATE EVENT IF NOT EXISTS ev_purgar_auditoria_30dias
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY)
DO
BEGIN
  DELETE FROM auditoria
  WHERE usuario = 'python_user'
    AND fecha < (NOW() - INTERVAL 30 DAY);
END//

DELIMITER ;
-- consultar estatus del evento programado
SHOW EVENTS LIKE 'ev_purgar_auditoria_30dias';



-- ############################# Evento de liquidacion diaria y calculo de valores ####################################################

-- ****** No está creado, apenas se cree borrar este comentario ********

DROP EVENT IF EXISTS evento_Liquidacion_Diaria;

DELIMITER //

CREATE EVENT evento_Liquidacion_Diaria
ON SCHEDULE
    EVERY 1 DAY
    STARTS TIMESTAMP(CURRENT_DATE, '11:30:00')   -- 11:30 UTC = 06:30 Colombia (UTC-5)
DO
BEGIN
    CALL sp_ActualizarTotalCobroPxH();
    CALL actualizar_total_cobro_PxQ();
    CALL sp_actualizar_total_cobro_entrega();
    CALL actualizar_total_cobro_mensualidad();
    CALL sp_ActualizarCobroAuxiliar();
    CALL sp_CalcularCobroSinAuxiliar();
    CALL sp_ActualizarTotalTurno();
    CALL actualizar_total_turno_terceros();
    CALL sp_actualizar_total_turno_entrega();
END //

DELIMITER ;
