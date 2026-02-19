-- funcion para remover tides
DELIMITER //

CREATE FUNCTION remove_accents(texto VARCHAR(255)) RETURNS VARCHAR(255) DETERMINISTIC
RETURN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       texto, 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'),
       'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U');
END//

DELIMITER ;

-- función para convertir las ñ en n
DELIMITER //

CREATE FUNCTION reemplazar_ene_ene(texto VARCHAR(500))
RETURNS VARCHAR(500)
DETERMINISTIC
BEGIN
    RETURN REPLACE(
             REPLACE(texto, 'ñ', 'n'),
             'Ñ', 'N'
           );
END//

DELIMITER ;


