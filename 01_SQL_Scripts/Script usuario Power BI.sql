-- 1. Crear usuario
CREATE USER 'powerbi_user'@'%' IDENTIFIED BY 'Clave_segura';

-- 2. Dar permiso de lectura a toda la base de datos (incluye tablas y vistas)
GRANT SELECT ON pypdb.* TO 'powerbi_user'@'%';

-- 3. Aplicar cambios
FLUSH PRIVILEGES;

GRANT USAGE ON *.* TO 'powerbi_user'@'%';
GRANT SHOW DATABASES ON *.* TO 'powerbi_user'@'%';
GRANT SELECT ON PYPdb.* TO 'powerbi_user'@'%';
FLUSH PRIVILEGES;


SELECT user, host 
FROM mysql.user;
