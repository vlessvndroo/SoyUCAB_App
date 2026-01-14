-- 1. Cambiamos de identidad al Auditor
SET ROLE user_auditor;
-- (El auditor no necesita app.current_ente_id porque no tiene datos propios)

-- 2. Prueba de Acceso Prohibido
-- DEBERÍA: Dar error rojo "permission denied for table persona"
SELECT * FROM Persona;

-- 3. Prueba de Acceso Permitido (Vistas)
-- DEBERÍA: Mostrar la tabla de resumen estadístico
SELECT * FROM vw_estadisticas_anonimas;