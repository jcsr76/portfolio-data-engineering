-- Creación de vistas
CREATE OR REPLACE VIEW vista_auditoria AS
SELECT
    id_auditoria,
    usuario,
    evento,
    tabla_afectada,
    registro_id,
    campo_afectado,
    valor_anterior,
    valor_nuevo,
    CONVERT_TZ(fecha, 'UTC', 'America/Bogota') AS fecha
FROM auditoria;


CREATE OR REPLACE VIEW vista_auxiliares_terceros AS
SELECT * FROM auxiliares_terceros;

CREATE OR REPLACE VIEW vista_bancos AS
SELECT * FROM bancos;

CREATE OR REPLACE VIEW vista_bases AS
SELECT * FROM bases;

CREATE OR REPLACE VIEW vista_bases_deprisa AS
SELECT * FROM bases_deprisa;

CREATE OR REPLACE VIEW vista_proveedores_motos_terceros AS
SELECT * FROM proveedores_motos_terceros;

CREATE OR REPLACE VIEW vista_motos_motocarros_terceros AS
SELECT * FROM motos_motocarros_terceros;

CREATE OR REPLACE VIEW vista_moto_persona_tercero AS
SELECT * FROM moto_persona_tercero;

CREATE OR REPLACE VIEW vista_motos_con_personas AS
SELECT 
    m.id_vehiculo,
    m.placa,
    m.tipo AS tipo_vehiculo,
    m.marca,
    m.modelo,
    m.anio,
    m.id_base,
    m.capacidad,
    m.estado AS estado_vehiculo,
    m.fecha_vencimiento_soat,
    m.ans,
    p.id_persona,
    p.nombre AS nombre_persona,
    p.identificacion,
    p.telefono1,
    p.direccion,
    p.ciudad,
    p.estado AS estado_persona,
    mp.roles AS rol_en_vehiculo
FROM motos_motocarros_terceros m
INNER JOIN moto_persona_tercero mp ON m.id_vehiculo = mp.id_vehiculo
INNER JOIN proveedores_motos_terceros p ON mp.id_persona = p.id_persona
ORDER BY m.placa, p.nombre;





CREATE OR REPLACE VIEW vista_beneficiarios AS
SELECT
    b.id_beneficiario,
    b.id_colaborador,
    b.nombre,
    b.genero,
    b.fecha_nacimiento,
    -- Campo calculado: Edad actual en años (usando hora local de Bogotá - UTC-5)
    CASE 
        WHEN b.fecha_nacimiento IS NULL THEN NULL
        ELSE TIMESTAMPDIFF(YEAR, b.fecha_nacimiento, DATE(DATE_ADD(NOW(), INTERVAL -5 HOUR)))
    END AS edad
FROM beneficiarios b
ORDER BY b.id_colaborador, b.nombre;

CREATE OR REPLACE VIEW vista_bitacora_operacion_trafico AS
SELECT * FROM bitacora_operacion_trafico;



CREATE OR REPLACE VIEW vista_caja_menor_operaciones AS
SELECT * FROM caja_menor_operaciones;

CREATE OR REPLACE VIEW vista_candados_satelitales AS
SELECT * FROM candados_satelitales;

CREATE OR REPLACE VIEW vista_categorias_vehiculo AS
SELECT * FROM categorias_vehiculo;

CREATE OR REPLACE VIEW vista_centro_costos AS
SELECT * FROM centro_costos;

CREATE OR REPLACE VIEW vista_paises AS
SELECT * FROM paises;

CREATE OR REPLACE VIEW vista_ciudades AS
SELECT * FROM ciudades;

CREATE OR REPLACE VIEW vista_clientes AS
SELECT * FROM clientes;

CREATE OR REPLACE VIEW vista_colaboradores AS
SELECT * FROM colaboradores;

CREATE OR REPLACE VIEW vista_colaboradores_retirados AS
SELECT * FROM colaboradores_retirados;

CREATE OR REPLACE VIEW vista_conceptos AS
SELECT * FROM conceptos;

CREATE OR REPLACE VIEW vista_conductores AS
SELECT * FROM conductores;

CREATE OR REPLACE VIEW vista_contactos_colaboradores AS
SELECT * FROM contactos_colaboradores;

CREATE OR REPLACE VIEW vista_contratos AS
SELECT * FROM contratos;

CREATE OR REPLACE VIEW vista_cuentas_pyp AS
SELECT * FROM cuentas_pyp;

CREATE OR REPLACE VIEW vista_departamentos AS
SELECT * FROM departamentos;

CREATE OR REPLACE VIEW vista_departamentos_col AS
SELECT * FROM departamentos_col;

CREATE OR REPLACE VIEW vista_dias_festivos AS
SELECT * FROM dias_festivos;

CREATE OR REPLACE VIEW vista_dotacion AS
SELECT * FROM dotacion;

CREATE OR REPLACE VIEW vista_inventario_dotacion AS
SELECT
	id.id_item,
    id.tipo,
    id.referencia,
    id.talla,
    id.color,
    id.precio,
    id.proveedor,
    p.nombre,
    id.fecha_compra,
    id.cantidad,
    id.lote
FROM inventario_dotacion id
JOIN proveedores p ON id.proveedor = p.id_proveedor
;

CREATE OR REPLACE VIEW vista_driver AS
SELECT * FROM driver;

CREATE OR REPLACE VIEW vista_envios AS
SELECT * FROM envios;

CREATE OR REPLACE VIEW vista_escoltas AS
SELECT * FROM escoltas;

CREATE OR REPLACE VIEW vista_grupos_vehiculo AS
SELECT * FROM grupos_vehiculo;

CREATE OR REPLACE VIEW vista_incapacidades AS
SELECT * FROM incapacidades;

CREATE OR REPLACE VIEW vista_ld_despacho AS
SELECT * FROM ld_despacho;

CREATE OR REPLACE VIEW vista_movimiento_candados AS
SELECT * FROM movimiento_candados;

CREATE OR REPLACE VIEW vista_no_planillados_avansat AS
SELECT * FROM no_planillados_avansat;

CREATE OR REPLACE VIEW vista_novedades_observaciones AS
SELECT * FROM novedades_observaciones;

CREATE OR REPLACE VIEW vista_observacion_ld_despachos AS
SELECT * FROM observacion_ld_despachos;

CREATE OR REPLACE VIEW vista_operaciones AS
SELECT * FROM operaciones;

CREATE OR REPLACE VIEW vista_operaciones_avansat AS
SELECT * FROM operaciones_avansat;

CREATE OR REPLACE VIEW vista_ordenes_trabajo_vehiculo AS
SELECT * FROM ordenes_trabajo_vehiculo;

CREATE OR REPLACE VIEW vista_otros_costos AS
SELECT * FROM otros_costos;

CREATE OR REPLACE VIEW vista_pausas_activas AS
SELECT 
    pa.pausa_id,
    pa.fecha,
    pa.hora,
    pa.tiempo_conduccion,
    pa.pausa_real,
    pa.origen,
    pa.destino,
    pa.placa,
    pa.novedad,
    pa.observaciones,
    pa.fecha_reporte,
    -- Reemplazo del ID Controlador por Nombre Completo
    CONCAT_WS(' ', c.primer_nombre, c.segundo_nombre, c.primer_apellido, c.segundo_apellido) AS controlador

FROM pausas_acivas pa  -- OJO: Tu SP anterior insertaba en 'pausas_acivas' (sin la 't'). Verifica el nombre real de tu tabla.
LEFT JOIN colaboradores c ON pa.controlador = c.id_colaborador
ORDER BY pa.pausa_id;


CREATE OR REPLACE VIEW vista_permisos_departamento_vistas AS
SELECT * FROM permisos_departamento_lectura_vistas;

CREATE OR REPLACE VIEW vista_pernocte_flota_propia AS
SELECT 
    p.pernocte_id,
    p.fecha,
    p.placa,
    p.lugar_pernocte,
    -- Reemplazo del ID por el Nombre Completo concatenado
    CONCAT_WS(' ', c.primer_nombre, c.segundo_nombre, c.primer_apellido, c.segundo_apellido) AS controlador
    
FROM pernocte_flota_propia p
LEFT JOIN colaboradores c ON p.controlador = c.id_colaborador
ORDER BY p.pernocte_id;


CREATE OR REPLACE VIEW vista_pp AS
SELECT * FROM pp;

CREATE OR REPLACE VIEW vista_proveedores_vehiculos_terceros AS
SELECT * FROM proveedores_vehiculos_terceros;

CREATE OR REPLACE VIEW vista_reglas_tarifas AS
SELECT * FROM reglas_tarifas;

CREATE OR REPLACE VIEW vista_remesas AS
SELECT * FROM remesas;

CREATE OR REPLACE VIEW vista_tarifas_transporte AS
SELECT * FROM tarifas_transporte;

CREATE OR REPLACE VIEW vista_roles AS
SELECT * FROM roles
ORDER BY cargo;

CREATE OR REPLACE VIEW vista_rutas AS
SELECT * FROM rutas;

CREATE OR REPLACE VIEW vista_sectores_deprisa AS
SELECT * FROM sectores_deprisa;

CREATE OR REPLACE VIEW vista_seguridad_social AS
SELECT * FROM seguridad_social;

CREATE OR REPLACE VIEW vista_servicio AS
SELECT * FROM servicio;

CREATE OR REPLACE VIEW vista_tarifas AS
SELECT * FROM tarifas;

CREATE OR REPLACE VIEW vista_tipologias_vehiculo AS
SELECT * FROM tipologias_vehiculo;

CREATE OR REPLACE VIEW vista_trafico_avansat AS
SELECT * FROM trafico_avansat;

CREATE OR REPLACE VIEW vista_usuarios AS
SELECT * FROM usuarios;

CREATE OR REPLACE VIEW vista_vehiculos_propios AS
SELECT * FROM vehiculos_propios;

CREATE OR REPLACE VIEW vista_vehiculos_terceros AS
SELECT * FROM vehiculos_terceros;

CREATE OR REPLACE VIEW vista_vehiculo_persona AS
SELECT * FROM vehiculo_persona;

CREATE OR REPLACE VIEW vista_contratos_modificaciones AS
SELECT * FROM contratos_modificaciones;

CREATE OR REPLACE VIEW vista_proveedores AS
SELECT * FROM proveedores;

-- Vista con información detallada de colaboradores

CREATE OR REPLACE VIEW vista_info_colaboradores AS
SELECT 
    C.tipo_id,
    C.id_cc,
    C.id_colaborador,
    C.primer_nombre,
    C.segundo_nombre,
    C.primer_apellido,
    C.segundo_apellido,
    CONCAT(C.primer_nombre, ' ', COALESCE(C.segundo_nombre, ''), ' ', C.primer_apellido, ' ', C.segundo_apellido) 
        AS nombre_completo,
    C.fecha_nacimiento,
    TIMESTAMPDIFF(YEAR, C.fecha_nacimiento, CURDATE()) AS edad,
    C.estatus_colaborador,
    D.departamento_id,
    D.nombre AS nombre_depto,
    R.id_rol,
    R.cargo,
    R.rol AS descrip_rol
FROM colaboradores C
JOIN departamentos D ON C.departamento = D.departamento_id
JOIN roles R ON C.cargo = R.id_rol;

-- Vista Consolidado de Vehiculos PYP, TRC, FIDELIZADOS
CREATE OR REPLACE VIEW vista_consolidado_vehiculos AS
WITH todos AS (
    -- 1. Vehículos especiales (máxima prioridad)
    SELECT 
        placa,
        tipo_proveedor,
        1 AS prioridad
    FROM vehiculos_especiales

    UNION ALL

    -- 2. Vehículos propios
    SELECT 
        placa,
        'PYP' AS tipo_proveedor,
        2 AS prioridad
    FROM vehiculos_propios

    UNION ALL

    -- 3. Vehículos terceros
    SELECT 
        placa,
        'TCR' AS tipo_proveedor,
        3 AS prioridad
    FROM vehiculos_terceros

    UNION ALL

    -- 4. Motos y Motocarros terceros
    SELECT
        placa,
        'TCR' AS tipo_proveedor,
        4 AS prioridad
    FROM motos_motocarros_terceros
)

SELECT t.placa, t.tipo_proveedor
FROM (
    SELECT 
        placa,
        tipo_proveedor,
        ROW_NUMBER() OVER (PARTITION BY placa ORDER BY prioridad) AS rn
    FROM todos
) t
WHERE t.rn = 1;


 

-- Vista de usuarios con departamento asignado
CREATE OR REPLACE VIEW vista_usuarios_departamentos AS
SELECT 
    u.usuario, 
    c.departamento,
    bd.base_id,
    bd.bases
FROM usuarios u 
JOIN colaboradores c ON u.id_colaborador = c.id_colaborador
JOIN bases_deprisa bd ON c.sede = bd.ciudad
;

-- Vista Consulta Ciudades VS Departamentos VS Latitud y Logitud
CREATE OR REPLACE VIEW vista_ciudades_departamentos AS
SELECT 
  C.id_ciudad,
  C.nombre AS ciudad,
  C.iata_abreviatura AS codigo,
  D.departamento_id,
  D.nombre AS Departamento_Estado,
  P.nombre AS Pais,
  C.latitud,
  C.longitud
FROM ciudades C 
JOIN departamentos_col D ON C.id_departamento = D.departamento_id
JOIN paises P ON P.pais_id = D.pais_id
ORDER BY C.nombre;

-- //////////////////////////////////////////////////// Vistas Especificas Operaciones ////////////////////////////////////////////////////
-- Vista Sectores / Códigos Deprisa
CREATE OR REPLACE VIEW vista_sectores_deprisa_formato AS
	SELECT
    BD.bases,
    SD.sector,
    LEFT(SD.contrato, 7) AS tipo,
    SD.contrato
FROM sectores_deprisa SD
JOIN bases_deprisa BD ON SD.base_id = BD.base_id;

-- //////////////////////////////////////////////////// Vista Vehiculos ////////////////////////////////////////////////////
/*
CREATE OR REPLACE VIEW vista_formato_operaciones_deprisa AS
SELECT
    VSD.tipo AS tipo_ruta,
    VSD.contrato AS concepto_largo,
    S.nombre AS servicio,
    D.nombre AS driver,
    O.vehiculo,
    BD.bases AS estacion,
    O.fecha,

    DATE_FORMAT(
        CASE
            WHEN DAY(O.fecha) >= 25 THEN DATE_ADD(O.fecha, INTERVAL 1 MONTH)
            ELSE O.fecha
        END,
        '%M %Y'
    ) AS mes_facturacion,

    BD.regional,
    (SELECT CONCAT(C.primer_nombre, ' ', C.primer_apellido) 
     FROM colaboradores C 
     WHERE C.id_colaborador = BD.coordinador_base) AS autorizacion,
    O.proveedor,
    O.tonelaje,

    ( 
        (CASE WHEN O.cc_aux_1 IS NOT NULL AND O.cc_aux_1 <> '' THEN 1 ELSE 0 END) + 
        (CASE WHEN O.cc_aux_2 IS NOT NULL AND O.cc_aux_2 <> '' THEN 1 ELSE 0 END)
    ) AS numero_auxiliares,

    GROUP_CONCAT(OT.numero_ot ORDER BY OT.numero_ot SEPARATOR ', ') AS numero_ot,

    SD.sector,
    O.placa,
    O.hora_inicio,
    O.hora_final,
    O.horas_no_operativas,

    ROUND(
        (TIMESTAMPDIFF(MINUTE, O.hora_inicio, O.hora_final) / 60) -  
        CASE
            WHEN (TIMESTAMPDIFF(MINUTE, O.hora_inicio, O.hora_final) / 60) < 8 THEN 0
            WHEN (TIMESTAMPDIFF(MINUTE, O.hora_inicio, O.hora_final) / 60) < 9 THEN
                (TIMESTAMPDIFF(MINUTE, O.hora_inicio, O.hora_final) / 60) - 8
            ELSE 1
        END,
    1) AS horas_totales,

    O.nombre_ruta,
    O.clasificacion_uso_PxH,
    COALESCE(VCV.propietario, 'No definido') AS propietario,  -- Manejo de NULLs

    CASE 
        WHEN O.vehiculo = 'CAMION' THEN 'CM'
        WHEN O.vehiculo = 'VAN' THEN 'VN'
        WHEN O.vehiculo = 'MOTO' THEN 'VN'
        ELSE NULL
    END AS concepto_corto,

    O.cc_conductor,
    O.cc_aux_1,
    O.cc_aux_2,
    O.cantidad_envios,
    O.cantidad_devoluciones,
    O.cantidad_recolecciones,
    O.cantidad_no_recogidos,
    O.km_inicial,
    O.km_final,
    O.tipo_pago,
    O.remesa,
    O.manifiesto,

    ROUND(TIMESTAMPDIFF(MINUTE, O.hora_inicio, O.hora_final) / 60, 1) AS horas_reales,

    BD.bases AS base,
    O.validacion_cumplido_liquidado,
    O.validacion_prefactura

FROM operaciones O
LEFT JOIN servicio S ON O.servicio = S.servicio_id
LEFT JOIN driver D ON O.driver = D.driver_id
LEFT JOIN bases_deprisa BD ON O.estacion = BD.base_id
LEFT JOIN ordenes_trabajo_vehiculo OT ON O.operacion_id = OT.operacion_id
LEFT JOIN sectores_deprisa SD ON O.sector = SD.sector
LEFT JOIN vista_sectores_deprisa_formato VSD ON SD.sector = VSD.sector
LEFT JOIN ciudades C ON BD.bases = C.iata_abreviatura
LEFT JOIN vista_consolidado_vehiculos VCV ON O.placa = VCV.placa

GROUP BY
    O.operacion_id,
    VSD.tipo,
    VSD.contrato,
    S.nombre,
    D.nombre,
    O.vehiculo,
    BD.bases,
    O.fecha,
    BD.regional,
    BD.coordinador_base,
    O.proveedor,
    O.tonelaje,
    SD.sector,
    O.placa,
    O.hora_inicio,
    O.hora_final,
    O.horas_no_operativas,
    O.nombre_ruta,
    O.clasificacion_uso_PxH,
    COALESCE(VCV.propietario, 'No definido'),  -- Mismo manejo en GROUP BY
    O.cc_conductor,
    O.cc_aux_1,
    O.cc_aux_2,
    O.cantidad_envios,
    O.cantidad_devoluciones,
    O.cantidad_recolecciones,
    O.cantidad_no_recogidos,
    O.km_inicial,
    O.km_final,
    O.tipo_pago,
    O.remesa,
    O.manifiesto,
    O.validacion_cumplido_liquidado,
    O.validacion_prefactura
ORDER BY O.fecha ASC;
*/

-- Vista para ListBox del formulario Conciliacion_Operacion

