-- Ponemos todos los posts en hora de Caracas de hoy domingo
UPDATE Publica
SET fechaPublicacion = CURRENT_TIMESTAMP AT TIME ZONE 'America/Caracas';