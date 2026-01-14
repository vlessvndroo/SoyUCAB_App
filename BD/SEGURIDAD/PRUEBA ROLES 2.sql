-- 1. Cambiamos de identidad a la Escuela
SET ROLE user_escuela;
SET app.current_ente_id = '100'; -- ID de la Escuela de Informática

-- 2. Prueba de Lectura (Eventos)
-- DEBERÍA: Mostrar solo eventos organizados por la ID 100.
-- Si ves eventos de otras escuelas, la política falló.
SELECT * FROM Evento;

-- 3. Prueba de Inserción (Nuevo Evento)
-- DEBERÍA: Permitirlo
INSERT INTO Evento (id_evento, nombre, tipo, fechaHoraInicio, lugar, estado)
VALUES (999, 'Evento Privado Escuela', 'taller', NOW(), 'Lab', 'borrador');

-- IMPORTANTE: Para que la política te deje ver este nuevo evento,
-- debes insertarte también como organizador inmediatamente (en una app real es una transacción)
-- Nota: Como user_escuela no tiene permiso directo en Organizador_Evento para escribir,
-- esta parte suele hacerla un SP con permisos elevados definidos con SECURITY DEFINER.
-- Para esta prueba simple, el SELECT de arriba es suficiente para validar la visión.