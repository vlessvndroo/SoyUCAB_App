# SoyUCAB - Red Social Institucional

SoyUCAB es una plataforma social diseñada para fortalecer los lazos entre estudiantes, profesores, egresados y personal administrativo de la Universidad Católica Andrés Bello. Permite la gestión de perfiles, creación de grupos, organización de eventos y networking profesional.

## 🛠️ Tecnologías

* **Backend:** Python 3 + Flask
* **Base de Datos:** PostgreSQL 14+
* **Frontend:** HTML5, Bootstrap 5, Jinja2
* **Seguridad:** Row Level Security (RLS) de PostgreSQL

## 📋 Pre-requisitos

1.  Tener instalado **Python 3.8+**.
2.  Tener instalado **PostgreSQL**.
3.  Tener instalado **Git** (opcional).

## 🚀 Instalación y Configuración

### 1. Configuración de la Base de Datos
El sistema requiere una base de datos PostgreSQL. Ejecuta los scripts SQL proporcionados en la carpeta `BD` en el siguiente orden estricto para evitar errores de dependencias:

1.  `01_DDL_Maestro.sql`: Crea las tablas y secuencias.
2.  `02_Logica_Negocio.sql`: Crea funciones y procedimientos almacenados.
3.  `03_Triggers.sql`: Activa los disparadores automáticos.
4.  `04_Vistas_Reportes.sql`: Genera las vistas para los dashboards.
5.  `05_Seguridad_Roles.sql`: Configura usuarios, roles y políticas de seguridad (RLS).
6.  `06_Poblacion.sql`: Carga los datos de prueba iniciales.

> **Nota:** El script de seguridad crea un usuario de base de datos llamado `app_backend` con contraseña `soyucab_pass`. Asegúrate de que tu PostgreSQL permita la conexión con este usuario.

### 2. Configuración del Entorno Python

1.  Clona o descarga este repositorio.
2.  Crea un entorno virtual (opcional pero recomendado):
    ```bash
    python -m venv venv
    # En Windows:
    venv\Scripts\activate
    # En Mac/Linux:
    source venv/bin/activate
    ```
3.  Instala las dependencias necesarias:
    ```bash
    pip install flask psycopg2-binary werkzeug
    ```

## ▶️ Ejecución

Para iniciar el servidor de desarrollo:

```bash
python app.py
```

Accede en tu navegador a: http://localhost:5000

## Usuarios de prueba

Rol                                 Correo Electrónico                              Descripción
Superusuario                        admin@ucab.edu.ve                               Admin Total. Acceso al Panel de Administración. Puede eliminar usuarios, grupos y eventos.
Auditor                             auditor@ucab.edu.ve                             Solo Lectura. Ve estadísticas globales anonimizadas. No puede ver perfiles personales.
Institución                         ingenieria@ucab.edu.ve                          Escuela. Puede publicar eventos oficiales y gestionar su perfil institucional.
Estudiante                          Registrar a traves de interfaz                  Usuario Común. Puede crear grupos, posts, unirse a eventos y conectar con otros.

Todos y cada uno de los usuarios se deben registrar manualmente a traves de la interfaz