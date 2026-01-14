/* ==========================================================================
 * 05_SEGURIDAD_ROLES.sql
 * Gestión de Usuarios, Roles, Permisos y RLS
 * ========================================================================== */

SET ROLE postgres;

-- 1. LIMPIEZA PREVIA (Eliminar roles y políticas anteriores)
DO $$
BEGIN
    -- Revocar permisos antes de borrar
    EXECUTE 'REVOKE ALL ON DATABASE soyucab_db FROM rol_usuario_comun, rol_institucional, rol_auditor';
    EXECUTE 'REVOKE ALL ON SCHEMA public FROM app_backend';
    EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM app_backend';
    EXECUTE 'REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM app_backend';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DROP USER IF EXISTS app_backend;
DROP ROLE IF EXISTS user_javier;
DROP ROLE IF EXISTS user_escuela;
DROP ROLE IF EXISTS user_auditor;

-- Eliminar políticas antiguas (Cascada se encarga, pero aseguramos)
DROP POLICY IF EXISTS policy_persona_propia ON Persona;
DROP POLICY IF EXISTS policy_ver_publicaciones ON Publicacion;

-- Eliminar roles principales
DROP OWNED BY rol_usuario_comun; DROP ROLE IF EXISTS rol_usuario_comun;
DROP OWNED BY rol_institucional; DROP ROLE IF EXISTS rol_institucional;
DROP OWNED BY rol_auditor; DROP ROLE IF EXISTS rol_auditor;
DROP OWNED BY rol_admin_dba; DROP ROLE IF EXISTS rol_admin_dba;


-- 2. CREACIÓN DE ROLES Y USUARIO DE LA APP
CREATE ROLE rol_admin_dba WITH LOGIN PASSWORD 'admin123' SUPERUSER;
CREATE ROLE rol_usuario_comun WITH NOLOGIN;
CREATE ROLE rol_institucional WITH NOLOGIN;
CREATE ROLE rol_auditor WITH NOLOGIN;

-- Usuario técnico para Flask
CREATE USER app_backend WITH PASSWORD 'soyucab_pass';
GRANT CONNECT ON DATABASE soyucab_db TO app_backend;
GRANT USAGE ON SCHEMA public TO app_backend;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_backend;

-- Asignar roles al usuario de la app (para que pueda hacer SET ROLE)
GRANT rol_usuario_comun TO app_backend;
GRANT rol_institucional TO app_backend;
GRANT rol_auditor TO app_backend;
GRANT rol_admin_dba TO app_backend;


-- 3. ASIGNACIÓN DE PERMISOS (GRANTS)
GRANT CONNECT ON DATABASE soyucab_db TO rol_usuario_comun, rol_institucional, rol_auditor;
GRANT USAGE ON SCHEMA public TO rol_usuario_comun, rol_institucional, rol_auditor;

-- A) ROL USUARIO COMÚN
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_usuario_comun;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_usuario_comun;
-- Permiso para usar el procedimiento de borrado seguro
GRANT EXECUTE ON PROCEDURE sp_eliminar_publicacion(INT, INT, BOOLEAN) TO rol_usuario_comun, rol_institucional, rol_admin_dba;
-- Permisos de Escritura
GRANT INSERT ON Ente, Persona, Nexo_Institucional, Forma_Parte_De TO rol_usuario_comun;
GRANT UPDATE (nombre, apellido, ocupacion) ON Persona TO rol_usuario_comun;
GRANT UPDATE (ubicacion_pais, ubicacion_estado, ubicacion_ciudad, direccion_detalle, visibilidad_perfil) ON Ente TO rol_usuario_comun;
GRANT INSERT, UPDATE, DELETE ON Telefono, Es_Poseida TO rol_usuario_comun;
GRANT INSERT, DELETE ON Publicacion, Publica, Reaccion, Comentario TO rol_usuario_comun;
GRANT INSERT, UPDATE, DELETE ON Relacion, Notificacion TO rol_usuario_comun;
GRANT INSERT, DELETE ON Membresia_Grupo, Asistencia_Evento, Esta_Suscrito TO rol_usuario_comun;
-- Registro de Instituciones (desde el formulario público)
GRANT INSERT ON Dependencia_UCAB, Organizacion_Asociada TO rol_usuario_comun;

