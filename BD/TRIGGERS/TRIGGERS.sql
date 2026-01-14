/* ==============================================================
 * 03_TRIGGERS.sql
 * ============================================================== */

-- 1. Validar Representante Único
CREATE OR REPLACE FUNCTION fn_trigger_validar_representante()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.rol IN ('Lider', 'Representante') THEN
        IF EXISTS (SELECT 1 FROM Membresia_Grupo WHERE id_grupo = NEW.id_grupo AND rol = NEW.rol AND id_ente <> NEW.id_ente) THEN
            RAISE EXCEPTION 'Error: El grupo ya tiene un % activo.', NEW.rol;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_validar_representante_unico
BEFORE INSERT OR UPDATE ON Membresia_Grupo
FOR EACH ROW EXECUTE FUNCTION fn_trigger_validar_representante();

-- 2. Trigger Conteo Asistentes (con SECURITY DEFINER)
CREATE OR REPLACE FUNCTION fn_trigger_conteo_inscritos()
RETURNS TRIGGER 
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE Evento SET cantidad_asistentes = COALESCE(cantidad_asistentes, 0) + 1 WHERE id_evento = NEW.id_evento;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE Evento SET cantidad_asistentes = GREATEST(cantidad_asistentes - 1, 0) WHERE id_evento = OLD.id_evento;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_mantener_conteo_inscritos
AFTER INSERT OR DELETE ON Asistencia_Evento
FOR EACH ROW EXECUTE FUNCTION fn_trigger_conteo_inscritos();