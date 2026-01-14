/* ==============================================================
 * 02_LOGICA_NEGOCIO.sql
 * Funciones y Procedimientos Almacenados
 * ============================================================== */

-- 1. SP Notificar Evento a Grupo
CREATE OR REPLACE PROCEDURE sp_notificar_evento_grupo(p_id_evento INT, p_id_grupo INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_nombre_evento VARCHAR(100);
    v_miembro RECORD;
BEGIN
    SELECT nombre INTO v_nombre_evento FROM Evento WHERE id_evento = p_id_evento;
    FOR v_miembro IN SELECT id_ente FROM Membresia_Grupo WHERE id_grupo = p_id_grupo AND estado = 'activo' LOOP
        INSERT INTO Notificacion (id_ente, fechaEmision, tipo, estado, contenidoResumen, tipoOrigen)
        VALUES (v_miembro.id_ente, NOW(), 'Evento', 'no-leida', 'Nuevo evento: ' || v_nombre_evento, 'Sistema');
    END LOOP;
END;
$$;

-- 2. Función Verificar Ente Institucional
CREATE OR REPLACE FUNCTION fn_verificar_ente_institucional(p_id_ente INT)
RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Dependencia_UCAB WHERE id_ente = p_id_ente)
       OR EXISTS (SELECT 1 FROM Organizacion_Asociada WHERE id_ente = p_id_ente) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. SP Gestionar Suscripción
CREATE OR REPLACE PROCEDURE sp_gestionar_suscripcion(p_id_ente INT, p_id_grupo INT)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Esta_Suscrito WHERE id_ente = p_id_ente AND id_grupo = p_id_grupo) THEN
        DELETE FROM Esta_Suscrito WHERE id_ente = p_id_ente AND id_grupo = p_id_grupo;
    ELSE
        INSERT INTO Esta_Suscrito (id_ente, id_grupo) VALUES (p_id_ente, p_id_grupo);
    END IF;
END;
$$;

-- 4. Función Antigüedad Miembro
CREATE OR REPLACE FUNCTION fn_calcular_antiguedad_miembro(p_id_ente INT, p_id_grupo INT)
RETURNS INT AS $$
DECLARE
    v_fecha_ingreso DATE;
    v_meses INT;
BEGIN
    SELECT fechaIngreso INTO v_fecha_ingreso FROM Membresia_Grupo WHERE id_ente = p_id_ente AND id_grupo = p_id_grupo;
    IF v_fecha_ingreso IS NULL THEN RETURN 0; END IF;
    SELECT (EXTRACT(YEAR FROM age(NOW(), v_fecha_ingreso)) * 12 + EXTRACT(MONTH FROM age(NOW(), v_fecha_ingreso))) INTO v_meses;
    RETURN v_meses;
END;
$$ LANGUAGE plpgsql;

-- 5. Función Recursiva: Grados de Separación (Clausura Transitiva)
CREATE OR REPLACE FUNCTION fn_camino_conexion(id_origen INT, id_destino INT)
RETURNS TEXT AS $$
WITH RECURSIVE Camino AS (
    -- Caso Base
    SELECT 
        CASE WHEN id_ente1 = id_origen THEN id_ente2 ELSE id_ente1 END as id_amigo,
        1 as grado,
        CAST((SELECT nombre || ' ' || apellido FROM Persona WHERE id_ente = id_origen) || ' ➜ ' || 
             (SELECT nombre || ' ' || apellido FROM Persona WHERE id_ente = (CASE WHEN id_ente1 = id_origen THEN id_ente2 ELSE id_ente1 END)) 
        AS TEXT) as ruta
    FROM Relacion
    WHERE (id_ente1 = id_origen OR id_ente2 = id_origen)
      AND tipo = 'amistad' AND estado = 'aceptada'

    UNION ALL

    -- Paso Recursivo
    SELECT 
        CASE WHEN r.id_ente1 = c.id_amigo THEN r.id_ente2 ELSE r.id_ente1 END,
        c.grado + 1,
        CAST(c.ruta || ' ➜ ' || (SELECT nombre || ' ' || apellido FROM Persona WHERE id_ente = (CASE WHEN r.id_ente1 = c.id_amigo THEN r.id_ente2 ELSE r.id_ente1 END)) AS TEXT)
    FROM Relacion r
    JOIN Camino c ON (r.id_ente1 = c.id_amigo OR r.id_ente2 = c.id_amigo)
    WHERE r.tipo = 'amistad' AND r.estado = 'aceptada'
      AND c.grado < 3 -- Límite de 3 grados
      AND (CASE WHEN r.id_ente1 = c.id_amigo THEN r.id_ente2 ELSE r.id_ente1 END) <> id_origen 
)
SELECT ruta FROM Camino WHERE id_amigo = id_destino ORDER BY grado ASC LIMIT 1;
$$ LANGUAGE sql;