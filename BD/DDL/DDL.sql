/* ==============================================================
 * 01_DDL_MAESTRO.sql
 * Estructura completa: Tablas, Secuencias y Relaciones
 * ============================================================== */

-- 1. TABLA MAESTRA Y SECUENCIAS
CREATE SEQUENCE ente_id_seq;

CREATE TABLE Ente (
    id_ente INT PRIMARY KEY DEFAULT nextval('ente_id_seq'),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Persona', 'Dependencia', 'Organizacion')),
    correoElectronico VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255), -- Ampliado para Hash
    ubicacion_pais VARCHAR(50) NOT NULL,
    ubicacion_estado VARCHAR(50) NOT NULL,
    ubicacion_ciudad VARCHAR(50) NOT NULL,
    direccion_detalle VARCHAR(150),
    visibilidad_perfil VARCHAR(20) DEFAULT 'publica' CHECK (visibilidad_perfil IN ('publica', 'solo-amigos', 'privada'))
);

ALTER SEQUENCE ente_id_seq OWNED BY Ente.id_ente;

-- 2. SUBTIPOS DE ENTE
CREATE TABLE Persona (
    id_ente INT PRIMARY KEY,
    CI INT NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    fechaNacimiento DATE NOT NULL,
    sexo CHAR(1) CHECK (sexo IN ('M', 'F')),
    ocupacion VARCHAR(100),
    estadoCuenta VARCHAR(20) DEFAULT 'activo' CHECK (estadoCuenta IN ('activo', 'suspendido', 'eliminado')),
    CONSTRAINT fk_persona_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Dependencia_UCAB (
    id_ente INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    tipoDependencia VARCHAR(50) CHECK (tipoDependencia IN ('Escuela', 'Facultad', 'CentroInvestigacion', 'Agrupacion', 'Secretariado')),
    descripcion TEXT,
    CONSTRAINT fk_dep_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Organizacion_Asociada (
    id_ente INT PRIMARY KEY,
    RIF VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    tipoOrganizacion VARCHAR(50) CHECK (tipoOrganizacion IN ('Fundacion', 'Empresa', 'Asociacion', 'Catedra')),
    relacionConUCAB VARCHAR(100),
    descripcion TEXT,
    CONSTRAINT fk_org_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

-- 3. PERFIL Y DATOS DE CONTACTO
CREATE TABLE Telefono (
    numero VARCHAR(20),
    id_ente_persona INT,
    PRIMARY KEY (numero, id_ente_persona),
    CONSTRAINT fk_tlf_persona FOREIGN KEY (id_ente_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE
);

CREATE TABLE Nexo_Institucional (
    TAI VARCHAR(20) PRIMARY KEY,
    tipoNexo VARCHAR(50) NOT NULL CHECK (tipoNexo IN ('Estudiante', 'Profesor', 'Empleado', 'Egresado')),
    fechaInicio DATE NOT NULL,
    fechaFin DATE,
    estado VARCHAR(20) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'historico'))
);

CREATE TABLE Forma_Parte_De (
    TAI VARCHAR(20) PRIMARY KEY,
    id_persona INT NOT NULL,
    id_dependencia INT NOT NULL,
    CONSTRAINT fk_fpd_nexo FOREIGN KEY (TAI) REFERENCES Nexo_Institucional(TAI),
    CONSTRAINT fk_fpd_persona FOREIGN KEY (id_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE,
    CONSTRAINT fk_fpd_dep FOREIGN KEY (id_dependencia) REFERENCES Dependencia_UCAB(id_ente)
);

CREATE TABLE Detalle_Nexo (
    TAI_nexo VARCHAR(20),
    clave VARCHAR(50),
    valor VARCHAR(255) NOT NULL,
    PRIMARY KEY (TAI_nexo, clave),
    CONSTRAINT fk_detalle_padre FOREIGN KEY (TAI_nexo) REFERENCES Nexo_Institucional(TAI) ON DELETE CASCADE
);

-- 4. CATÁLOGOS Y HABILIDADES
CREATE TABLE Idioma (
    nombre VARCHAR(50) PRIMARY KEY,
    descripcion VARCHAR(255)
);

CREATE TABLE Habilidad_Tecnica (
    nombre VARCHAR(50) PRIMARY KEY,
    descripcion VARCHAR(255)
);

CREATE TABLE Area_De_Interes (
    nombre VARCHAR(50) PRIMARY KEY,
    descripcion VARCHAR(255)
);

CREATE TABLE Es_Dominado (
    id_ente_persona INT,
    nombre_idioma VARCHAR(50),
    nivel VARCHAR(20) CHECK (nivel IN ('Basico', 'Intermedio', 'Avanzado', 'Nativo')),
    PRIMARY KEY (id_ente_persona, nombre_idioma),
    CONSTRAINT fk_dom_per FOREIGN KEY (id_ente_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE,
    CONSTRAINT fk_dom_idi FOREIGN KEY (nombre_idioma) REFERENCES Idioma(nombre)
);

CREATE TABLE Es_Poseida (
    id_ente_persona INT,
    nombre_habilidad VARCHAR(50),
    PRIMARY KEY (id_ente_persona, nombre_habilidad),
    CONSTRAINT fk_pos_per FOREIGN KEY (id_ente_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE,
    CONSTRAINT fk_pos_hab FOREIGN KEY (nombre_habilidad) REFERENCES Habilidad_Tecnica(nombre)
);

CREATE TABLE Es_Interesado (
    id_ente_persona INT,
    nombre_area VARCHAR(50),
    prioridad INT CHECK (prioridad BETWEEN 1 AND 5),
    PRIMARY KEY (id_ente_persona, nombre_area),
    CONSTRAINT fk_int_per FOREIGN KEY (id_ente_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE,
    CONSTRAINT fk_int_area FOREIGN KEY (nombre_area) REFERENCES Area_De_Interes(nombre)
);

-- 5. GRUPOS Y EVENTOS
CREATE TABLE Grupo (
    id_grupo INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipoGrupo VARCHAR(20) NOT NULL CHECK (tipoGrupo IN ('publico', 'privado', 'secreto')),
    fechaCreacion DATE NOT NULL DEFAULT CURRENT_DATE,
    estado VARCHAR(20) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'archivado'))
);

CREATE TABLE Membresia_Grupo (
    id_grupo INT,
    id_ente INT,
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('miembro', 'administrador', 'creador', 'moderador', 'Lider', 'Representante')),
    fechaIngreso DATE NOT NULL DEFAULT CURRENT_DATE,
    fechaSalida DATE,
    estado VARCHAR(20) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'suspendido', 'invitado', 'pendiente')),
    PRIMARY KEY (id_grupo, id_ente),
    CONSTRAINT fk_mem_grupo FOREIGN KEY (id_grupo) REFERENCES Grupo(id_grupo) ON DELETE CASCADE,
    CONSTRAINT fk_mem_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE SEQUENCE evento_id_evento_seq;
CREATE TABLE Evento (
    id_evento INT PRIMARY KEY DEFAULT nextval('evento_id_evento_seq'),
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('conferencia', 'taller', 'webinar', 'acto-grado')),
    fechaHoraInicio TIMESTAMP NOT NULL,
    fechaHoraFin TIMESTAMP,
    lugar VARCHAR(100) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'publicado' CHECK (estado IN ('borrador', 'publicado', 'en-curso', 'finalizado', 'archivado')),
    cantidad_asistentes INT DEFAULT 0
);
ALTER SEQUENCE evento_id_evento_seq OWNED BY Evento.id_evento;

CREATE TABLE Organizador_Evento (
    id_evento INT,
    id_ente INT,
    rol VARCHAR(50),
    fechaAsignacion DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (id_evento, id_ente),
    CONSTRAINT fk_org_ev_evento FOREIGN KEY (id_evento) REFERENCES Evento(id_evento) ON DELETE CASCADE,
    CONSTRAINT fk_org_ev_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Asistencia_Evento (
    id_evento INT,
    id_ente_persona INT,
    estadoRegistro VARCHAR(20) NOT NULL CHECK (estadoRegistro IN ('interesado', 'registrado', 'confirmado', 'asistio', 'cancelo')),
    fechaRegistro DATE NOT NULL DEFAULT CURRENT_DATE,
    fechaAsistencia DATE,
    PRIMARY KEY (id_evento, id_ente_persona),
    CONSTRAINT fk_asist_evento FOREIGN KEY (id_evento) REFERENCES Evento(id_evento) ON DELETE CASCADE,
    CONSTRAINT fk_asist_persona FOREIGN KEY (id_ente_persona) REFERENCES Persona(id_ente) ON DELETE CASCADE
);

CREATE TABLE Evento_Grupo (
    id_evento INT PRIMARY KEY,
    id_grupo INT NOT NULL,
    CONSTRAINT fk_ev_grupo_ev FOREIGN KEY (id_evento) REFERENCES Evento(id_evento) ON DELETE CASCADE,
    CONSTRAINT fk_ev_grupo_gr FOREIGN KEY (id_grupo) REFERENCES Grupo(id_grupo) ON DELETE CASCADE
);

-- 6. INTERACCIONES SOCIALES Y PUBLICACIONES
CREATE TABLE Relacion (
    id_ente1 INT,
    id_ente2 INT,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('amistad', 'tutoria', 'colaboracion', 'seguimiento', 'empleo', 'pasantia')),
    direccionalidad VARCHAR(20) NOT NULL CHECK (direccionalidad IN ('simetrica', 'asimetrica')),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'disuelta', 'bloqueada')),
    fechaInicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fechaFin DATE,
    observaciones TEXT,
    PRIMARY KEY (id_ente1, id_ente2, tipo),
    CONSTRAINT fk_rel_ente1 FOREIGN KEY (id_ente1) REFERENCES Ente(id_ente) ON DELETE CASCADE,
    CONSTRAINT fk_rel_ente2 FOREIGN KEY (id_ente2) REFERENCES Ente(id_ente) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_rel CHECK (id_ente1 <> id_ente2)
);

