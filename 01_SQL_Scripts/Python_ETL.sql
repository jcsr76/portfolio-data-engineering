-- Crear usuario para Python
CREATE USER 'python_user'@'%' IDENTIFIED BY 'Contraseña_segura';

-- Permiso de usar la base pypdb, solo puede verla o conectarse ya que no tienen ningún otro permiso SELECT, UPDATE, INSERT O DELETE permisos básicos
GRANT USAGE ON pypdb.* TO 'python_user'@'%';
GRANT EXECUTE ON pypdb.* TO 'python_user'@'%';
-- Puedes añadir aquí vistas específicas más adelante
FLUSH PRIVILEGES;

-- Permisos para procedimientos almacenados
GRANT EXECUTE ON PROCEDURE pypdb.insertar_en_staging_operaciones TO 'python_user'@'%';
GRANT SELECT ON pypdb.log_errores_etl TO 'python_user'@'%';
GRANT EXECUTE ON PROCEDURE pypdb.limpiar_staging_operaciones TO 'python_user'@'%';
GRANT EXECUTE ON PROCEDURE pypdb.registrar_error_etl TO 'python_user'@'%';
GRANT EXECUTE ON PROCEDURE pypdb.sp_sincronizar_operaciones_avansat TO 'python_user'@'%';
GRANT EXECUTE ON PROCEDURE pypdb.registrar_log_conexion TO 'python_user'@'%';

FLUSH PRIVILEGES;


-- Si se tienen muchos procedimientos en el mismo esquema:
GRANT EXECUTE ON nombre_bd.* TO 'python_user'@'localhost';

-- Permisos de lectura solo a vistas
GRANT SELECT ON nombre_bd.nombre_vista TO 'python_user'@'localhost';

-- otorgar acceso a todas las vistas (no tablas) en el esquema, tendrás que listar solo las vistas manualmente, ya que MySQL no diferencia en permisos entre tablas y vistas.
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'nombre_bd';


-- Borrar explícitamente permisos a nivel de esquema
REVOKE SELECT, INSERT, UPDATE, DELETE, EXECUTE ON nombre_bd.* FROM 'python_user'@'localhost';


FLUSH PRIVILEGES;