/* ==============================================================
 * 04_VISTAS_REPORTES.sql
 * Vistas con permisos definidos para los Dashboards
 * ============================================================== */
SET ROLE postgres;

-- 1. Popularidad de Grupos
CREATE OR REPLACE VIEW vw_reporte_popularidad_grupos AS
SELECT G.nombre, 
       COUNT(M.id_ente) as total_miembros,
       CAST(COUNT(M.id_ente) * 100.0 / NULLIF((SELECT COUNT(*) FROM Persona), 0) AS DECIMAL(5,2)) as popularidad
FROM Grupo G
LEFT JOIN Membresia_Grupo M ON G.id_grupo = M.id_grupo
GROUP BY G.id_grupo, G.nombre
ORDER BY 2 DESC LIMIT 5;
ALTER VIEW vw_reporte_popularidad_grupos OWNER TO postgres;

-- 2. Actividad de Grupos
CREATE OR REPLACE VIEW vw_reporte_actividad_grupos AS
SELECT G.nombre, 
       COUNT(EG.id_evento) as eventos, 
       CASE WHEN COUNT(EG.id_evento) >= 2 THEN 'Muy Activo' 
            WHEN COUNT(EG.id_evento) = 1 THEN 'Regular' 
            ELSE 'Sin Actividad' END as estatus
FROM Grupo G
LEFT JOIN Evento_Grupo EG ON G.id_grupo = EG.id_grupo
GROUP BY G.nombre
ORDER BY 2 DESC LIMIT 5;
ALTER VIEW vw_reporte_actividad_grupos OWNER TO postgres;

-- 3. Docentes con Eventos
CREATE OR REPLACE VIEW vw_reporte_docencia AS
SELECT P.nombre || ' ' || P.apellido as docente, 
       COUNT(E.id_evento) as cant_eventos, 
       COALESCE(SUM(EXTRACT(EPOCH FROM (E.fechaHoraFin - E.fechaHoraInicio))/3600), 0) as horas
FROM Persona P 
JOIN Forma_Parte_De FPD ON P.id_ente = FPD.id_persona 
JOIN Nexo_Institucional N ON FPD.TAI = N.TAI 
JOIN Organizador_Evento OE ON P.id_ente = OE.id_ente 
JOIN Evento E ON OE.id_evento = E.id_evento 
WHERE N.tipoNexo = 'Profesor' 
GROUP BY P.id_ente, P.nombre, P.apellido 
ORDER BY 3 DESC LIMIT 5;
ALTER VIEW vw_reporte_docencia OWNER TO postgres;

-- 4. Antigüedad Personal
CREATE OR REPLACE VIEW vw_reporte_antiguedad AS
SELECT P.nombre || ' ' || P.apellido as personal, 
       N.tipoNexo as cargo, 
       N.fechaInicio, 
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, N.fechaInicio)) as anios
FROM Nexo_Institucional N 
JOIN Forma_Parte_De FPD ON N.TAI = FPD.TAI 
JOIN Persona P ON FPD.id_persona = P.id_ente 
WHERE N.tipoNexo IN ('Profesor', 'Empleado') 
ORDER BY N.fechaInicio ASC LIMIT 5;
ALTER VIEW vw_reporte_antiguedad OWNER TO postgres;

-- 5. Tutores Egresados
CREATE OR REPLACE VIEW vw_reporte_tutores AS
SELECT P.nombre || ' ' || P.apellido as tutor, 
       DN.valor as promedio, 
       R.fechaInicio
FROM Persona P 
JOIN Forma_Parte_De FPD ON P.id_ente = FPD.id_persona 
JOIN Nexo_Institucional N ON FPD.TAI = N.TAI 
JOIN Detalle_Nexo DN ON N.TAI = DN.TAI_nexo 
JOIN Relacion R ON P.id_ente = R.id_ente1 
WHERE N.tipoNexo = 'Egresado' AND DN.clave = 'Promedio' AND R.tipo = 'tutoria' 
LIMIT 5;
ALTER VIEW vw_reporte_tutores OWNER TO postgres;

-- 6. Calendario Público
CREATE OR REPLACE VIEW vw_reporte_calendario AS
SELECT nombre, lugar, fechaHoraInicio, estado 
FROM Evento 
WHERE estado IN ('publicado', 'finalizado') 
ORDER BY fechaHoraInicio DESC LIMIT 5;
ALTER VIEW vw_reporte_calendario OWNER TO postgres;

-- 7. Vista para Explorar Grupos (Paginación)
CREATE OR REPLACE VIEW vw_grupos_explorar AS
SELECT 
    G.id_grupo, 
    G.nombre, 
    G.tipoGrupo, 
    G.descripcion,
    COUNT(M.id_ente) as total_miembros
FROM Grupo G
LEFT JOIN Membresia_Grupo M ON G.id_grupo = M.id_grupo AND M.estado = 'activo'
GROUP BY G.id_grupo, G.nombre, G.tipoGrupo, G.descripcion;
ALTER VIEW vw_grupos_explorar OWNER TO postgres;

-- 8. Vista de Auditoría Completa
CREATE OR REPLACE VIEW vw_estadisticas_anonimas AS
SELECT
    (SELECT COUNT(*) FROM Persona) as total_usuarios,
    (SELECT COUNT(*) FROM Grupo) as total_grupos,
    (SELECT COUNT(*) FROM Evento WHERE estado = 'publicado') as eventos_activos,
    (SELECT COUNT(*) FROM Evento WHERE estado = 'finalizado') as eventos_finalizados,
    (SELECT COUNT(*) FROM Organizacion_Asociada) as empresas_aliadas,
    (SELECT COUNT(*) FROM Publicacion) as total_posts,
    (SELECT COUNT(*) FROM Comentario) as total_comentarios;