CREATE TABLE Notificacion (
    id_ente INT,
    fechaEmision TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('Evento', 'comentario', 'solicitud Relacion', 'grupo', 'sistema')),
    estado VARCHAR(20) NOT NULL DEFAULT 'no-leida' CHECK (estado IN ('leida', 'no-leida', 'archivada')),
    contenidoResumen VARCHAR(255) NOT NULL,
    tipoOrigen VARCHAR(50),
    PRIMARY KEY (id_ente, fechaEmision),
    CONSTRAINT fk_notif_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE SEQUENCE pub_id_seq;
CREATE TABLE Publicacion (
    id_publicacion INT PRIMARY KEY DEFAULT nextval('pub_id_seq'),
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('mensaje', 'archivo', 'encuesta', 'anuncio', 'oferta')),
    contenidoTexto TEXT NOT NULL,
    visibilidad VARCHAR(20) NOT NULL CHECK (visibilidad IN ('publica', 'solo-amigos', 'grupos', 'privada'))
);
ALTER SEQUENCE pub_id_seq OWNED BY Publicacion.id_publicacion;

CREATE TABLE Publica (
    id_publicacion INT PRIMARY KEY,
    id_ente INT NOT NULL,
    fechaPublicacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_publica_pub FOREIGN KEY (id_publicacion) REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE,
    CONSTRAINT fk_publica_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Reaccion (
    id_publicacion INT,
    id_ente INT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_publicacion, id_ente),
    CONSTRAINT fk_reaccion_pub FOREIGN KEY (id_publicacion) REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE,
    CONSTRAINT fk_reaccion_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Comentario (
    id_comentario SERIAL PRIMARY KEY,
    id_publicacion INT NOT NULL,
    id_ente INT NOT NULL,
    contenido TEXT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_com_pub FOREIGN KEY (id_publicacion) REFERENCES Publicacion(id_publicacion) ON DELETE CASCADE,
    CONSTRAINT fk_com_ente FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE
);

CREATE TABLE Esta_Suscrito (
    id_ente INT,
    id_grupo INT,
    fechaSuscripcion DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (id_ente, id_grupo),
    FOREIGN KEY (id_ente) REFERENCES Ente(id_ente) ON DELETE CASCADE,
    FOREIGN KEY (id_grupo) REFERENCES Grupo(id_grupo) ON DELETE CASCADE
);