-- B) ROL INSTITUCIONAL
GRANT SELECT ON Ente, Dependencia_UCAB, Organizacion_Asociada TO rol_institucional;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_institucional;
GRANT SELECT, INSERT, UPDATE, DELETE ON Evento TO rol_institucional;
GRANT SELECT, INSERT ON Organizador_Evento TO rol_institucional;
GRANT SELECT, INSERT ON Notificacion TO rol_institucional;

-- C) ROL AUDITOR
GRANT SELECT ON vw_estadisticas_anonimas TO rol_auditor; -- Solo ve la vista segura


-- 4. ACTIVAR ROW LEVEL SECURITY (RLS)
ALTER TABLE Ente ENABLE ROW LEVEL SECURITY;
ALTER TABLE Persona ENABLE ROW LEVEL SECURITY;
ALTER TABLE Telefono ENABLE ROW LEVEL SECURITY;
ALTER TABLE Publicacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE Notificacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE Relacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE Es_Poseida ENABLE ROW LEVEL SECURITY;
ALTER TABLE Asistencia_Evento ENABLE ROW LEVEL SECURITY;
ALTER TABLE Membresia_Grupo ENABLE ROW LEVEL SECURITY;
ALTER TABLE Evento ENABLE ROW LEVEL SECURITY;
ALTER TABLE Dependencia_UCAB ENABLE ROW LEVEL SECURITY;
ALTER TABLE Organizacion_Asociada ENABLE ROW LEVEL SECURITY;


-- 5. DEFINICIÓN DE POLÍTICAS (POLICIES)

-- --- POLÍTICAS USUARIO COMÚN ---
-- Ver perfiles públicos
CREATE POLICY policy_ver_personas_publico ON Persona FOR SELECT TO rol_usuario_comun USING (true);
CREATE POLICY policy_ver_entes_publicos ON Ente FOR SELECT TO rol_usuario_comun USING (true);

