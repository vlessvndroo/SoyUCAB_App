-- 1. Cambiamos de identidad a Javier
SET ROLE user_javier;
SET app.current_ente_id = '1'; -- Simulamos que el backend nos identificó como ID 1

-- 2. Prueba de Lectura (Notificaciones)
-- DEBERÍA: Mostrar solo las notificaciones donde id_ente = 1
SELECT * FROM Notificacion;

-- 3. Prueba de Escritura Ilegal (Teléfono de otro)
-- Intentamos borrar el teléfono de Kevin (ID 2)
-- DEBERÍA: Ejecutarse sin error pero decir "0 rows affected" (la política se lo oculta)
DELETE FROM Telefono WHERE id_ente_persona = 2;

-- 4. Prueba de Escritura Legal (Su propio teléfono)
-- DEBERÍA: Funcionar correctamente
UPDATE Telefono SET numero = '0414-NUEVO' WHERE id_ente_persona = 1;

---------------------------------------------------------------------------------------------

SELECT
    current_user;