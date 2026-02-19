-- Insertar los usuarios masivamente en la tabla usuarios desde vista_colaboradores sin rol = 3
CALL InsertarUsuarios();
UPDATE usuarios
SET usuario = reemplazar_ene_ene(usuario);


-- Crear los usuarios en MySQL sin permisos basado en los usuarios de la tabla usuarios con contraseña 
CALL CrearUsuariosMySQL();

-- Crear permisos básicos y comunes para todos los usuarios
CALL AsignarPrivilegiosUsuariosMySQL();