CREATE OR REPLACE VIEW vista_conciliacion_operaciones AS
SELECT
    O.operacion_id,
	D.nombre AS Driver,
    S.nombre AS Servicio,
    O.vehiculo,
    BD.bases,
    O.fecha,
    BD.regional,
    O.tonelaje,
	(
        (CASE WHEN O.cc_aux_1 IS NOT NULL AND O.cc_aux_1 <> '' THEN 1 ELSE 0 END) +
        (CASE WHEN O.cc_aux_2 IS NOT NULL AND O.cc_aux_2 <> '' THEN 1 ELSE 0 END)
    ) AS cantidad_auxiliares,
    GROUP_CONCAT(OT.numero_ot ORDER BY OT.numero_ot SEPARATOR ', ') AS OT_Viaje,
    O.sector,
    O.placa,
	TIME_FORMAT(O.hora_inicio, '%h:%i %p') AS Hora_Inicio,
	TIME_FORMAT(O.hora_final, '%h:%i %p') AS Hora_Final,

    O.horas_no_operativas,
    O.cc_aux_1,
    O.cc_aux_2

FROM vista_operaciones O
LEFT JOIN ordenes_trabajo_vehiculo OT ON O.operacion_id = OT.operacion_id
LEFT JOIN bases_deprisa BD ON O.estacion = BD.base_id
LEFT JOIN servicio S ON O.servicio = S.servicio_id
LEFT JOIN driver D ON O.driver = D.driver_id
WHERE
    O.hora_final IS NOT NULL
    AND O.km_final IS NOT NULL
    AND O.servicio IN (1, 2, 3, 4)
GROUP BY
    O.operacion_id,
    O.fecha,
    BD.bases,
    S.nombre,
    D.nombre,
    O.sector,
    O.placa,
    O.vehiculo,
    O.hora_inicio,
    O.hora_final,
    O.tonelaje,
    O.cc_aux_1,
    O.cc_aux_2,
    BD.regional,
    O.horas_no_operativas,
    O.cc_aux_1,
    O.cc_aux_2
ORDER BY
    O.fecha ASC,
    O.hora_inicio ASC;
    
    
-- ###############################Vista Estatus de Vehiculos Terceros##################################
CREATE OR REPLACE VIEW vista_informacion_vehiculos_terceros AS
SELECT 
    v.id_vehiculo,
    v.placa,
    v.estado AS estatus_vehiculo,
    vp.id_persona,
    p.identificacion,
    p.nombre,
    p.estado AS estatus_persona,
    vp.roles AS rol
FROM vehiculos_terceros v
JOIN vehiculo_persona vp ON v.id_vehiculo = vp.id_vehiculo
JOIN proveedores_vehiculos_terceros p ON p.id_persona = vp.id_persona
ORDER BY v.placa;

-- Consulta datos conductores terceros
CREATE OR REPLACE VIEW vista_conductores_terceros AS
SELECT 
    vt.placa,
    pvt.nombre,
    pvt.identificacion,
    pvt.telefono1,
    pvt.direccion,
    c.nombre AS ciudad
FROM vehiculo_persona vp
JOIN proveedores_vehiculos_terceros pvt 
    ON vp.id_persona = pvt.id_persona
JOIN vehiculos_terceros vt 
    ON vp.id_vehiculo = vt.id_vehiculo
LEFT JOIN ciudades c 
    ON pvt.ciudad = c.id_ciudad
WHERE vp.roles = 'Conductor';

-- Consulta doatos conductores propios
CREATE OR REPLACE VIEW vista_conductores_propios AS
SELECT 
    CONCAT_WS(' ', c.primer_nombre, c.segundo_nombre, c.primer_apellido, c.segundo_apellido) AS nombre_completo,
    c.tipo_id,
    c.id_cc,
    c.direccion,
    ciu.nombre AS ciudad_sede
FROM colaboradores c
JOIN ciudades ciu ON c.sede = ciu.id_ciudad
WHERE c.estatus_colaborador = 'Activo'
  AND c.cargo IN (15, 16, 17, 21, 24, 39, 51);

-- Consulta consolidado Conductores, reune los datos de conductores terceros y propios
CREATE OR REPLACE VIEW vista_consolidado_conductores AS
WITH todos AS (
    -- 1. Conductores propios (máxima prioridad)
    SELECT 
        vcp.id_cc AS identificacion,
        vcp.nombre_completo AS nombre,
        'Directo' AS tipo_conductor,
        1 AS prioridad
    FROM vista_conductores_propios vcp

    UNION ALL

    -- 2. Proveedores vehículos terceros
    SELECT
        pvt.identificacion,
        pvt.nombre,
        'Tercero Vehículo' AS tipo_conductor,
        2 AS prioridad
    FROM proveedores_vehiculos_terceros pvt
    JOIN vehiculo_persona vp ON pvt.id_persona = vp.id_persona
    WHERE vp.roles = 'Conductor' AND pvt.estado = 'Habilitado'

    UNION ALL

    -- 3. Conductores Avansat
    SELECT
        vcta.cc_id AS identificacion,
        vcta.nombre,
        'Tercero Avansat' AS tipo_conductor,
        3 AS prioridad
    FROM vista_conductores_terceros_avansat vcta
    WHERE vcta.estado = 'Activo'

    UNION ALL

    -- 4. Proveedores motos terceros
    SELECT
        PMT.identificacion,
        PMT.nombre,
        'Tercero Moto' AS tipo_conductor,
        4 AS prioridad
    FROM proveedores_motos_terceros PMT
    JOIN moto_persona_tercero MPT ON PMT.id_persona = MPT.id_persona
    WHERE MPT.roles = 'Conductor' AND PMT.estado = 'Habilitado'
)

SELECT t.identificacion, t.nombre, t.tipo_conductor
FROM (
    SELECT 
        identificacion, 
        nombre, 
        tipo_conductor,
        ROW_NUMBER() OVER (PARTITION BY identificacion ORDER BY prioridad) AS rn
    FROM todos
) t
WHERE t.rn = 1;

-- Consulta Usuarios creados para crear en pypdb en MySQL
CREATE OR REPLACE VIEW vista_datos_usuarios AS
SELECT
    u.id_usuario,
    u.usuario,
    u.contraseña AS contraseña_temporal,
    u.departamento AS id_departamento,
    d.nombre AS nombre_departamento,
    c.id_colaborador,
    CONCAT_WS(' ',
        c.primer_nombre,
        c.segundo_nombre,
        c.primer_apellido,
        c.segundo_apellido
    ) AS nombre_completo
FROM
    usuarios u
JOIN
    colaboradores c ON u.id_colaborador = c.id_colaborador
LEFT JOIN
    departamentos d ON u.departamento = d.departamento_id;
    
    
-- consulta con los usuarios y el respectivo id y nombre del colaborador
CREATE OR REPLACE VIEW vista_colaboradores_usuarios AS
SELECT 
  U.usuario,
  C.id_colaborador, 
  CONCAT_WS(' ', C.primer_nombre, C.segundo_nombre, C.primer_apellido, C.segundo_apellido) AS Nombre
FROM colaboradores C
JOIN usuarios U
  ON C.id_colaborador = U.id_colaborador;
  
  
-- consulta listado total de auxiliares propios y terceros con ciudad y bases Deprisa
CREATE OR REPLACE VIEW vista_auxiliares_transporte_activo AS
SELECT
  C.id_cc AS identificacion,
  CONCAT_WS(' ', C.primer_nombre, C.segundo_nombre, C.primer_apellido, C.segundo_apellido) AS nombre,
  CIU.id_ciudad,
  CIU.nombre AS nombre_ciudad,
  BD.bases AS base_deprisa
FROM colaboradores C
JOIN ciudades CIU ON C.sede = CIU.id_ciudad
JOIN bases_deprisa BD ON C.sede = BD.ciudad
WHERE C.cargo IN (11, 12, 14, 17, 39) AND C.estatus_colaborador = 'Activo'

UNION

SELECT
  AX.documento AS identificacion,
  AX.nombre,
  CIU.id_ciudad,
  CIU.nombre AS nombre_ciudad,
  BD.bases AS base_deprisa
FROM auxiliares_terceros AX
JOIN ciudades CIU ON AX.ciudad = CIU.id_ciudad
JOIN bases_deprisa BD ON AX.ciudad = BD.ciudad
WHERE AX.estatus = 'Activo';

-- vista Back office
CREATE OR REPLACE VIEW vista_backoffice AS
SELECT * FROM backoffice;



-- Vista de Supervisores y coordionadores operaciones
CREATE OR REPLACE VIEW vista_supervisores_coodinadores_activo_operaciones AS
SELECT
  C.id_cc AS identificacion,
  CONCAT_WS(' ', C.primer_nombre, C.segundo_nombre, C.primer_apellido, C.segundo_apellido) AS nombre,
  CIU.id_ciudad,
  CIU.nombre AS nombre_ciudad,
  BD.bases AS base_deprisa
FROM colaboradores C
JOIN ciudades CIU ON C.sede = CIU.id_ciudad
JOIN bases_deprisa BD ON C.sede = BD.ciudad
WHERE C.cargo IN (21, 39, 63) AND C.estatus_colaborador = 'Activo';


-- Vista conductores_terceros_avansat
CREATE OR REPLACE VIEW vista_conductores_terceros_avansat AS
SELECT * FROM conductores_terceros_avansat;

-- ############################################Vistas Tarifas PXQ y PXH Operaciones #################################################

