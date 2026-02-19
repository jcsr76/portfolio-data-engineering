-- script que genera los grant EXECUTE y SELECT para todos los usuarios de un departamento usando las tablas usuarios y permisos_departamento_objetos
-- Se copia el resultado a archivo Excel para ejecutar desde Python

-- Genrar listado de permisos para usurio

SELECT 
    CONCAT(
        'GRANT ', p.tipo_permiso,
        ' ON ',
           IF(p.tipo_objeto='PROCEDIMIENTO',
               CONCAT('PROCEDURE pypdb.', '`', p.nombre_objeto, '`'),
               CONCAT('pypdb.',             '`', p.nombre_objeto, '`')
           ),
        ' TO ''', u.usuario, '''@''', h.host, ''';'
    ) AS grant_stmt
FROM usuarios u
JOIN permisos_departamento_objetos p
  ON u.departamento = p.departamento_id
-- Se añade el nuevo segmento de red para la VPN
CROSS JOIN (
    SELECT '192.168.0.%' AS host
    UNION ALL
    SELECT '192.168.100.%'
    UNION ALL
    SELECT '192.168.101.%'
) h
WHERE u.departamento = 6
AND
p.nombre_objeto = 'sp_insertar_pernocte_flota_propia'
ORDER BY u.usuario, p.tipo_objeto, p.nombre_objeto, h.host
LIMIT 500000;




SELECT 
    CONCAT(
        'GRANT ', p.tipo_permiso,
        ' ON ',
           IF(p.tipo_objeto = 'PROCEDIMIENTO',
               CONCAT('PROCEDURE pypdb.', '`', p.nombre_objeto, '`'),
               CONCAT('pypdb.', '`', p.nombre_objeto, '`')
           ),
        ' TO ''', u.usuario, '''@''', h.host, ''';'
    ) AS grant_stmt
FROM usuarios u
JOIN permisos_departamento_objetos p
  ON u.departamento = p.departamento_id
-- Se añade el nuevo segmento de red para la VPN
CROSS JOIN (
    SELECT '192.168.0.%' AS host
    UNION ALL
    SELECT '192.168.100.%'
    UNION ALL
    SELECT '192.168.101.%'
) h
WHERE u.departamento = 3
  AND p.nombre_objeto = 'insertar_operacion_completa'
ORDER BY u.usuario, p.tipo_objeto, p.nombre_objeto, h.host
LIMIT 50000;


-- Generar listado de Permisos para usuario Talento humano

SELECT 
    CONCAT(
        'GRANT ', p.tipo_permiso,
        ' ON ',
           IF(p.tipo_objeto='PROCEDIMIENTO',
               CONCAT('PROCEDURE pypdb.', '`', p.nombre_objeto, '`'),
               CONCAT('pypdb.',             '`', p.nombre_objeto, '`')
           ),
        ' TO ''', u.usuario, '''@''', h.host, ''';'
    ) AS grant_stmt
FROM usuarios u
JOIN permisos_departamento_objetos p
  ON u.departamento = p.departamento_id
-- Se añade el nuevo segmento de red para la VPN
CROSS JOIN (
    SELECT '192.168.0.%' AS host
    UNION ALL
    SELECT '192.168.100.%'
    UNION ALL
    SELECT '192.168.101.%'
) h
WHERE u.departamento = 6 AND u.usuario = 'cifuentesj'
ORDER BY u.usuario, p.tipo_objeto, p.nombre_objeto, h.host
LIMIT 50000;
