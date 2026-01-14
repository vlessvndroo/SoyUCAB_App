/* ==============================================================
 * SCRIPT MAESTRO "FULL DATA" - CORREGIDO
 * ============================================================== */

-- 0. LIMPIEZA NUCLEAR (Agregada tabla Nexo_Institucional y Telefono explícitamente)
TRUNCATE TABLE
    Ente,
    Nexo_Institucional,
    Grupo,
    Evento,
    Publicacion,
    Idioma,
    Habilidad_Tecnica,
    Area_De_Interes
RESTART IDENTITY CASCADE;

-- ==============================================================
-- 1. IDENTIDAD
-- ==============================================================
INSERT INTO Ente (id_ente, tipo, correoElectronico, ubicacion_pais, ubicacion_estado, ubicacion_ciudad, direccion_detalle) VALUES
-- DEPENDENCIAS
(100, 'Dependencia', 'ingenieria@ucab.edu.ve', 'Venezuela', 'Bolivar', 'Guayana', 'Edif. Ciencias'),
(101, 'Dependencia', 'derecho@ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'Cincuentenario'),
(102, 'Dependencia', 'cultura@ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'Aula Magna'),
(103, 'Dependencia', 'deportes@ucab.edu.ve', 'Venezuela', 'Miranda', 'Caracas', 'Gimnasio'),
-- ORGANIZACIONES
(200, 'Organizacion', 'polar@empresas.com', 'Venezuela', 'Miranda', 'Caracas', 'Los Cortijos'),
(201, 'Organizacion', 'nestle@empresas.com', 'Venezuela', 'Aragua', 'Fabrica', 'Zona Industrial'),
(202, 'Organizacion', 'bancaribe@banco.com', 'Venezuela', 'Distrito Capital', 'Chacao', 'Torre B'),
(203, 'Organizacion', 'google@tech.com', 'USA', 'California', 'Mountain View', 'Plex'),
-- ESTUDIANTES
(1, 'Persona', 'javier@est.ucab.edu.ve', 'Venezuela', 'Miranda', 'Caracas', 'Montalban'),
(2, 'Persona', 'kevin@est.ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'El Paraiso'),
(3, 'Persona', 'fredi@est.ucab.edu.ve', 'Venezuela', 'La Guaira', 'Caribe', 'Av Principal'),
(4, 'Persona', 'maria.perez@est.ucab.edu.ve', 'Venezuela', 'Miranda', 'San Antonio', 'Recta'),
(5, 'Persona', 'jose.gomez@est.ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'Centro'),
(6, 'Persona', 'ana.rodriguez@est.ucab.edu.ve', 'Venezuela', 'Miranda', 'Chacao', 'El Rosal'),
(7, 'Persona', 'sofia.martinez@est.ucab.edu.ve', 'Venezuela', 'Miranda', 'Baruta', 'Las Mercedes'),
(8, 'Persona', 'carlos.lopez@est.ucab.edu.ve', 'Venezuela', 'Miranda', 'Hatillo', 'Oripoto'),
(9, 'Persona', 'luis.fernandez@est.ucab.edu.ve', 'Venezuela', 'Bolivar', 'Puerto Ordaz', 'Alta Vista'),
(10, 'Persona', 'andrea.torres@est.ucab.edu.ve', 'Venezuela', 'Bolivar', 'San Felix', 'Centro'),
-- PROFESORES Y PERSONAL
(30, 'Persona', 'marlene.goncalves@ucab.edu.ve', 'Venezuela', 'La Guaira', 'Catia la Mar', 'Res. Playa'),
(31, 'Persona', 'patricia.wilthew@ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'Urb. Avila'),
(32, 'Persona', 'oscar.perez@ucab.edu.ve', 'Venezuela', 'Miranda', 'Caracas', 'Santa Fe'),
(33, 'Persona', 'yosly.hernandez@ucab.edu.ve', 'Venezuela', 'Miranda', 'Caracas', 'La Trinidad'),
(34, 'Persona', 'jonas.montilva@ucab.edu.ve', 'Venezuela', 'Merida', 'Merida', 'La Hechicera'),
(35, 'Persona', 'carlos.suarez@ucab.edu.ve', 'Venezuela', 'Distrito Capital', 'Caracas', 'San Bernardino'),
(36, 'Persona', 'empleado.juan@ucab.edu.ve', 'Venezuela', 'Miranda', 'Guarenas', 'Villa Panamericana'),
(37, 'Persona', 'empleada.elena@ucab.edu.ve', 'Venezuela', 'Miranda', 'Guatire', 'Castillejo'),
-- EGRESADOS
(50, 'Persona', 'pedro.tutor@gmail.com', 'España', 'Madrid', 'Madrid', 'Centro'),
(51, 'Persona', 'luisa.ingeniera@tech.com', 'USA', 'Florida', 'Miami', 'Brickell'),
(52, 'Persona', 'miguel.gerente@banco.com', 'Panama', 'Panama', 'Costa del Este', 'Torre B'),
(53, 'Persona', 'andres.consultor@big4.com', 'Chile', 'Santiago', 'Las Condes', 'Golf');

-- ==============================================================
-- 2. DETALLES SUBTIPOS
-- ==============================================================
INSERT INTO Dependencia_UCAB (id_ente, nombre, tipoDependencia) VALUES
(100, 'Escuela Ingeniería Informática', 'Escuela'),
(101, 'Escuela de Derecho', 'Escuela'),
(102, 'Dirección de Cultura', 'Agrupacion'),
(103, 'Dirección de Deportes', 'Agrupacion');

INSERT INTO Organizacion_Asociada (id_ente, RIF, nombre, tipoOrganizacion) VALUES
(200, 'J-00001234-5', 'Empresas Polar', 'Empresa'),
(201, 'J-55554444-1', 'Nestlé Venezuela', 'Empresa'),
(202, 'J-99998888-2', 'Bancaribe', 'Empresa'),
(203, 'Ext-001122', 'Google LLC', 'Empresa');

-- Personas
INSERT INTO Persona (id_ente, CI, nombre, apellido, fechaNacimiento, sexo, ocupacion) VALUES
(1, 28111001, 'Javier', 'Di Addezio', '2002-05-20', 'M', 'Estudiante'),
(2, 29111002, 'Kevin', 'Lopez', '2003-08-15', 'M', 'Estudiante'),
(3, 27111003, 'Fredi', 'Airanji', '2001-02-10', 'M', 'Estudiante'),
(4, 30111004, 'Maria', 'Perez', '2004-12-01', 'F', 'Estudiante'),
(5, 30111005, 'Jose', 'Gomez', '2004-01-20', 'M', 'Estudiante'),
(6, 29111006, 'Ana', 'Rodriguez', '2003-05-15', 'F', 'Estudiante'),
(7, 28111007, 'Sofia', 'Martinez', '2002-11-11', 'F', 'Estudiante'),
(8, 28111008, 'Carlos', 'Lopez', '2002-07-07', 'M', 'Estudiante'),
(9, 26111009, 'Luis', 'Fernandez', '2001-03-03', 'M', 'Estudiante'),
(10, 27111010, 'Andrea', 'Torres', '2002-09-09', 'F', 'Estudiante'),
(30, 10111000, 'Marlene', 'Goncalves', '1980-01-01', 'F', 'Profesor Titular'),
(31, 11111000, 'Patricia', 'Wilthew', '1982-05-05', 'F', 'Director Escuela'),
(32, 12111000, 'Oscar', 'Perez', '1975-09-09', 'M', 'Investigador'),
(33, 13111000, 'Yosly', 'Hernandez', '1978-04-14', 'F', 'Coordinador Pasantías'),
(34, 14111000, 'Jonas', 'Montilva', '1960-11-20', 'M', 'Profesor Doctor'),
(35, 15111000, 'Carlos', 'Suarez', '1985-02-28', 'M', 'Profesor Hora'),
(36, 18111000, 'Juan', 'Martinez', '1990-06-15', 'M', 'Técnico Soporte'),
(37, 19111000, 'Elena', 'Rivas', '1992-08-20', 'F', 'Secretaria Académica'),
(50, 15111999, 'Pedro', 'Ramirez', '1992-06-15', 'M', 'Consultor Senior'),
(51, 16111999, 'Luisa', 'Fernandez', '1993-03-30', 'F', 'Tech Lead'),
(52, 17111999, 'Miguel', 'Torres', '1990-12-12', 'M', 'Gerente'),
(53, 17222999, 'Andres', 'Bello', '1989-10-10', 'M', 'Arquitecto Cloud');

-- ==============================================================
-- 3. NEXOS Y EXTENSIBILIDAD
-- ==============================================================
INSERT INTO Nexo_Institucional (TAI, tipoNexo, fechaInicio, estado) VALUES
('TAI-PROF-01', 'Profesor', '1990-01-01', 'activo'),
('TAI-PROF-02', 'Profesor', '2005-09-01', 'activo'),
('TAI-PROF-03', 'Profesor', '2010-03-15', 'activo'),
('TAI-PROF-04', 'Profesor', '2015-01-10', 'activo'),
('TAI-PROF-05', 'Profesor', '2022-09-01', 'activo'),
('TAI-PROF-06', 'Profesor', '2023-09-01', 'activo'),
('TAI-EMP-01', 'Empleado', '2018-05-01', 'activo'),
('TAI-EMP-02', 'Empleado', '2019-11-01', 'activo'),
('TAI-STD-01', 'Estudiante', '2020-09-15', 'activo'),
('TAI-STD-02', 'Estudiante', '2020-09-15', 'activo'),
('TAI-STD-03', 'Estudiante', '2021-03-01', 'activo'),
('TAI-STD-04', 'Estudiante', '2021-03-01', 'activo'),
('TAI-STD-05', 'Estudiante', '2022-09-15', 'activo'),
('TAI-STD-06', 'Estudiante', '2022-09-15', 'activo'),
('TAI-STD-07', 'Estudiante', '2023-03-01', 'activo'),
('TAI-STD-08', 'Estudiante', '2023-03-01', 'activo'),
('TAI-STD-09', 'Estudiante', '2024-09-01', 'activo'),
('TAI-STD-10', 'Estudiante', '2024-09-01', 'activo'),
('TAI-EGR-01', 'Egresado', '2014-07-30', 'historico'),
('TAI-EGR-02', 'Egresado', '2016-07-30', 'historico'),
('TAI-EGR-03', 'Egresado', '2013-07-30', 'historico'),
('TAI-EGR-04', 'Egresado', '2012-07-30', 'historico');

INSERT INTO Forma_Parte_De (TAI, id_persona, id_dependencia) VALUES
('TAI-PROF-01', 34, 100),
('TAI-PROF-02', 30, 100),
('TAI-PROF-03', 31, 100),
('TAI-PROF-04', 33, 100),
('TAI-PROF-05', 32, 100),
('TAI-PROF-06', 35, 100),
('TAI-EMP-01', 36, 100),
('TAI-EMP-02', 37, 101),
('TAI-STD-01', 1, 100),
('TAI-STD-02', 2, 100),
('TAI-STD-03', 3, 100),
('TAI-STD-04', 4, 100),
('TAI-STD-05', 5, 100),
('TAI-STD-06', 6, 100),
('TAI-STD-07', 7, 101),
('TAI-STD-08', 8, 101),
('TAI-STD-09', 9, 100),
('TAI-STD-10', 10, 100),
('TAI-EGR-01', 50, 100),
('TAI-EGR-02', 51, 100),
('TAI-EGR-03', 52, 100),
('TAI-EGR-04', 53, 100);

INSERT INTO Detalle_Nexo (TAI_nexo, clave, valor) VALUES
('TAI-EGR-01', 'Promedio', '18.5'),
('TAI-EGR-02', 'Promedio', '19.2'),
('TAI-EGR-03', 'Promedio', '16.0'),
('TAI-EGR-04', 'Promedio', '17.8'),
('TAI-PROF-01', 'Escalafon', 'Titular'),
('TAI-PROF-02', 'Escalafon', 'Titular'),
('TAI-PROF-03', 'Escalafon', 'Asociado');

-- ==============================================================
-- 4. GRUPOS Y MEMBRESÍAS
-- ==============================================================
INSERT INTO Grupo (id_grupo, nombre, tipoGrupo, descripcion) VALUES
(1, 'Agrupación de Robótica', 'publico', 'Tech'),
(2, 'Centro de Estudiantes', 'publico', 'Politica'),
(3, 'Club de Debate', 'privado', 'Oratoria'),
(4, 'Selección de Fútbol', 'publico', 'Deportes'),
(5, 'Modelado Naciones Unidas', 'privado', 'MUN');

INSERT INTO Membresia_Grupo (id_grupo, id_ente, rol) VALUES
(1, 1, 'Lider'),
(1, 2, 'miembro'),
(1, 3, 'miembro'),
(1, 5, 'miembro'),
(1, 9, 'miembro'),
(2, 2, 'Lider'),
(2, 4, 'miembro'),
(2, 6, 'miembro'),
(3, 8, 'Lider'),
(3, 7, 'miembro'),
(4, 9, 'Lider'),
(5, 10, 'Lider'),
(5, 1, 'miembro'),
(5, 6, 'miembro'),
(5, 7, 'miembro'),
(5, 8, 'miembro');

-- ==============================================================
-- 5. EVENTOS
-- ==============================================================
INSERT INTO Evento (id_evento, nombre, tipo, fechaHoraInicio, fechaHoraFin, lugar, estado) VALUES
(500, 'Taller SQL', 'taller', '2023-01-10 08:00:00', '2023-01-10 12:00:00', 'Lab 1', 'finalizado'),
(501, 'Intro a Python', 'taller', '2023-02-15 09:00:00', '2023-02-15 14:00:00', 'Lab 2', 'finalizado'),
(502, 'Foro de DDHH', 'conferencia', '2023-03-20 08:00:00', '2023-03-20 18:00:00', 'Auditorio', 'finalizado'),
(600, 'Feria de Empleo', 'conferencia', '2025-12-20 09:00:00', NULL, 'Plaza', 'publicado'),
(601, 'Acto de Grado', 'acto-grado', '2025-11-30 10:00:00', NULL, 'Aula Magna', 'publicado'),
(602, 'Torneo de Robots', 'conferencia', '2026-01-15 08:00:00', NULL, 'Cancha', 'publicado'),
(603, 'Charla de IA', 'webinar', '2025-10-15 15:00:00', NULL, 'Zoom', 'publicado'),
(604, 'Copa UCAB', 'conferencia', '2026-02-01 08:00:00', NULL, 'Estadio', 'borrador');

INSERT INTO Organizador_Evento (id_evento, id_ente, rol) VALUES
(500, 30, 'Facilitador'),
(502, 30, 'Moderador'),
(603, 30, 'Ponente'),
(501, 31, 'Facilitador'),
(600, 200, 'Patrocinante'),
(602, 1, 'Organizador');

INSERT INTO Evento_Grupo (id_evento, id_grupo) VALUES
(500, 1),
(602, 1),
(501, 1),
(502, 2),
(603, 1),
(604, 4);

INSERT INTO Asistencia_Evento (id_evento, id_ente_persona, estadoRegistro) VALUES
(500, 1, 'asistio'),
(500, 2, 'asistio'),
(500, 3, 'asistio'),
(600, 50, 'registrado'),
(600, 51, 'registrado');

-- ==============================================================
-- 6. INTERACCIONES
-- ==============================================================
INSERT INTO Relacion (id_ente1, id_ente2, tipo, direccionalidad, estado, fechaInicio) VALUES
(50, 1, 'tutoria', 'asimetrica', 'aceptada', '2023-01-01'),
(51, 2, 'tutoria', 'asimetrica', 'aceptada', '2023-02-01'),
(53, 3, 'tutoria', 'asimetrica', 'aceptada', '2023-03-01');

INSERT INTO Telefono (numero, id_ente_persona) VALUES
('04140000000', 1);

INSERT INTO Idioma (nombre) VALUES
('Ingles');

INSERT INTO Habilidad_Tecnica (nombre, descripcion) VALUES
('Java'),
('SQL', 'Manejo de bases de datos relacionales'),
('Python', 'Programación backend'),
('Flask', 'Desarrollo web microframework'),
('PostgreSQL', 'Administración avanzada de BD');

INSERT INTO Area_De_Interes (nombre) VALUES
('IA');

INSERT INTO Esta_Suscrito (id_ente, id_grupo) VALUES
(1, 2);

INSERT INTO Publicacion (id_publicacion, tipo, contenidoTexto, visibilidad) VALUES
(1, 'anuncio', 'Hola', 'publica');

INSERT INTO Publica (id_publicacion, id_ente) VALUES
(1, 1);

INSERT INTO Notificacion (id_ente, tipo, contenidoResumen) VALUES
(1, 'sistema', 'Hola');