-- Vista Tarifas PXQ Operaciones
CREATE OR REPLACE VIEW vista_tarifas_deprisa_PXQ AS
SELECT
    TD.tarifa_id,
    TD.tipo,
    TD.estructura,
    TD.modelo,
    
    -- Información de la base
    TD.base                           AS id_base,
    CB.nombre                         AS nombre_base,
    TD.base_corta,
    
    -- Información de la población
    TD.poblacion                      AS id_poblacion,
    CP.nombre                         AS nombre_poblacion,
    
    TD.entrega,
    TD.recoleccion
FROM tarifas_deprisa_PXQ AS TD

-- 1. JOIN para la base
JOIN ciudades AS CB
       ON CB.id_ciudad = TD.base

-- 2. JOIN para la población
LEFT JOIN ciudades AS CP
       ON CP.id_ciudad = TD.poblacion;
       

-- Vista tarifas PXH Operaciones
CREATE OR REPLACE VIEW vista_tarifas_deprisa_PXH AS
SELECT 
	TD.tarifa_id,
    TD.tipo,
    TD.estructura,
    TD.modelo,
    TD.base,
    C.nombre,
    C.iata_abreviatura AS base_corta,
    TD.tonelaje,
    TD.valor,
    TD.auxiliar
FROM tarifas_deprisa_PXH TD
JOIN ciudades C ON TD.base = C.id_ciudad
;

-- Vista Log_conexiones
CREATE OR REPLACE VIEW vista_log_conexiones AS
SELECT
    id_log,
    usuario,
    ip_origen,
    mac_origen,
    CONVERT_TZ(fecha_conexion, 'UTC', 'America/Bogota') AS fecha_conexion
FROM log_conexiones;

-- Vista listado conductore motos y moto-carros terceros
CREATE OR REPLACE VIEW vista_conductores_motos_terceros AS
SELECT
	PMT.identificacion,
    PMT.nombre,
    MPT.roles
FROM proveedores_motos_terceros PMT
JOIN moto_persona_tercero MPT
WHERE roles = 'Conductor'
;

-- vista consolidado de vehiculos con tipologia y proveedor
CREATE OR REPLACE VIEW vista_consolidado_vehiculos_tipologia AS
SELECT
    vp.placa,
    tv.nombre,
    'Propio' AS tipo_vinculacion
FROM vehiculos_propios vp
LEFT JOIN tipologias_vehiculo tv ON vp.id_tipologia = tv.id_tipologia

UNION ALL

SELECT
    vt.placa,
    tv.nombre,
    'Tercero' AS tipo_vinculacion
FROM vehiculos_terceros vt
LEFT JOIN tipologias_vehiculo tv ON vt.id_tipologia = tv.id_tipologia
WHERE vt.placa NOT IN (
    SELECT placa FROM vehiculos_propios
);


-- vista operaciones larga distancia AVANSAT
CREATE OR REPLACE VIEW vista_operaciones_larga_distancia_avansat AS
SELECT
    voa.fecha_salida_despacho,
    voa.placa,
    vcvt.nombre,
    voa.fecha_manifiesto,
    voa.manifiesto,
    voa.facturado_a AS cliente,
    voa.origen,
    voa.destino,
    voa.tipo_vinculacion,
    voa.fecha_remesa,
    voa.fecha_factura,
    voa.factura,
    CASE
		WHEN factura LIKE 'AA%' THEN 'FACTURADO'
		ELSE 'SIN FACTURAR'
	END AS estado_rm,

    voa.fecha_recaudo,
    voa.nro_comprobante_recaudo,
    voa.fecha_pago,
    voa.valor_pagado,
    voa.nro_comprob2,
    voa.creado_por,
    CASE 
        WHEN voa.manifiesto LIKE 'I%' THEN voa.val_inicial_remesa 
        ELSE NULL 
    END AS internos,
    voa.val_produccion AS tarifa,
    voa.flete_manifiesto AS flete
FROM vista_operaciones_avansat voa
LEFT JOIN vista_consolidado_vehiculos_tipologia vcvt ON vcvt.placa = voa.placa
WHERE 
voa.origen <> voa.destino
AND
voa.estado = 'Activo'
AND
voa.creado_por IN ('YCADENA', 'ARODIRGUEZ', 'DPOVEDA', 'JMORALES', 'SPINO', 'YMORENO')
;


-- vista operaciones AVANSAT para Power BI
CREATE OR REPLACE VIEW vista_operaciones_avansat_powerbi AS
SELECT
    voa.fecha_salida_despacho,
    voa.placa,
    vcvt.nombre,
    voa.fecha_manifiesto,
    voa.manifiesto,
    voa.facturado_a AS cliente,
    voa.origen,
    voa.destino,
    voa.tipo_vinculacion,
    voa.fecha_remesa,
    voa.fecha_factura,
    voa.factura,
    CASE
		WHEN factura LIKE 'AA%' THEN 'FACTURADO'
		ELSE 'SIN FACTURAR'
	END AS estado_rm,

    voa.fecha_recaudo,
    voa.nro_comprobante_recaudo,
    voa.fecha_pago,
    voa.valor_pagado,
    voa.nro_comprob2,
    voa.creado_por,
    CASE 
        WHEN voa.manifiesto LIKE 'I%' THEN voa.val_inicial_remesa 
        ELSE NULL 
    END AS internos,
    voa.val_produccion AS tarifa,
    voa.flete_manifiesto AS flete
FROM vista_operaciones_avansat voa
LEFT JOIN vista_consolidado_vehiculos_tipologia vcvt ON vcvt.placa = voa.placa
WHERE 
voa.estado = 'Activo';

-- Vista Histórico Operaciones UM
CREATE OR REPLACE VIEW vista_historico_operaciones AS
SELECT * FROM historico_operaciones;

-- Vista combinada historico_operaciones + operaciones
CREATE OR REPLACE VIEW vista_total_operaciones AS
SELECT 					-- Consulta historico_operaciones reducida
	servicio_excel,
    servicio,
    driver_excel,
    driver,
    vehiculo,
    estacion_excel,
    estacion,
    fecha,
    mes_facturacion,
    regional,
    autorizacion,
    proveedor_deprisa,
    tonelaje,
    numero_auxiliares,
    sector,
    placa,
    hora_inicio,
    hora_final,
    horas_no_operativas,
    horas_totales,
    nombre_ruta,
    clasificacion_uso_pxh,
    proveedor,
    vehiculo_concepto_corto,
    cc_conductor,
    nombre_conductor,
    cc_aux1,
    nombre_aux1,
    cc_aux2,
    nombre_aux2,
    envios,
    envios_efectivos,
    dev,
	num_recolecciones,
    recolecciones_efectivas,
    recolecciones_no_efectivas,
    km_inicial,
    km_final,
    tipo_pago,
    remesa,
    manifiesto,
    horas_reales,
    km_dia,
    total_cobro,
    total_turno,
    total_env_y_rec,
    cobro_auxiliar,
    cobro_sin_auxiliar
FROM historico_operaciones

UNION ALL

SELECT 												-- Consulta operaciones ajustada
    s.nombre AS servicio_excel,
    o.servicio,
    CASE 
		WHEN d.nombre LIKE '%hora%' THEN 'PxH' 
		ELSE d.nombre 
	END AS driver_excel,
    o.driver,
    o.vehiculo,
    bd.bases AS estacion_excel,
    o.estacion,
    o.fecha,
    CASE 
        WHEN DAY(o.fecha) >= 25 
            THEN ELT(MONTH(DATE_ADD(o.fecha, INTERVAL 1 MONTH)),
                     'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                     'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre')
        ELSE ELT(MONTH(o.fecha),
                 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                 'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre')
    END AS mes_facturacion,
    bd.regional,
    bd.coordinador_base AS autorizacion,
    'pyp' AS proveedor_deprisa,
    o.tonelaje,
    (
        IF(o.cc_aux_1 IS NOT NULL AND o.cc_aux_1 <> '', 1, 0) +
        IF(o.cc_aux_2 IS NOT NULL AND o.cc_aux_2 <> '', 1, 0)
    ) AS numero_auxiliares,
    o.sector,
    o.placa,
    o.hora_inicio,
    o.hora_final,
    o.horas_no_operativas,
    ROUND((TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0) - o.horas_no_operativas, 1) AS horas_totales,
    o.nombre_ruta,
    o.clasificacion_uso_pxh,
    o.proveedor,
    CASE
        WHEN o.vehiculo LIKE '%CAMION%' THEN 'CM'
        WHEN o.vehiculo LIKE '%VAN%'    THEN 'VN'
        WHEN o.vehiculo LIKE '%MOTO%'   THEN 'MT'
        ELSE o.vehiculo
    END AS vehiculo_concepto_corto,
    o.cc_conductor,
    vcc.nombre AS nombre_conductor,
    o.cc_aux_1,
    vat1.nombre AS nombre_aux1,
    o.cc_aux_2,
    vat2.nombre AS nombre_aux2,
    o.cantidad_envios AS envios,
    (o.cantidad_envios - o.cantidad_devoluciones) AS envios_efectivos,
    o.cantidad_devoluciones AS dev,
    o.cantidad_recolecciones AS num_recolecciones,
    (o.cantidad_recolecciones - o.cantidad_no_recogidos) AS recolecciones_efectivas,
    o.cantidad_no_recogidos AS recolecciones_no_efectivas,
    o.km_inicial,
    o.km_final,
    o.tipo_pago,
    o.remesa,
    o.manifiesto,
    ROUND(TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0, 1) AS horas_reales,
	(IFNULL(o.km_final, 0) - IFNULL(o.km_inicial, 0)) AS km_dia,
    o.total_cobro,
    o.total_turno,
    ((o.cantidad_envios - o.cantidad_devoluciones) + (o.cantidad_recolecciones - o.cantidad_no_recogidos)) AS total_env_y_rec,
    cobro_auxiliar,
    cobro_sin_auxiliar
FROM operaciones o
JOIN servicio s ON s.servicio_id = o.servicio
JOIN driver d ON d.driver_id = o.driver
JOIN bases_deprisa bd ON bd.base_id = o.estacion
JOIN vista_consolidado_conductores vcc ON o.cc_conductor = vcc.identificacion
LEFT JOIN vista_auxiliares_transporte_activo vat1 ON o.cc_aux_1 = vat1.identificacion
LEFT JOIN vista_auxiliares_transporte_activo vat2 ON o.cc_aux_2 = vat2.identificacion
LEFT JOIN tarifas_mensuales tm ON tm.sector = o.sector   -- 👈 nuevo join
WHERE 
    (tm.sector IS NULL)            -- si no está en tarifas_mensuales, mostrar sin restricción
    OR 
    (tm.sector IS NOT NULL AND o.total_cobro IS NOT NULL)  -- si está, exigir total_cobro
GROUP BY 
    o.operacion_id,
    s.nombre,
    o.servicio,
    d.nombre,
    o.driver,
    o.vehiculo,
    bd.bases,
    o.estacion,
    o.fecha,
    bd.regional,
    bd.coordinador_base,
    o.tonelaje,
    o.cc_aux_1,
    o.cc_aux_2,
    o.hora_inicio,
    o.hora_final,
    o.horas_no_operativas,
    o.nombre_ruta,
    o.clasificacion_uso_pxh,
    o.proveedor,
    vcc.nombre,
    vat1.nombre,
    vat2.nombre,
    o.cantidad_envios,
    o.cantidad_devoluciones,
    o.cantidad_recolecciones,
    o.cantidad_no_recogidos;

-- vista de operaciones con calculos de horas y paquetes

CREATE OR REPLACE VIEW vista_operaciones_cerradas_PxH AS
SELECT *
FROM (
    SELECT
        o.operacion_id,
        o.servicio,
        s.nombre AS servicio_excel,
        o.driver,
        CASE
            WHEN d.nombre LIKE '%hora%' THEN 'PxH'
            ELSE d.nombre
        END AS driver_excel,
        o.vehiculo,
        CASE
            WHEN o.vehiculo LIKE '%CAMION%' THEN 'CM'
            WHEN o.vehiculo LIKE '%VAN%'    THEN 'VN'
            WHEN o.vehiculo LIKE '%MOTO%'   THEN 'MT'
            ELSE o.vehiculo
        END AS vehiculo_concepto_corto,
        o.estacion,
        bd.bases AS estacion_excel,
        o.fecha,
        o.tonelaje,
        (
            IF(o.cc_aux_1 IS NOT NULL AND o.cc_aux_1 <> '', 1, 0) +
            IF(o.cc_aux_2 IS NOT NULL AND o.cc_aux_2 <> '', 1, 0)
        ) AS numero_auxiliares,
        o.sector,
        o.placa,
        o.hora_inicio,
        o.hora_final,
        o.horas_no_operativas,
        ROUND((TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0) - o.horas_no_operativas, 1) AS horas_totales,
        o.clasificacion_uso_pxh,
        o.proveedor,
        o.cc_conductor,
        o.cc_aux_1,
        o.cc_aux_2,
        o.cantidad_envios AS envios,
        (o.cantidad_envios - o.cantidad_devoluciones) AS envios_efectivos,
        o.cantidad_devoluciones AS dev,
        o.cantidad_recolecciones AS num_recolecciones,
        (o.cantidad_recolecciones - o.cantidad_no_recogidos) AS recolecciones_efectivas,
        o.cantidad_no_recogidos AS recolecciones_no_efectivas,
        o.tipo_pago,
        -- CAMPOS CALCULADOS AÑADIDOS --
        tar.valor AS tarifa_por_hora,
        ROUND( (ROUND((TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0) - o.horas_no_operativas, 1)) * tar.valor, 2) AS total_cobro

    FROM operaciones o
    JOIN servicio s ON s.servicio_id = o.servicio
    JOIN driver d ON d.driver_id = o.driver
    JOIN bases_deprisa bd ON bd.base_id = o.estacion
    JOIN vista_consolidado_conductores vcc ON o.cc_conductor = vcc.identificacion
    -- JOIN AÑADIDO PARA OBTENER LA TARIFA --
    LEFT JOIN vista_tarifas_con_base_deprisa AS tar
        ON o.estacion = tar.base_id
        AND o.tonelaje = tar.tonelaje
        AND (IF(o.cc_aux_1 IS NOT NULL AND o.cc_aux_1 <> '', 1, 0) + IF(o.cc_aux_2 IS NOT NULL AND o.cc_aux_2 <> '', 1, 0)) = tar.auxiliar
    WHERE o.hora_final IS NOT NULL AND o.km_final <> '' AND o.proveedor = 'PYP'
    GROUP BY
        o.operacion_id,
        s.nombre,
        o.servicio,
        d.nombre,
        o.driver,
        o.vehiculo,
        bd.bases,
        o.estacion,
        o.fecha,
        bd.regional,
        bd.coordinador_base,
        o.tonelaje,
        o.cc_aux_1,
        o.cc_aux_2,
        o.hora_inicio,
        o.hora_final,
        o.horas_no_operativas,
        o.nombre_ruta,
        o.clasificacion_uso_pxh,
        o.proveedor,
        o.cantidad_envios,
        o.cantidad_devoluciones,
        o.cantidad_recolecciones,
        o.cantidad_no_recogidos,
        tar.valor -- Se añade la tarifa al GROUP BY
) AS consulta_filtrada
WHERE driver_excel = 'PxH';



-- Vista tarifas con id de base_deprisa y ciudad
CREATE OR REPLACE VIEW vista_tarifas_con_base_deprisa AS
SELECT 
    tdpxh.tarifa_id,
    tdpxh.tipo,
    tdpxh.estructura,
    tdpxh.modelo,
    tdpxh.base,
    bd.base_id,
    tdpxh.tonelaje,
    tdpxh.valor,
    tdpxh.auxiliar,
    tdpxh.vigencia
FROM tarifas_deprisa_PXH tdpxh
 LEFT JOIN bases_deprisa bd ON tdpxh.base = bd.ciudad
WHERE tdpxh.valor > 0;


-- Consulta Vista calcular PxH

CREATE OR REPLACE VIEW calculos_pxh AS
SELECT
    o.operacion_id,
    tar.valor AS tarifa_por_hora,
    -- Cálculo de horas trabajadas (excluyendo no operativas)
    ROUND( (TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0) - o.horas_no_operativas, 1) AS horas_facturables,
    -- Cálculo del cobro total
    ROUND( 
        (ROUND( (TIMESTAMPDIFF(MINUTE, o.hora_inicio, o.hora_final) / 60.0) - o.horas_no_operativas, 1)) * tar.valor, 
        2
    ) AS total_cobro_calculado
FROM
    operaciones o
-- Usamos un JOIN porque solo nos interesan las operaciones que tienen una tarifa aplicable
JOIN
    vista_tarifas_con_base_deprisa AS tar
    ON o.sector = tar.base -- Unión por ciudad/sector
    AND o.tonelaje = tar.tonelaje
    AND (IF(o.cc_aux_1 IS NOT NULL AND o.cc_aux_1 <> '', 1, 0) + IF(o.cc_aux_2 IS NOT NULL AND o.cc_aux_2 <> '', 1, 0)) = tar.auxiliar
WHERE
    o.hora_final IS NOT NULL;
    
    


-- Vista de cálculo de cobor total para servicios PxH
CREATE OR REPLACE VIEW vista_calculos_total_tarifa_PxH AS
SELECT
    o.operacion_id,
    
    -- El cálculo de total_tarifa ajustado
    ROUND(
        (
            ROUND(
                -- Inicia el cálculo de horas efectivas
                (TIMESTAMPDIFF(MINUTE, 
                    o.hora_inicio, 
                    -- >>> LA CORRECCIÓN CLAVE: Ajuste para cierre al día siguiente <<<
                    CASE 
                        WHEN o.cierre_dia_siguiente = 1 THEN ADDTIME(o.hora_final, '24:00:00') 
                        ELSE o.hora_final 
                    END
                ) / 60.0) - o.horas_no_operativas,
                4
            )
        ) * MAX(tdpxh.valor),
        0
    ) AS total_tarifa
FROM
    operaciones o
/* ───────── JOIN con excepción puntual ───────── */
LEFT JOIN tarifas_deprisa_PXH AS tdpxh
       ON tdpxh.tonelaje = o.tonelaje
      AND tdpxh.auxiliar = ( IF(o.cc_aux_1 IS NOT NULL AND o.cc_aux_1 <> '',1,0)
                           + IF(o.cc_aux_2 IS NOT NULL AND o.cc_aux_2 <> '',1,0) )

      /* 1️⃣ Búsqueda normal para todo el país (lo que ya tenías) */
      AND (
              (tdpxh.base = o.ciudad_poblacion
               AND tdpxh.estructura <> 'MENSUALIDAD')

      /* 2️⃣ Excepción SOLO si base=3 y ciudad_poblacion≠110        */
           OR (o.estacion = 3
               AND o.ciudad_poblacion <> 110
               AND tdpxh.estructura = 'PXH Camion Poblacion Sabana'
               AND tdpxh.modelo     = 'PXH POB')
          )

WHERE
      o.hora_final IS NOT NULL
  AND o.servicio   <> 5
GROUP BY
      o.operacion_id;
      

-- Vista para control combo box en Access para para id_colaborador, nombre completo Talento Humano
CREATE OR REPLACE VIEW vista_id_colaborador_nombre_completo AS
SELECT 
  id_colaborador,
  CONCAT_WS(' ', primer_nombre, segundo_nombre, primer_apellido, segundo_apellido) AS nombre_completo
FROM 
  vista_colaboradores
ORDER BY 
  primer_nombre,
  segundo_nombre,
  primer_apellido,
  segundo_apellido;
  
  -- Vista Datos Bancarios Colaboradores
CREATE OR REPLACE VIEW vista_cuentas_bancarias_colaboradores AS
SELECT
    ccb.cuenta_id,
    ccb.id_colaborador,
    ccb.banco_id,
    vb.nombre_banco,
    ccb.tipo_cuenta,
    ccb.num_cuenta,
    ccb.cta_contable_banco
FROM cuentas_bancarias_colaboradores ccb
INNER JOIN vista_bancos vb ON ccb.banco_id = vb.banco_id
ORDER BY ccb.id_colaborador, vb.nombre_banco;

CREATE OR REPLACE VIEW vista_tallas_dotacion AS
SELECT * FROM tallas_dotacion;

CREATE OR REPLACE VIEW vista_tbl_inactividades AS
SELECT * FROM tbl_inactividades;

CREATE OR REPLACE VIEW vista_informe_colaboradores AS
SELECT 
    RET.fecha_retiro,
    CR_DETALLE.motivo,
    CON.fecha_ingreso,
    DAY(CON.fecha_ingreso) AS dia_ingreso,
    ELT(MONTH(CON.fecha_ingreso), 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC') AS mes_ingreso,
    YEAR(CON.fecha_ingreso) AS año_ingreso,
    COL.planta,
    COL.estatus_colaborador,
    COL.tipo_id,
    COL.id_cc,
    CIUD.nombre AS lugar_expedicion,
    COL.fecha_expedicion,
    COL.primer_nombre,
    COL.segundo_nombre,
    COL.primer_apellido,
    COL.segundo_apellido,
    CONCAT(
        COL.primer_nombre, ' ',
        IFNULL(COL.segundo_nombre, ''), ' ',
        COL.primer_apellido, ' ',
        COL.segundo_apellido) AS nombre_completo,
    
    COL.fecha_nacimiento,
    DAY(COL.fecha_nacimiento) AS dia_nacimiento,
    ELT(MONTH(COL.fecha_nacimiento), 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC') AS mes_nacimiento,
    YEAR(COL.fecha_nacimiento) AS año_nacimiento,
    
    COL.sexo,
    COL.grupo_sanguineo,
    COL.rh,
    COL.estado_civil,
    COL.direccion,
    COL.barrio,

    -- 1. CONTACTO
    CONTACTO_EMAIL.valor AS email_personal,
    CONTACTO_MOVIL.valor AS movil_personal,

    -- 2. CONTRATO
    CON_DETALLE.tipo_contrato,
    CON_DETALLE.termino_meses,
    CON_DETALLE.forma_pago,
    
    ROL.cargo,
    COS.centro_costo,
    CIU.nombre AS ciudad,

    -- 3. SEGURIDAD SOCIAL
    SS.cesantias,
    SS.pension,
    SS.eps,
    SS.arl,
    SS.riesgo,
    SS.ccf,
    
    COL.fecha_emo,

    CIUD_NAC.nombre AS lugar_nacimiento, 

    -- 4. NUEVOS CAMPOS CALCULADOS (Beneficiarios)
    IF(IFNULL(BEN.total_beneficiarios, 0) > 0, 'SI', 'NO') AS personas_a_cargo,
    IFNULL(BEN.total_beneficiarios, 0) AS numero,

    COL.contacto_emergencia,
    COL.telefono_contacto_emergencia
    
FROM colaboradores COL

-- JOIN Fecha Ingreso
LEFT JOIN (
    SELECT 
        id_colaborador,
        MAX(fecha_ingreso) AS fecha_ingreso
    FROM contratos
    GROUP BY id_colaborador
) AS CON
    ON COL.id_colaborador = CON.id_colaborador

-- JOIN Detalle Contrato
LEFT JOIN contratos CON_DETALLE
    ON CON.id_colaborador = CON_DETALLE.id_colaborador 
    AND CON.fecha_ingreso = CON_DETALLE.fecha_ingreso

-- JOIN Fecha Retiro
LEFT JOIN (
    SELECT 
        id_colaborador,
        MAX(fecha_retiro) AS fecha_retiro
    FROM colaboradores_retirados
    GROUP BY id_colaborador
) AS RET
    ON COL.id_colaborador = RET.id_colaborador

-- JOIN Motivo Retiro
LEFT JOIN colaboradores_retirados CR_DETALLE 
    ON RET.id_colaborador = CR_DETALLE.id_colaborador 
    AND RET.fecha_retiro = CR_DETALLE.fecha_retiro

-- JOIN Sede
LEFT JOIN ciudades CIU 
    ON COL.sede = CIU.id_ciudad
 
-- JOIN Lugar Expedición 
LEFT JOIN ciudades CIUD 
    ON COL.lugar_expedicion = CIUD.id_ciudad

-- JOIN Ciudad Nacimiento
LEFT JOIN ciudades CIUD_NAC 
    ON COL.ciudad_nacimiento = CIUD_NAC.id_ciudad

-- JOIN Centro de Costos
LEFT JOIN centro_costos COS 
    ON COS.id_centro_costo = (
        SELECT c2.id_centro_costo
        FROM contratos c2
        WHERE c2.id_colaborador = COL.id_colaborador
        ORDER BY c2.fecha_ingreso DESC
        LIMIT 1
    )

LEFT JOIN roles ROL 
    ON COL.cargo = ROL.id_rol
 
-- Joins de Contacto
LEFT JOIN contactos_colaboradores CONTACTO_EMAIL
    ON COL.id_colaborador = CONTACTO_EMAIL.id_colaborador 
    AND CONTACTO_EMAIL.tipo = 'email_personal'

LEFT JOIN contactos_colaboradores CONTACTO_MOVIL
    ON COL.id_colaborador = CONTACTO_MOVIL.id_colaborador 
    AND CONTACTO_MOVIL.tipo = 'movil_personal'

-- JOIN Seguridad Social
LEFT JOIN seguridad_social SS
    ON COL.id_colaborador = SS.id_empleado

-- 5. NUEVO JOIN: BENEFICIARIOS (Agrupado)
LEFT JOIN (
    SELECT 
        id_colaborador, 
        COUNT(*) AS total_beneficiarios 
    FROM beneficiarios
    GROUP BY id_colaborador
) AS BEN
    ON COL.id_colaborador = BEN.id_colaborador

ORDER BY COL.primer_nombre, COL.primer_apellido;

  
CREATE OR REPLACE VIEW vista_colaboradores_con_novedades AS
SELECT
    c.id_colaborador,
    c.id_cc,
    CONCAT_WS(' ',
        c.primer_nombre,
        NULLIF(c.segundo_nombre, ''),
        c.primer_apellido,
        c.segundo_apellido
    ) AS nombre_completo,
    c.estatus_colaborador,
    COUNT(i.id_inactividad) AS total_novedades,
    SUM(CASE WHEN i.estado_actual = 1 THEN 1 ELSE 0 END) AS novedades_abiertas
FROM colaboradores c
INNER JOIN tbl_inactividades i
        ON i.id_colaborador = c.id_colaborador
GROUP BY
    c.id_colaborador,
    c.id_cc,
    nombre_completo,
    c.estatus_colaborador;


CREATE OR REPLACE VIEW vista_colaboradores_con_novedades_detalles AS

SELECT 
    i.id_inactividad,
    i.id_colaborador,
    i.tipo_inactividad,
    i.fecha_inicio,
    i.fecha_fin,
    i.fecha_registro,
    CONCAT_WS(' ', c.primer_nombre, c.primer_apellido) AS registrado_por,
    i.estado_actual,
    CASE 
        WHEN i.estado_actual = 1 THEN 'Abierta'
        WHEN i.estado_actual = 0 THEN 'Cerrada'
        ELSE 'Desconocido'
    END AS estatus
FROM tbl_inactividades i
JOIN colaboradores c ON c.id_colaborador = i.registrado_por
ORDER BY i.fecha_inicio DESC;


-- ###############################  Vistas Informes Planta  ###############################################

-- Planta PYP
CREATE OR REPLACE VIEW vista_planta_pyp AS
SELECT 
    RET.fecha_retiro,
    CR_DETALLE.motivo,
    CON.fecha_ingreso,
    DAY(CON.fecha_ingreso) AS dia_ingreso,
    ELT(MONTH(CON.fecha_ingreso), 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC') AS mes_ingreso,
    YEAR(CON.fecha_ingreso) AS año_ingreso,
    COL.planta,
    COL.estatus_colaborador,
    COL.tipo_id,
    COL.id_cc,
    CIUD.nombre AS lugar_expedicion,
    COL.fecha_expedicion,
    COL.primer_nombre,
    COL.segundo_nombre,
    COL.primer_apellido,
    COL.segundo_apellido,
    CONCAT(
        COL.primer_nombre, ' ',
        IFNULL(COL.segundo_nombre, ''), ' ',
        COL.primer_apellido, ' ',
        COL.segundo_apellido) AS nombre_completo,
    
    COL.fecha_nacimiento,
    DAY(COL.fecha_nacimiento) AS dia_nacimiento,
    ELT(MONTH(COL.fecha_nacimiento), 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC') AS mes_nacimiento,
    YEAR(COL.fecha_nacimiento) AS año_nacimiento,
    
    COL.sexo,
    COL.grupo_sanguineo,
    COL.rh,
    COL.estado_civil,
    COL.direccion,
    COL.barrio,

    -- CONTACTO PERSONAL
    CONTACTO_EMAIL.valor AS email_personal,
    CONTACTO_MOVIL.valor AS movil_personal,

    -- CONTRATO
    CON_DETALLE.tipo_contrato,
    CON_DETALLE.termino_meses,
    CON_DETALLE.forma_pago,
    
    ROL.cargo,
    COS.centro_costo,
    CIU.nombre AS ciudad,

    -- FINANCIEROS
    CON_DETALLE.salario_base,
    CON_DETALLE.aux_transporte, 
    CON_DETALLE.aux_alimentacion,
    CON_DETALLE.rodamiento,
    
    IF(CON_DETALLE.salario_integral = 1, 'SI', 'NO') AS salario_integral,
    
    (IFNULL(CON_DETALLE.salario_base, 0) + 
     IFNULL(CON_DETALLE.aux_alimentacion, 0) + 
     IFNULL(CON_DETALLE.aux_transporte, 0) + 
     IFNULL(CON_DETALLE.rodamiento, 0)) AS salario_mes,
    
    ROL.rol AS area_trabajo,
    CON_DETALLE.num_ultimo_otro_si,

    -- BANCARIOS
    CBA.tipo_cuenta,
    CBA.num_cuenta,
    BAN.nombre_banco,
    BAN.cta_contable_banco,

    -- SEGURIDAD SOCIAL
    SS.cesantias,
    SS.pension,
    SS.eps,
    SS.arl,
    SS.riesgo,
    SS.ccf,
    
    COL.fecha_emo,
    COL.fecha_proximo_emo,
    
    -- CALCULOS EMO
    DATEDIFF(COL.fecha_proximo_emo, COL.fecha_emo) AS dias_disponibles,
    IF(DATEDIFF(COL.fecha_proximo_emo, COL.fecha_emo) <= 60, 'APLICA', 'NO APLICA') AS estado_emo,
    
    -- EDAD (Ajuste fijo -5 horas para evitar error de variable en VISTA)
    TIMESTAMPDIFF(YEAR, COL.fecha_nacimiento, DATE_SUB(NOW(), INTERVAL 5 HOUR)) AS edad,
    
    COL.formacion_academica,
    COL.estado_formacion_academica,
    COL.estrato,
    
    -- DATOS DE NACIMIENTO
    CIUD_NAC.nombre AS lugar_nacimiento, 
    DEP_NAC.nombre AS departamento_nacimiento,
    PAIS_NAC.nombre AS pais_nacimiento,

    -- TOTAL BENEFICIARIOS
    IF(IFNULL(BEN_COUNT.total, 0) > 0, 'SI', 'NO') AS personas_a_cargo,
    IFNULL(BEN_COUNT.total, 0) AS numero,

    COL.contacto_emergencia,
    COL.telefono_contacto_emergencia,

    DEP.nombre AS departamento,
    
    CONCAT(
        IFNULL(JEFE.primer_nombre, ''), ' ', 
        IFNULL(JEFE.primer_apellido, '')
    ) AS jefe_inmediato,

    CON_DETALLE.turno,
    CONTACTO_CORP.valor AS correo_corporativo,
    
    -- CONDUCTORES
    CASE 
        WHEN ROL.cargo LIKE '%Conductor%' THEN LIC.tipo_licencia
        ELSE 'N/A'
    END AS tipo_licencia,
    
    CASE 
        WHEN ROL.cargo LIKE '%Conductor%' THEN LIC.fecha_vencimiento_lic
        ELSE NULL 
    END AS fecha_vencimiento_lic,

    -- DOTACIÓN
    DOT.talla_pantalon,
    DOT.talla_camisa,
    DOT.talla_botas,
    ENTREGA_DOT.fecha_entrega AS fecha_entrega_dotacion,

    -- PERIODO DE PRUEBA Y CARNET
    COL.fecha_elaboracion_carnet,
    CON_DETALLE.dias_pp,

    DATE_ADD(CON.fecha_ingreso, INTERVAL CON_DETALLE.dias_pp DAY) AS pp_vence,

    GREATEST(0, DATEDIFF(
        DATE_ADD(CON.fecha_ingreso, INTERVAL CON_DETALLE.dias_pp DAY), 
        DATE_SUB(NOW(), INTERVAL 5 HOUR)
    )) AS dias_disponibles_pp,

    IF(
        GREATEST(0, DATEDIFF(
            DATE_ADD(CON.fecha_ingreso, INTERVAL CON_DETALLE.dias_pp DAY), 
            DATE_SUB(NOW(), INTERVAL 5 HOUR)
        )) > 0, 
        'Vigente', 
        'Vencido'
    ) AS estado_pp,

    IF(CON_DETALLE.contrato = 1, 'OK', NULL) AS contrato,
    IF(COL.ruta_induccion = 1, 'OK', NULL) AS ruta_induccion,

    -- =========================================================================
    -- BENEFICIARIOS PIVOTADOS (Límite 4) - EDADES AJUSTADAS
    -- =========================================================================
    
    BEN_PIVOT.nombre_1 AS nombre_beneficiario_1,
    BEN_PIVOT.genero_1 AS genero_beneficiario_1,
    BEN_PIVOT.nac_1 AS fecha_nacimiento_beneficiario_1,
    TIMESTAMPDIFF(YEAR, BEN_PIVOT.nac_1, DATE_SUB(NOW(), INTERVAL 5 HOUR)) AS edad_benef_1,

    BEN_PIVOT.nombre_2 AS nombre_beneficiario_2,
    BEN_PIVOT.genero_2 AS genero_beneficiario_2,
    BEN_PIVOT.nac_2 AS fecha_nacimiento_beneficiario_2,
    TIMESTAMPDIFF(YEAR, BEN_PIVOT.nac_2, DATE_SUB(NOW(), INTERVAL 5 HOUR)) AS edad_benef_2,

    BEN_PIVOT.nombre_3 AS nombre_beneficiario_3,
    BEN_PIVOT.genero_3 AS genero_beneficiario_3,
    BEN_PIVOT.nac_3 AS fecha_nacimiento_beneficiario_3,
    TIMESTAMPDIFF(YEAR, BEN_PIVOT.nac_3, DATE_SUB(NOW(), INTERVAL 5 HOUR)) AS edad_benef_3,

    BEN_PIVOT.nombre_4 AS nombre_beneficiario_4,
    BEN_PIVOT.genero_4 AS genero_beneficiario_4,
    BEN_PIVOT.nac_4 AS fecha_nacimiento_beneficiario_4,
    TIMESTAMPDIFF(YEAR, BEN_PIVOT.nac_4, DATE_SUB(NOW(), INTERVAL 5 HOUR)) AS edad_benef_4

FROM colaboradores COL

-- JOIN Fecha Ingreso
LEFT JOIN (
    SELECT id_colaborador, MAX(fecha_ingreso) AS fecha_ingreso
    FROM contratos GROUP BY id_colaborador
) AS CON ON COL.id_colaborador = CON.id_colaborador

LEFT JOIN contratos CON_DETALLE
    ON CON.id_colaborador = CON_DETALLE.id_colaborador 
    AND CON.fecha_ingreso = CON_DETALLE.fecha_ingreso

-- JOIN Retiro
LEFT JOIN (
    SELECT id_colaborador, MAX(fecha_retiro) AS fecha_retiro
    FROM colaboradores_retirados GROUP BY id_colaborador
) AS RET ON COL.id_colaborador = RET.id_colaborador

LEFT JOIN colaboradores_retirados CR_DETALLE 
    ON RET.id_colaborador = CR_DETALLE.id_colaborador 
    AND RET.fecha_retiro = CR_DETALLE.fecha_retiro

-- JOINS Geográficos
LEFT JOIN ciudades CIU ON COL.sede = CIU.id_ciudad
LEFT JOIN ciudades CIUD ON COL.lugar_expedicion = CIUD.id_ciudad
LEFT JOIN ciudades CIUD_NAC ON COL.ciudad_nacimiento = CIUD_NAC.id_ciudad
LEFT JOIN departamentos_col DEP_NAC ON COL.departamento_nacimiento = DEP_NAC.departamento_id
LEFT JOIN paises PAIS_NAC ON COL.pais_nacimiento = PAIS_NAC.pais_id

-- JOIN Centro Costos
LEFT JOIN centro_costos COS 
    ON COS.id_centro_costo = (
        SELECT c2.id_centro_costo
        FROM contratos c2
        WHERE c2.id_colaborador = COL.id_colaborador
        ORDER BY c2.fecha_ingreso DESC
        LIMIT 1
    )

LEFT JOIN roles ROL ON COL.cargo = ROL.id_rol

-- JOIN BANCARIO (Anti-Duplicados)
LEFT JOIN cuentas_bancarias_colaboradores CBA
    ON CBA.cuenta_id = (
        SELECT MAX(c2.cuenta_id) 
        FROM cuentas_bancarias_colaboradores c2 
        WHERE c2.id_colaborador = COL.id_colaborador
    )
LEFT JOIN bancos BAN ON CBA.banco_id = BAN.banco_id
 
-- CONTACTOS (Anti-Duplicados)
LEFT JOIN contactos_colaboradores CONTACTO_EMAIL
    ON CONTACTO_EMAIL.id_contacto = (
        SELECT MAX(c3.id_contacto)
        FROM contactos_colaboradores c3
        WHERE c3.id_colaborador = COL.id_colaborador
        AND c3.tipo = 'email_personal'
    )

LEFT JOIN contactos_colaboradores CONTACTO_MOVIL
    ON CONTACTO_MOVIL.id_contacto = (
        SELECT MAX(c4.id_contacto)
        FROM contactos_colaboradores c4
        WHERE c4.id_colaborador = COL.id_colaborador
        AND c4.tipo = 'movil_personal'
    )

LEFT JOIN contactos_colaboradores CONTACTO_CORP
    ON CONTACTO_CORP.id_contacto = (
        SELECT MAX(c5.id_contacto)
        FROM contactos_colaboradores c5
        WHERE c5.id_colaborador = COL.id_colaborador
        AND c5.tipo = 'email_corporativo'
    )

-- Resto de Joins
LEFT JOIN seguridad_social SS ON COL.id_colaborador = SS.id_empleado

-- CONTEO DE BENEFICIARIOS
LEFT JOIN (
    SELECT id_colaborador, COUNT(*) AS total 
    FROM beneficiarios GROUP BY id_colaborador
) AS BEN_COUNT ON COL.id_colaborador = BEN_COUNT.id_colaborador

LEFT JOIN colaboradores JEFE ON COL.id_jefe = JEFE.id_colaborador
LEFT JOIN departamentos DEP ON COL.departamento = DEP.departamento_id
LEFT JOIN conductores LIC ON COL.id_colaborador = LIC.id_colaborador

-- TALLAS (Anti-Duplicados)
LEFT JOIN tallas_dotacion DOT 
    ON DOT.id_talla = (
        SELECT MAX(t.id_talla) 
        FROM tallas_dotacion t 
        WHERE t.id_colaborador = COL.id_colaborador
    )

-- ENTREGA DOTACIÓN (Anti-Duplicados)
LEFT JOIN dotacion ENTREGA_DOT
    ON ENTREGA_DOT.id_entrega = (
        SELECT MAX(d.id_entrega)
        FROM dotacion d
        WHERE d.id_colaborador = COL.id_colaborador
    )

-- LOGICA DE PIVOTEO BENEFICIARIOS
LEFT JOIN (
    SELECT 
        id_colaborador,
        MAX(CASE WHEN rn = 1 THEN nombre END) AS nombre_1,
        MAX(CASE WHEN rn = 1 THEN genero END) AS genero_1,
        MAX(CASE WHEN rn = 1 THEN fecha_nacimiento END) AS nac_1,
        
        MAX(CASE WHEN rn = 2 THEN nombre END) AS nombre_2,
        MAX(CASE WHEN rn = 2 THEN genero END) AS genero_2,
        MAX(CASE WHEN rn = 2 THEN fecha_nacimiento END) AS nac_2,
        
        MAX(CASE WHEN rn = 3 THEN nombre END) AS nombre_3,
        MAX(CASE WHEN rn = 3 THEN genero END) AS genero_3,
        MAX(CASE WHEN rn = 3 THEN fecha_nacimiento END) AS nac_3,
        
        MAX(CASE WHEN rn = 4 THEN nombre END) AS nombre_4,
        MAX(CASE WHEN rn = 4 THEN genero END) AS genero_4,
        MAX(CASE WHEN rn = 4 THEN fecha_nacimiento END) AS nac_4
    FROM (
        SELECT 
            id_colaborador,
            nombre,
            genero,
            fecha_nacimiento,
            ROW_NUMBER() OVER(PARTITION BY id_colaborador ORDER BY fecha_nacimiento DESC) as rn
        FROM beneficiarios
    ) AS b_ranked
    WHERE rn <= 4
    GROUP BY id_colaborador
) AS BEN_PIVOT ON COL.id_colaborador = BEN_PIVOT.id_colaborador

ORDER BY COL.primer_nombre, COL.primer_apellido;


-- vista para presentacion datos Auxiliares Terceros

CREATE OR REPLACE VIEW vista_auxiliares_terceros_seguridad AS
select 
	aut.auxiliar_id,
    aut.fecha as ingreso,
    aut.tipo_documento AS tipo_id,
    aut.documento,
    aut.fecha_nacimiento AS f_nacim,
    aut.nombre,
    aut.grupo_sanguineo AS g_sang,
    aut.rh,
    aut.direccion,
    aut.ciudad,
    c.nombre AS n_ciudad,
    aut.eps,
    aut.arl,
    aut.estatus,
    aut.fecha_nuevo_estatus

FROM auxiliares_terceros aut
JOIN ciudades c ON aut.ciudad = c.id_ciudad
ORDER BY aut.auxiliar_id;

-- Vista utilitaria para ver las motos/motocarros en una consulta sin repeticiones

CREATE OR REPLACE VIEW vista_motos_distinct AS
SELECT DISTINCT
    m.id_vehiculo,
    m.placa,
    m.tipo,
    m.marca,
    m.modelo,
    m.anio,
    m.id_base,
    m.capacidad,
    m.estado,
    m.fecha_vencimiento_soat,
    m.ans
FROM motos_motocarros_terceros m
ORDER BY m.placa;


-- Vista de personas con sus motos y roles

CREATE OR REPLACE VIEW vista_personas_motos AS
SELECT
    p.id_persona,
    p.nombre,
    p.identificacion,
    p.telefono1,
    p.direccion,
    p.ciudad,
    p.estado,
    m.id_vehiculo,
    m.placa,
    mp.roles
FROM proveedores_motos_terceros p
LEFT JOIN moto_persona_tercero mp ON p.id_persona = mp.id_persona
LEFT JOIN motos_motocarros_terceros m ON mp.id_vehiculo = m.id_vehiculo
ORDER BY p.nombre, m.placa;


-- vista de personas sin relacion con motos NUEVAS
CREATE OR REPLACE VIEW vista_personas_sin_relacion_moto AS
SELECT
    p.id_persona,
    p.nombre,
    p.identificacion,
    p.estado
FROM proveedores_motos_terceros p
ORDER BY p.nombre;


-- vista informe vitácora seguridad
CREATE OR REPLACE VIEW vista_reporte_bitacora_seguridad AS

-- =============================================
-- BLOQUE 1: Datos de TRAFICO AVANSAT
-- =============================================
SELECT 
    b.entrada_id,
    b.fecha,
    b.turno,
    
    -- Concatenación para quien ENTREGA (Maneja nulos automáticamente)
    CONCAT_WS(' ', c_ent.primer_nombre, c_ent.segundo_nombre, c_ent.primer_apellido, c_ent.segundo_apellido) AS controlador_entrega,
    
    -- Concatenación para quien RECIBE
    CONCAT_WS(' ', c_rec.primer_nombre, c_rec.segundo_nombre, c_rec.primer_apellido, c_rec.segundo_apellido) AS controlador_recibe,
    
    b.observaciones,
    'TRAFICO AVANSAT' AS tipo_registro,
    t.cliente,
    t.cant_vehiculos,
    NULL AS placa,
    NULL AS detalle_noplanillado

FROM bitacora_operacion_trafico b
-- Primer Join: Para obtener el nombre de quien entrega
LEFT JOIN colaboradores c_ent ON b.controlador_entrega = c_ent.id_colaborador
-- Segundo Join: Para obtener el nombre de quien recibe
LEFT JOIN colaboradores c_rec ON b.controlador_recibe = c_rec.id_colaborador
-- Join con la tabla de detalle específica
JOIN trafico_avansat t ON b.entrada_id = t.entrada_id

UNION ALL

-- =============================================
-- BLOQUE 2: Datos de NO PLANILLADOS
-- =============================================
SELECT 
    b.entrada_id,
    b.fecha,
    b.turno,
    
    CONCAT_WS(' ', c_ent.primer_nombre, c_ent.segundo_nombre, c_ent.primer_apellido, c_ent.segundo_apellido),
    CONCAT_WS(' ', c_rec.primer_nombre, c_rec.segundo_nombre, c_rec.primer_apellido, c_rec.segundo_apellido),
    
    b.observaciones,
    'NO PLANILLADO' AS tipo_registro,
    NULL,
    NULL,
    n.placa,
    n.detalle

FROM bitacora_operacion_trafico b
LEFT JOIN colaboradores c_ent ON b.controlador_entrega = c_ent.id_colaborador
LEFT JOIN colaboradores c_rec ON b.controlador_recibe = c_rec.id_colaborador
JOIN no_planillados_avansat n ON b.entrada_id = n.entrada_id
ORDER BY entrada_id;


CREATE OR REPLACE VIEW vista_botones_panico AS
SELECT 
    b.id_prueba,
    b.fecha,
    b.hora_solicitud_activacion,
    b.tiempo_respuesta,
    b.placa_vehiculo,
    b.empresa_satelital,
    b.tipo_flota,
    b.ubicaciones_vehiculo,
    b.novedades,
    b.observaciones,
    b.gestion,
    b.fecha_cierre_novedad,
    -- Concatenamos el nombre, si no hay controlador sale vacío pero no borra el registro
    CONCAT_WS(' ', c.primer_nombre, c.segundo_nombre, c.primer_apellido, c.segundo_apellido) AS controlador
    
FROM botones_panico b
LEFT JOIN colaboradores c ON b.controlador = c.id_colaborador
ORDER BY id_prueba;