-- Registro y Edición Propia
CREATE POLICY policy_registro_persona ON Persona FOR INSERT TO rol_usuario_comun WITH CHECK (true);
CREATE POLICY policy_registro_ente ON Ente FOR INSERT TO rol_usuario_comun WITH CHECK (true);
CREATE POLICY policy_editar_persona_propia ON Persona FOR UPDATE TO rol_usuario_comun USING (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_editar_ente_propio ON Ente FOR UPDATE TO rol_usuario_comun USING (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_telefono_propio ON Telefono FOR ALL TO rol_usuario_comun USING (id_ente_persona = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_mis_habilidades ON Es_Poseida FOR ALL TO rol_usuario_comun USING (id_ente_persona = current_setting('app.current_ente_id', true)::INT);

-- Publicaciones (Ver públicas, amigos o propias)
CREATE POLICY policy_ver_publicaciones ON Publicacion FOR SELECT TO rol_usuario_comun
    USING (
        visibilidad = 'publica'
        OR id_publicacion IN (
            SELECT P.id_publicacion FROM Publica P
            WHERE P.id_ente = current_setting('app.current_ente_id', true)::INT
            OR P.id_ente IN (
                SELECT CASE WHEN id_ente1 = current_setting('app.current_ente_id', true)::INT THEN id_ente2 ELSE id_ente1 END
                FROM Relacion
                WHERE (id_ente1 = current_setting('app.current_ente_id', true)::INT OR id_ente2 = current_setting('app.current_ente_id', true)::INT)
                AND tipo = 'amistad' AND estado = 'aceptada'
            )
        )
        OR id_publicacion NOT IN (SELECT id_publicacion FROM Publica) -- Ver recién creadas
    );
CREATE POLICY policy_crear_publicacion ON Publicacion FOR INSERT TO rol_usuario_comun WITH CHECK (true);
CREATE POLICY policy_borrar_publicacion ON Publicacion FOR DELETE TO rol_usuario_comun USING (id_publicacion IN (SELECT id_publicacion FROM Publica WHERE id_ente = current_setting('app.current_ente_id', true)::INT));

-- Relaciones y Notificaciones
CREATE POLICY policy_ver_relaciones ON Relacion FOR SELECT TO rol_usuario_comun USING (true);
CREATE POLICY policy_crear_relacion ON Relacion FOR INSERT TO rol_usuario_comun WITH CHECK (id_ente1 = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_aceptar_relacion ON Relacion FOR UPDATE TO rol_usuario_comun USING (id_ente2 = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_borrar_relacion ON Relacion FOR DELETE TO rol_usuario_comun USING (id_ente1 = current_setting('app.current_ente_id', true)::INT OR id_ente2 = current_setting('app.current_ente_id', true)::INT);

CREATE POLICY policy_ver_mis_notificaciones ON Notificacion FOR SELECT TO rol_usuario_comun USING (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_crear_notificacion ON Notificacion FOR INSERT TO rol_usuario_comun WITH CHECK (true);
CREATE POLICY policy_actualizar_notificacion ON Notificacion FOR UPDATE TO rol_usuario_comun USING (id_ente = current_setting('app.current_ente_id', true)::INT);

CREATE POLICY policy_gestionar_asistencia ON Asistencia_Evento FOR ALL TO rol_usuario_comun USING (id_ente_persona = current_setting('app.current_ente_id', true)::INT) WITH CHECK (id_ente_persona = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_gestionar_membresia ON Membresia_Grupo FOR ALL TO rol_usuario_comun USING (id_ente = current_setting('app.current_ente_id', true)::INT) WITH CHECK (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_ver_eventos_publicos ON Evento FOR SELECT TO rol_usuario_comun USING (estado IN ('publicado', 'finalizado', 'en-curso'));


-- --- POLÍTICAS ROL INSTITUCIONAL ---
CREATE POLICY policy_ver_mi_dependencia ON Dependencia_UCAB FOR SELECT TO rol_institucional USING (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_ver_mi_organizacion ON Organizacion_Asociada FOR SELECT TO rol_institucional USING (id_ente = current_setting('app.current_ente_id', true)::INT);
CREATE POLICY policy_ver_ente_inst ON Ente FOR SELECT TO rol_institucional USING (id_ente = current_setting('app.current_ente_id', true)::INT);

-- Gestión Eventos Institucionales
CREATE POLICY policy_institucional_insert ON Evento FOR INSERT TO rol_institucional WITH CHECK (true);
CREATE POLICY policy_institucional_select ON Evento FOR SELECT TO rol_institucional
    USING (
        id_evento IN (SELECT id_evento FROM Organizador_Evento WHERE id_ente = current_setting('app.current_ente_id', true)::INT)
        OR id_evento NOT IN (SELECT id_evento FROM Organizador_Evento) -- Ver recién creados
    );
CREATE POLICY policy_institucional_modificar ON Evento FOR UPDATE TO rol_institucional USING (id_evento IN (SELECT id_evento FROM Organizador_Evento WHERE id_ente = current_setting('app.current_ente_id', true)::INT));
CREATE POLICY policy_institucional_borrar ON Evento FOR DELETE TO rol_institucional USING (id_evento IN (SELECT id_evento FROM Organizador_Evento WHERE id_ente = current_setting('app.current_ente_id', true)::INT));

-- 1. Eliminar restricciones viejas (Candados)
ALTER TABLE Publica DROP CONSTRAINT IF EXISTS fk_publica_pub;
ALTER TABLE Comentario DROP CONSTRAINT IF EXISTS fk_com_pub;
ALTER TABLE Reaccion DROP CONSTRAINT IF EXISTS fk_reaccion_pub;

-- 2. Crear restricciones nuevas con "Modo Demolición" (ON DELETE CASCADE)
-- Esto permite que al borrar la Publicación, se borre todo lo de adentro automáticamente.

ALTER TABLE Publica
    ADD CONSTRAINT fk_publica_pub FOREIGN KEY (id_publicacion)
    REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE;

ALTER TABLE Comentario
    ADD CONSTRAINT fk_com_pub FOREIGN KEY (id_publicacion)
    REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE;

ALTER TABLE Reaccion
    ADD CONSTRAINT fk_reaccion_pub FOREIGN KEY (id_publicacion)
    REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE;