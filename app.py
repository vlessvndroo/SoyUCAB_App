from flask import Flask, render_template, request, redirect, url_for, session, flash
from db import get_db_connection
from werkzeug.security import generate_password_hash, check_password_hash
import datetime
import random
import string

app = Flask(__name__)
app.secret_key = 'soyucab_secret_key'

# Función auxiliar para conectar con el ROL ESPECÍFICO de la sesión
def get_db_connection_with_role():
    conn = get_db_connection() # Usa app_backend (definido en db.py)
    if conn:
        cur = conn.cursor()
        try:
            # 1. CAMBIO DE ROL: Si la sesión dice que es Institución o Auditor, nos disfrazamos
            if 'db_role' in session:
                cur.execute(f"SET ROLE {session['db_role']}")
            
            # 2. CONTEXTO RLS: Inyectamos el ID del usuario (Si no es auditor)
            if 'user_id' in session and session.get('db_role') != 'rol_auditor':
                cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
                
        except Exception as e:
            print(f"Error configurando rol/contexto: {e}")
        cur.close()
    return conn

# --- 🛠️ CONTEXTO GLOBAL ---
@app.context_processor
def global_data():
    data = {'notif_count': 0, 'lista_ocupaciones': []}
    
    # Si no hay usuario o es auditor (que no tiene notificaciones personales), saltamos
    if 'user_id' not in session or session.get('db_role') == 'rol_auditor':
        return data

    conn = get_db_connection()
    cur = conn.cursor()
    # [SEGURIDAD] Inyectar contexto RLS
    try: cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    except: pass
    
    try:
        cur.execute("SELECT COUNT(*) FROM Notificacion WHERE id_ente = %s AND estado = 'no-leida'", (session['user_id'],))
        result = cur.fetchone()
        data['notif_count'] = result[0] if result else 0
        
        cur.execute("SELECT DISTINCT ocupacion FROM Persona WHERE ocupacion IS NOT NULL ORDER BY 1")
        data['lista_ocupaciones'] = [row[0] for row in cur.fetchall()]
    except Exception as e:
        print(f"Error en global_data: {e}")
        
    cur.close()
    conn.close()
    return data

@app.template_filter('format_tipo')
def format_tipo(value):
    return value.replace('-', ' ').title() if value else ''

# --- 🚀 RUTA 1: LANDING PAGE ---
@app.route('/')
def index(): return render_template('landing.html')

# --- 🔑 RUTA 2: LOGIN ---
@app.route('/login', methods=['GET', 'POST'])
def login():
    if 'user_id' in session: return redirect(url_for('home'))
    
    if request.method == 'POST':
        email, pwd = request.form['email'], request.form['password']
        
        conn = get_db_connection()
        cur = conn.cursor()
        # Buscamos ID, Password, TIPO y ESTADO DE CUENTA
        cur.execute("""
            SELECT E.id_ente, E.password, E.tipo, P.estadoCuenta 
            FROM Ente E 
            LEFT JOIN Persona P ON E.id_ente = P.id_ente 
            WHERE E.correoElectronico = %s
        """, (email,))
        user = cur.fetchone()
        cur.close(); conn.close()
        
        if user and check_password_hash(user[1], pwd):
            # Verificar bloqueo
            if user[3] == 'suspendido':
                flash('⛔ TU CUENTA HA SIDO SUSPENDIDA. Contacta al administrador.')
                return render_template('login.html')

            session['user_id'] = user[0]
            session['user_email'] = email
            tipo_ente = user[2]
            
            # --- CEREBRO DEL LOGIN INTELIGENTE ---
            if email == 'auditor@ucab.edu.ve':
                session['db_role'] = 'rol_auditor'
                return redirect(url_for('dashboard')) # Auditor ahora va directo al Dashboard general
                
            elif email == 'admin@ucab.edu.ve':
                session['db_role'] = 'rol_admin_dba'
                return redirect(url_for('admin_panel'))
                
            elif tipo_ente in ['Dependencia', 'Organizacion']:
                session['db_role'] = 'rol_institucional'
                return redirect(url_for('home_institucional'))
                
            else:
                session['db_role'] = 'rol_usuario_comun'
                return redirect(url_for('home'))
                
        flash('Credenciales incorrectas.')
    return render_template('login.html')

# --- 🏠 RUTA 3: HOME (DISTRIBUIDOR CENTRAL) ---
@app.route('/home')
def home():
    if 'user_id' not in session: return redirect(url_for('login'))
    
    # 1. SI ES UN ROL ESPECIAL, REDIRIGIR A SU PROPIO DASHBOARD
    rol = session.get('db_role')
    if rol == 'rol_institucional':
        return redirect(url_for('home_institucional'))
    elif rol == 'rol_auditor':
        return redirect(url_for('dashboard')) # Auditor al dashboard de reportes
    elif rol == 'rol_admin_dba':
        return redirect(url_for('admin_panel'))

    # 2. SI ES USUARIO COMÚN (Estudiante/Profesor), CARGAR EL FEED SOCIAL
    uid = session['user_id']
    conn = get_db_connection_with_role() # Usar conexión con rol
    cur = conn.cursor()
    
    # [SEGURIDAD] Inyectar contexto RLS
    try: cur.execute("SET app.current_ente_id = %s", (str(uid),))
    except: pass

    # Obtener nombre de la Persona
    cur.execute("SELECT nombre, apellido FROM Persona WHERE id_ente = %s", (uid,))
    persona = cur.fetchone()
    
    if not persona:
        cur.close(); conn.close()
        return redirect(url_for('logout'))
    
    # --- QUERY POSTS ---
    cur.execute("""
        SELECT DISTINCT P.nombre, P.apellido, Pub.contenidoTexto, Pub.tipo, A.fechaPublicacion, 
               Pub.id_publicacion,
               (SELECT COUNT(*) FROM Reaccion WHERE id_publicacion = Pub.id_publicacion) as total_likes,
               EXISTS(SELECT 1 FROM Reaccion WHERE id_publicacion = Pub.id_publicacion AND id_ente = %s) as user_liked,
               A.id_ente as autor_id
        FROM Publicacion Pub
        JOIN Publica A ON Pub.id_publicacion = A.id_publicacion
        JOIN Persona P ON A.id_ente = P.id_ente
        LEFT JOIN Relacion R ON (R.id_ente1 = %s AND R.id_ente2 = A.id_ente) 
                            OR (R.id_ente2 = %s AND R.id_ente1 = A.id_ente)
        WHERE A.id_ente = %s 
           OR Pub.visibilidad = 'publica' 
           OR (Pub.visibilidad = 'solo-amigos' AND R.estado = 'aceptada')
           OR (Pub.visibilidad = 'privada' AND A.id_ente = %s)
        ORDER BY A.fechaPublicacion DESC LIMIT 15;
    """, (uid, uid, uid, uid, uid))
    posts_raw = cur.fetchall()
    
    posts = []
    for p in posts_raw:
        cur.execute("SELECT P.nombre, P.apellido, C.contenido, C.fecha FROM Comentario C JOIN Persona P ON C.id_ente = P.id_ente WHERE C.id_publicacion = %s ORDER BY C.fecha ASC", (p[5],))
        posts.append({
            'autor': f"{p[0]} {p[1]}", 'contenido': p[2], 'tipo': p[3], 'fecha': p[4],
            'id': p[5], 'likes': p[6], 'liked': p[7], 'es_mio': (p[8] == uid),
            'comentarios': cur.fetchall()
        })

    # --- QUERY CONEXIONES (DISTINCT) ---
    cur.execute("""
        SELECT DISTINCT P.id_ente, P.nombre, P.apellido, R.tipo, P.ocupacion
        FROM Relacion R
        JOIN Persona P ON P.id_ente = (CASE WHEN R.id_ente1 = %s THEN R.id_ente2 ELSE R.id_ente1 END)
        WHERE (R.id_ente1 = %s OR R.id_ente2 = %s) AND R.estado = 'aceptada'
        LIMIT 5
    """, (uid, uid, uid))
    mis_conexiones = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('home.html', user_name=f"{persona[0]} {persona[1]}", posts=posts, uid=uid, mis_conexiones=mis_conexiones)

# --- 📝 RUTA 4: REGISTRO ---
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        email, p_hash = request.form['email'], generate_password_hash(request.form['password'])
        ci, nom, ape = request.form['ci'], request.form['nombre'], request.form['apellido']
        rol, id_esc = request.form['rol_ucab'], request.form.get('escuela', 100)
        tai = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
        
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("INSERT INTO Ente (tipo, correoElectronico, password, ubicacion_pais, ubicacion_estado, ubicacion_ciudad, direccion_detalle) VALUES ('Persona', %s, %s, %s, %s, %s, %s) RETURNING id_ente;", 
                       (email, p_hash, request.form['pais'], request.form['estado'], request.form['ciudad'], request.form['direccion']))
            nuevo_id = cur.fetchone()[0]
            cur.execute("INSERT INTO Persona (id_ente, CI, nombre, apellido, fechaNacimiento, sexo, ocupacion) VALUES (%s,%s,%s,%s,%s,%s,%s);", 
                        (nuevo_id, ci, nom, ape, request.form['fecha_nac'], request.form['sexo'], rol))
            cur.execute("INSERT INTO Nexo_Institucional (TAI, tipoNexo, fechaInicio, estado) VALUES (%s,%s,CURRENT_DATE,'activo');", (tai, rol.capitalize()))
            cur.execute("INSERT INTO Forma_Parte_De (TAI, id_persona, id_dependencia) VALUES (%s,%s,%s);", (tai, nuevo_id, id_esc))
            conn.commit()
            flash('¡Registro exitoso!')
            return redirect(url_for('login'))
        except Exception as e:
            conn.rollback()
            flash(f'Error: {e}')
        finally:
            cur.close()
            conn.close()
    return render_template('register.html')

# --- 🚪 RUTA 5: LOGOUT ---
@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

# --- 📣 RUTA 6: GESTIÓN DE POSTS ---
@app.route('/create_post', methods=['POST'])
def create_post():
    if 'user_id' not in session: return redirect(url_for('login'))
    con, tip, vis = request.form['contenido'], request.form['tipo'], request.form['visibilidad']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("INSERT INTO Publicacion (tipo, contenidoTexto, visibilidad) VALUES (%s, %s, %s) RETURNING id_publicacion;", (tip, con, vis))
    pid = cur.fetchone()[0]
    cur.execute("INSERT INTO Publica (id_publicacion, id_ente, fechaPublicacion) VALUES (%s, %s, CURRENT_TIMESTAMP AT TIME ZONE 'America/Caracas');", (pid, session['user_id']))
    conn.commit()
    cur.close(); conn.close()
    return redirect(url_for('home'))

@app.route('/delete_post/<int:id_pub>')
def delete_post(id_pub):
    if 'user_id' not in session: return redirect(url_for('login'))
    
    conn = get_db_connection() # Usamos conexión genérica para checkear roles
    cur = conn.cursor()
    
    # ¿Es Admin?
    es_admin = (session.get('db_role') == 'rol_admin_dba')
    
    # ¿Es Dueño?
    cur.execute("SELECT 1 FROM Publica WHERE id_publicacion = %s AND id_ente = %s", (id_pub, session['user_id']))
    es_dueno = cur.fetchone() is not None
    
    if es_admin or es_dueno:
        # Si es Admin, necesitamos conectar con rol Admin para tener permiso de borrar cualquier cosa
        if es_admin:
            conn_admin = get_db_connection_with_role()
            cur_admin = conn_admin.cursor()
            try:
                cur_admin.execute("DELETE FROM Publica WHERE id_publicacion = %s", (id_pub,))
                cur_admin.execute("DELETE FROM Publicacion WHERE id_publicacion = %s", (id_pub,))
                conn_admin.commit()
                flash("Contenido eliminado por administración." if es_admin else "Post eliminado.")
            except Exception as e:
                conn_admin.rollback()
                print(f"Error Admin Delete: {e}")
            finally:
                cur_admin.close(); conn_admin.close()
        else:
            # Lógica normal de usuario (RLS activado)
            # ... (Tu lógica original con RLS) ...
            # Para simplificar, usaremos la conexión admin para ambos casos de borrado si la lógica original falla
            pass 
            # (NOTA: Como ya tienes tu lógica de borrado arriba, mantenla, pero agrega el "OR es_admin")

    cur.close(); conn.close()
    return redirect(request.referrer or url_for('home'))

@app.route('/add_comment', methods=['POST'])
def add_comment():
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("INSERT INTO Comentario (id_publicacion, id_ente, contenido) VALUES (%s, %s, %s)", (request.form['id_pub'], session['user_id'], request.form['contenido']))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('home'))

# --- 👤 RUTA 7: PERFIL (CON PRIVACIDAD Y RECURSIVIDAD) ---
@app.route('/perfil')
@app.route('/perfil/<int:user_id_ver>')
def perfil(user_id_ver=None):
    if 'user_id' not in session: return redirect(url_for('login'))
    
    if session.get('db_role') == 'rol_auditor':
        flash("Los auditores no tienen acceso a perfiles personales.")
        return redirect(url_for('dashboard'))

    uid, target = session['user_id'], user_id_ver if user_id_ver else session['user_id']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    # 1. Datos básicos + PRIVACIDAD
    # Traemos también visibilidad_perfil
    cur.execute("""
        SELECT P.CI, P.nombre, P.apellido, P.ocupacion, P.fechaNacimiento, 
               E.correoElectronico, E.ubicacion_ciudad, E.ubicacion_estado, E.direccion_detalle, E.ubicacion_pais,
               E.visibilidad_perfil,
               (SELECT numero FROM Telefono WHERE id_ente_persona = P.id_ente LIMIT 1) as telefono
        FROM Persona P JOIN Ente E ON P.id_ente = E.id_ente 
        WHERE P.id_ente = %s
    """, (target,))
    datos = cur.fetchone()
    
    # 2. Verificar Relación (Amistad)
    cur.execute("SELECT tipo, estado FROM Relacion WHERE id_ente1 = %s AND id_ente2 = %s", (uid, target))
    rels = {row[0]: row[1] for row in cur.fetchall()}
    
    # --- LÓGICA DE PRIVACIDAD GRANULAR ---
    # ¿Debo mostrar datos sensibles (correo, tlf, dirección)?
    mostrar_sensible = False
    if uid == target:
        mostrar_sensible = True # Es mi perfil
    elif datos[10] == 'publica':
        mostrar_sensible = True # Es público
    elif datos[10] == 'solo-amigos' and rels.get('amistad') == 'aceptada':
        mostrar_sensible = True # Somos amigos
    # Si es 'privada' o no cumple lo anterior, se queda en False.

    # --- LÓGICA DE GRADOS DE SEPARACIÓN (RECURSIVIDAD) ---
    camino_conexion = None
    if uid != target:
        # Llamamos a la función SQL recursiva
        cur.execute("SELECT fn_camino_conexion(%s, %s)", (uid, target))
        res = cur.fetchone()
        if res and res[0]:
            camino_conexion = res[0]

    # 3. Nexos y Roles
    cur.execute("""
        SELECT NI.tipoNexo, D.nombre, NI.fechaInicio 
        FROM Nexo_Institucional NI 
        JOIN Forma_Parte_De FPD ON NI.TAI = FPD.TAI 
        JOIN Dependencia_UCAB D ON FPD.id_dependencia = D.id_ente 
        WHERE FPD.id_persona = %s AND NI.estado = 'activo' LIMIT 1
    """, (target,))
    nexo = cur.fetchone()

    cur.execute("""
        SELECT DISTINCT NI.tipoNexo
        FROM Nexo_Institucional NI
        JOIN Forma_Parte_De FPD ON NI.TAI = FPD.TAI
        WHERE FPD.id_persona = %s
    """, (target,))
    roles_usuario = [row[0] for row in cur.fetchall()]

    cur.execute("SELECT nombre_habilidad FROM Es_Poseida WHERE id_ente_persona = %s", (target,))
    mis_habs = [h[0] for h in cur.fetchall()]
    cur.execute("SELECT nombre FROM Habilidad_Tecnica")
    cat_habs = cur.fetchall()
    
    mis_relaciones = []
    if uid == target:
        cur.execute("""
            SELECT P.nombre, P.apellido, R.tipo, P.id_ente, R.estado 
            FROM Relacion R 
            JOIN Persona P ON P.id_ente = (CASE WHEN R.id_ente1 = %s THEN R.id_ente2 ELSE R.id_ente1 END)
            WHERE (R.id_ente1 = %s OR R.id_ente2 = %s) AND R.estado IN ('aceptada', 'pendiente')
        """, (uid, uid, uid))
        mis_relaciones = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('perfil.html', datos=datos, nexo=nexo, roles_usuario=roles_usuario, 
                           es_mio=(uid==target), relaciones=rels, id_obj=target, 
                           mis_habs=mis_habs, cat_habs=cat_habs, mis_relaciones=mis_relaciones,
                           mostrar_sensible=mostrar_sensible, camino_conexion=camino_conexion)

# --- 🛠️ RUTA 8: EDITAR PERFIL (CON PRIVACIDAD) ---
@app.route('/edit_perfil', methods=['POST'])
def edit_perfil():
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))

    try:
        cur.execute("UPDATE Persona SET nombre=%s, apellido=%s, ocupacion=%s WHERE id_ente=%s", 
                   (request.form['nombre'], request.form['apellido'], request.form['ocupacion'], uid))
        
        # Actualizamos también la Visibilidad
        cur.execute("UPDATE Ente SET ubicacion_estado=%s, ubicacion_ciudad=%s, direccion_detalle=%s, visibilidad_perfil=%s WHERE id_ente=%s", 
                   (request.form['estado'], request.form['ciudad'], request.form['direccion'], request.form['visibilidad'], uid))
        
        cur.execute("DELETE FROM Es_Poseida WHERE id_ente_persona = %s", (uid,))
        for hab in request.form.getlist('habilidades'):
            cur.execute("INSERT INTO Es_Poseida (id_ente_persona, nombre_habilidad) VALUES (%s, %s)", (uid, hab))
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"Error update: {e}")
    finally:
        cur.close(); conn.close()
    return redirect(url_for('perfil'))

# --- 🔍 RUTA 9: BUSCADOR ---
@app.route('/usuarios')
def lista_usuarios():
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    
    # Parámetros de Paginación
    page = request.args.get('page', 1, type=int)
    per_page = 10 # Usuarios por página
    offset = (page - 1) * per_page
    
    q = request.args.get('q', '')
    ciu = request.args.get('ciudad', '')
    ocu = request.args.get('ocupacion', '')
    
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    # 1. Query de Datos (LIMIT + OFFSET)
    query = """
        SELECT p.id_ente, p.nombre, p.apellido, p.ocupacion,
        EXISTS(SELECT 1 FROM Relacion r WHERE r.id_ente1 = %s AND r.id_ente2 = p.id_ente AND r.tipo = 'seguimiento'),
        e.ubicacion_ciudad
        FROM Persona p JOIN Ente e ON p.id_ente = e.id_ente
        WHERE (p.nombre ILIKE %s OR p.apellido ILIKE %s) AND p.id_ente != %s
    """
    params = [uid, f"%{q}%", f"%{q}%", uid]
    if ciu: query += " AND e.ubicacion_ciudad ILIKE %s"; params.append(f"%{ciu}%")
    if ocu: query += " AND p.ocupacion = %s"; params.append(ocu)
    
    # Agregar Paginación
    query += " LIMIT %s OFFSET %s"
    params.extend([per_page, offset])
    
    cur.execute(query, tuple(params))
    usuarios = cur.fetchall()
    
    # 2. Query de Conteo (Para saber si hay página siguiente)
    # (Simplificado: Solo verificamos si trajimos 'per_page' registros)
    has_next = len(usuarios) == per_page
    
    cur.close(); conn.close()
    return render_template('usuarios.html', usuarios=usuarios, q=q, ciudad=ciu, ocupacion=ocu, page=page, has_next=has_next)

# --- 🤝 ACCIONES SOCIALES ---
@app.route('/add_relation/<int:id_destino>/<string:tipo_rel>')
def add_relation(id_destino, tipo_rel):
    if 'user_id' not in session: return redirect(url_for('login'))
    uid, est, dire = session['user_id'], 'aceptada' if tipo_rel == 'seguimiento' else 'pendiente', 'asimetrica'
    if tipo_rel == 'amistad': dire = 'simetrica'
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    try:
        cur.execute("INSERT INTO Relacion (id_ente1, id_ente2, tipo, direccionalidad, estado, fechaInicio) VALUES (%s, %s, %s, %s, %s, CURRENT_DATE) ON CONFLICT DO NOTHING", (uid, id_destino, tipo_rel, dire, est))
        if est == 'pendiente':
            cur.execute("INSERT INTO Notificacion (id_ente, fechaEmision, tipo, estado, contenidoResumen, tipoOrigen) VALUES (%s, CURRENT_TIMESTAMP, 'solicitud Relacion', 'no-leida', 'Nueva solicitud de conexión', 'Persona')", (id_destino,))
        conn.commit()
    finally:
        cur.close(); conn.close()
    return redirect(request.referrer)

@app.route('/remove_relation/<int:id_destino>/<string:tipo_rel>')
def remove_relation(id_destino, tipo_rel):
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    conn = get_db_connection()
    cur = conn.cursor()
    try: cur.execute("SET app.current_ente_id = %s", (str(uid),))
    except: pass
    
    if tipo_rel == 'amistad':
        query = "DELETE FROM Relacion WHERE tipo = 'amistad' AND ((id_ente1 = %s AND id_ente2 = %s) OR (id_ente1 = %s AND id_ente2 = %s))"
        cur.execute(query, (uid, id_destino, id_destino, uid))
    else:
        query = "DELETE FROM Relacion WHERE id_ente1 = %s AND id_ente2 = %s AND tipo = %s"
        cur.execute(query, (uid, id_destino, tipo_rel))
    conn.commit(); cur.close(); conn.close()
    return redirect(request.referrer)

@app.route('/cancel_request/<int:id_destino>/<string:tipo_rel>')
def cancel_request(id_destino, tipo_rel):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("DELETE FROM Relacion WHERE id_ente1 = %s AND id_ente2 = %s AND tipo = %s AND estado = 'pendiente'", (session['user_id'], id_destino, tipo_rel))
    conn.commit(); cur.close(); conn.close()
    return redirect(request.referrer)

@app.route('/like/<int:id_pub>')
def like_post(id_pub):
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    cur.execute("SELECT 1 FROM Reaccion WHERE id_publicacion = %s AND id_ente = %s", (id_pub, uid))
    if cur.fetchone():
        cur.execute("DELETE FROM Reaccion WHERE id_publicacion = %s AND id_ente = %s", (id_pub, uid))
    else:
        cur.execute("INSERT INTO Reaccion (id_publicacion, id_ente) VALUES (%s, %s)", (id_pub, uid))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('home'))

# --- RUTAS DE GRUPOS, EVENTOS Y DASHBOARD ---
@app.route('/grupos')
def lista_grupos():
    if 'user_id' not in session: return redirect(url_for('login'))
    
    uid = session['user_id']
    q = request.args.get('q', '')
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Activamos RLS para que el LEFT JOIN de membresía sea seguro
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    # CONSULTA MEJORADA (Usando Vista Pública vw_grupos_explorar)
    cur.execute("""
        SELECT 
            V.id_grupo,       -- 0
            V.nombre,         -- 1
            V.tipoGrupo,      -- 2
            (M.id_ente IS NOT NULL) as soy_miembro, -- 3 (True/False)
            V.total_miembros  -- 4 (El número real)
        FROM vw_grupos_explorar V
        LEFT JOIN Membresia_Grupo M ON V.id_grupo = M.id_grupo AND M.id_ente = %s
        WHERE V.nombre ILIKE %s 
        ORDER BY V.total_miembros DESC, V.nombre ASC;
    """, (uid, f"%{q}%"))
    
    grupos = cur.fetchall()
    
    cur.close(); conn.close()
    return render_template('grupos.html', grupos=grupos, q=q)

@app.route('/join_group/<int:id_grupo>')
def join_group(id_grupo):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("INSERT INTO Membresia_Grupo (id_grupo, id_ente, rol, fechaIngreso, estado) VALUES (%s, %s, 'miembro', CURRENT_DATE, 'activo') ON CONFLICT DO NOTHING", (id_grupo, session['user_id']))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('lista_grupos'))

@app.route('/leave_group/<int:id_grupo>')
def leave_group(id_grupo):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("DELETE FROM Membresia_Grupo WHERE id_grupo = %s AND id_ente = %s", (id_grupo, session['user_id']))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('lista_grupos'))

@app.route('/eventos')
def lista_eventos():
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    
    # Paginación
    page = request.args.get('page', 1, type=int)
    per_page = 5 # Eventos por página
    offset = (page - 1) * per_page
    
    conn = get_db_connection()
    cur = conn.cursor()
    try: cur.execute("SET app.current_ente_id = %s", (str(uid),))
    except: pass
    
    cur.execute("""
        SELECT e.id_evento, e.nombre, e.tipo, e.fechaHoraInicio, e.lugar, e.cantidad_asistentes,
        EXISTS(SELECT 1 FROM Asistencia_Evento WHERE id_evento = e.id_evento AND id_ente_persona = %s),
        G.nombre as nombre_grupo, G.id_grupo, e.estado,
        (OE.id_ente IS NOT NULL) as es_organizador
        FROM Evento e 
        LEFT JOIN Evento_Grupo EG ON e.id_evento = EG.id_evento
        LEFT JOIN Grupo G ON EG.id_grupo = G.id_grupo
        LEFT JOIN Organizador_Evento OE ON e.id_evento = OE.id_evento AND OE.id_ente = %s
        WHERE e.estado IN ('publicado', 'finalizado') OR (e.estado = 'borrador' AND OE.id_ente IS NOT NULL)
        ORDER BY e.fechaHoraInicio DESC
        LIMIT %s OFFSET %s
    """, (uid, uid, per_page, offset))
    
    eventos = cur.fetchall()
    has_next = len(eventos) == per_page
    
    cur.close(); conn.close()
    return render_template('eventos.html', eventos=eventos, page=page, has_next=has_next)

@app.route('/asistir/<int:id_evento>')
def asistir_evento(id_evento):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("INSERT INTO Asistencia_Evento (id_evento, id_ente_persona, estadoRegistro, fechaRegistro) VALUES (%s, %s, 'confirmado', CURRENT_DATE) ON CONFLICT DO NOTHING", (id_evento, session['user_id']))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('lista_eventos'))

@app.route('/unjoin_event/<int:id_evento>')
def unjoin_event(id_evento):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("DELETE FROM Asistencia_Evento WHERE id_evento = %s AND id_ente_persona = %s", (id_evento, session['user_id']))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('lista_eventos'))

@app.route('/notify_group/<int:id_evento>/<int:id_grupo>')
def notify_group(id_evento, id_grupo):
    if 'user_id' not in session: return redirect(url_for('login'))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
    cur.execute("CALL sp_notificar_evento_grupo(%s, %s)", (id_evento, id_grupo))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('lista_eventos'))

@app.route('/notificaciones')
def notificaciones():
    if 'user_id' not in session: return redirect(url_for('login'))
    uid = session['user_id']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    cur.execute("""
        SELECT n.fechaEmision, n.tipo, n.contenidoResumen, n.estado, r.id_ente1, r.tipo as tipo_rel
        FROM Notificacion n
        LEFT JOIN Relacion r ON r.id_ente2 = n.id_ente AND r.estado = 'pendiente' AND r.id_ente2 = %s
        WHERE n.id_ente = %s 
        ORDER BY n.fechaEmision DESC
    """, (uid, uid))
    notifs = cur.fetchall()
    cur.execute("UPDATE Notificacion SET estado = 'leida' WHERE id_ente = %s", (uid,))
    conn.commit(); cur.close(); conn.close()
    return render_template('notificaciones.html', notificaciones=notifs)

@app.route('/responder_solicitud/<int:id_origen>/<string:tipo_rel>/<string:respuesta>')
def responder_solicitud(id_origen, tipo_rel, respuesta):
    if 'user_id' not in session: return redirect(url_for('login'))
    uid, status = session['user_id'], 'aceptada' if respuesta == 'aceptar' else 'rechazada'
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SET app.current_ente_id = %s", (str(uid),))
    
    cur.execute("UPDATE Relacion SET estado = %s WHERE id_ente1 = %s AND id_ente2 = %s AND tipo = %s", (status, id_origen, uid, tipo_rel))
    if respuesta == 'aceptar' and tipo_rel == 'amistad':
        cur.execute("INSERT INTO Relacion (id_ente1, id_ente2, tipo, direccionalidad, estado, fechaInicio) VALUES (%s, %s, 'amistad', 'simetrica', 'aceptada', CURRENT_DATE) ON CONFLICT DO NOTHING", (uid, id_origen))
    conn.commit(); cur.close(); conn.close()
    return redirect(url_for('notificaciones'))

# --- DASHBOARD DE REPORTES (MODIFICADO PARA AUDITOR) ---
@app.route('/dashboard')
def dashboard():
    # Permitir si es Usuario Común O si es Auditor
    if 'user_id' not in session: return redirect(url_for('login'))
    
    # Conectamos con el rol adecuado
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    
    # [IMPORTANTE] No activamos RLS aquí para que los reportes funcionen para el Auditor
    if session.get('db_role') != 'rol_auditor':
        try: cur.execute("SET app.current_ente_id = %s", (str(session['user_id']),))
        except: pass

    # Consultamos las vistas seguras (si existen) o las queries (si arreglamos SQL)
    # Asumiendo que YA creaste las vistas del paso anterior, usamos SELECT simples:
    try:
        cur.execute("SELECT * FROM vw_reporte_popularidad_grupos")
        rep1 = cur.fetchall()
        cur.execute("SELECT * FROM vw_reporte_actividad_grupos")
        rep2 = cur.fetchall()
        cur.execute("SELECT * FROM vw_reporte_docencia")
        rep3 = cur.fetchall()
        cur.execute("SELECT * FROM vw_reporte_antiguedad")
        rep4 = cur.fetchall()
        cur.execute("SELECT * FROM vw_reporte_tutores")
        rep5 = cur.fetchall()
        cur.execute("SELECT * FROM vw_reporte_calendario")
        rep6 = cur.fetchall()
    except:
        # Fallback si no existen vistas
        rep1=rep2=rep3=rep4=rep5=rep6=[]

    cur.close(); conn.close()
    return render_template('dashboard.html', rep1=rep1, rep2=rep2, rep3=rep3, rep4=rep4, rep5=rep5, rep6=rep6)

# --- 🏢 RUTAS INSTITUCIONALES (SOLO ESCUELAS/EMPRESAS) ---
@app.route('/register_entity', methods=['GET', 'POST'])
def register_entity():
    if request.method == 'POST':
        email = request.form['email']
        p_hash = generate_password_hash(request.form['password'])
        tipo_ente = request.form['tipo_ente'] # 'Dependencia' o 'Organizacion'
        
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            # Crear el Ente Padre
            cur.execute("""
                INSERT INTO Ente (tipo, correoElectronico, password, ubicacion_pais, ubicacion_estado, ubicacion_ciudad, direccion_detalle) 
                VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id_ente
            """, (tipo_ente, email, p_hash, request.form['pais'], request.form['estado'], request.form['ciudad'], request.form['direccion']))
            nuevo_id = cur.fetchone()[0]

            if tipo_ente == 'Dependencia':
                cur.execute("""
                    INSERT INTO Dependencia_UCAB (id_ente, nombre, tipoDependencia, descripcion) 
                    VALUES (%s, %s, %s, %s)
                """, (nuevo_id, request.form['nombre'], request.form['tipo_dep'], request.form['descripcion']))
                
            elif tipo_ente == 'Organizacion':
                cur.execute("""
                    INSERT INTO Organizacion_Asociada (id_ente, RIF, nombre, tipoOrganizacion, descripcion) 
                    VALUES (%s, %s, %s, %s, %s)
                """, (nuevo_id, request.form['rif'], request.form['nombre'], request.form['tipo_org'], request.form['descripcion']))

            conn.commit()
            flash('¡Cuenta institucional creada con éxito! Por favor inicia sesión.')
            return redirect(url_for('login'))
        except Exception as e:
            conn.rollback()
            flash(f'Error en registro: {e}')
        finally:
            cur.close(); conn.close()
    return render_template('register_entity.html')

@app.route('/institucional')
def home_institucional():
    if 'user_id' not in session or session.get('db_role') != 'rol_institucional':
        return redirect(url_for('login'))
        
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT D.nombre, D.tipoDependencia, E.ubicacion_ciudad 
        FROM Dependencia_UCAB D JOIN Ente E ON D.id_ente = E.id_ente 
        WHERE D.id_ente = %s
        UNION
        SELECT O.nombre, O.tipoOrganizacion, E.ubicacion_ciudad 
        FROM Organizacion_Asociada O JOIN Ente E ON O.id_ente = E.id_ente 
        WHERE O.id_ente = %s
    """, (session['user_id'], session['user_id']))
    datos = cur.fetchone()
    
    cur.execute("""
        SELECT id_evento, nombre, fechaHoraInicio, lugar, estado, cantidad_asistentes 
        FROM Evento 
        ORDER BY fechaHoraInicio DESC
    """)
    mis_eventos = cur.fetchall()
    
    cur.close(); conn.close()
    return render_template('home_institucional.html', datos=datos, eventos=mis_eventos)

@app.route('/crear_evento_oficial', methods=['POST'])
def crear_evento_oficial():
    if session.get('db_role') != 'rol_institucional': return redirect(url_for('login'))
    
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO Evento (nombre, tipo, fechaHoraInicio, lugar, estado, descripcion)
            VALUES (%s, %s, %s, %s, 'publicado', %s) RETURNING id_evento
        """, (request.form['nombre'], request.form['tipo'], request.form['fecha'], request.form['lugar'], request.form['desc']))
        id_ev = cur.fetchone()[0]
        cur.execute("INSERT INTO Organizador_Evento (id_evento, id_ente, rol) VALUES (%s, %s, 'Organizador')", (id_ev, session['user_id']))
        conn.commit()
        flash("Evento institucional publicado exitosamente.")
    except Exception as e:
        conn.rollback()
        flash(f"Error creando evento: {e}")
    finally:
        cur.close(); conn.close()
    return redirect(url_for('home_institucional'))

# --- 👑 RUTA ADMIN ---
@app.route('/admin_panel')
def admin_panel():
    if session.get('db_role') != 'rol_admin_dba': return redirect(url_for('login'))
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    
    # 1. Usuarios
    cur.execute("""
        SELECT E.id_ente, E.tipo, E.correoElectronico, 
               COALESCE(P.nombre || ' ' || P.apellido, D.nombre, O.nombre, 'Sin Nombre') as nombre_completo,
               COALESCE(P.ocupacion, D.tipoDependencia, O.tipoOrganizacion, '-') as rol_detalle,
               COALESCE(P.estadoCuenta, 'activo') as estado_cuenta
        FROM Ente E
        LEFT JOIN Persona P ON E.id_ente = P.id_ente
        LEFT JOIN Dependencia_UCAB D ON E.id_ente = D.id_ente
        LEFT JOIN Organizacion_Asociada O ON E.id_ente = O.id_ente
        ORDER BY E.id_ente ASC;
    """)
    usuarios = cur.fetchall()

    # 2. Grupos (Últimos 50)
    cur.execute("SELECT id_grupo, nombre, tipoGrupo, (SELECT COUNT(*) FROM Membresia_Grupo WHERE id_grupo=G.id_grupo) FROM Grupo G ORDER BY id_grupo DESC LIMIT 50")
    grupos = cur.fetchall()

    # 3. Eventos (Últimos 50)
    cur.execute("SELECT id_evento, nombre, tipo, fechaHoraInicio, estado FROM Evento ORDER BY fechaHoraInicio DESC LIMIT 50")
    eventos = cur.fetchall()

    cur.close(); conn.close()
    return render_template('admin_panel.html', usuarios=usuarios, grupos=grupos, eventos=eventos)

@app.route('/admin/toggle_status/<int:id_ente>/<string:tipo>')
def toggle_status(id_ente, tipo):
    if session.get('db_role') != 'rol_admin_dba': return redirect(url_for('login'))
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        if tipo == 'Persona':
            cur.execute("UPDATE Persona SET estadoCuenta = CASE WHEN estadoCuenta = 'activo' THEN 'suspendido' ELSE 'activo' END WHERE id_ente = %s", (id_ente,))
        conn.commit()
        flash("Estado del usuario actualizado.")
    except Exception as e:
        conn.rollback()
        flash(f"Error al cambiar estado: {e}")
    cur.close(); conn.close()
    return redirect(url_for('admin_panel'))

# --- 🕵️ RUTA AUDITOR (DASHBOARD) ---
@app.route('/auditoria')
def dashboard_auditor():
    if session.get('db_role') != 'rol_auditor': return redirect(url_for('login'))
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        cur.execute("SELECT * FROM vw_estadisticas_anonimas")
        stats = cur.fetchone() 
    except Exception as e:
        stats = (0, 0, 0, 0)
        flash(f"Error de lectura: {e}")
    cur.close(); conn.close()
    return render_template('dashboard_auditor.html', stats=stats)

# --- 🧨 RUTAS DE SUPERUSUARIO (ELIMINACIÓN TOTAL) ---

@app.route('/admin/delete_user/<int:id_ente>')
def admin_delete_user(id_ente):
    if session.get('db_role') != 'rol_admin_dba': return redirect(url_for('login'))
    
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        # Gracias al ON DELETE CASCADE del script SQL, esto borra TODO (Perfil, Posts, Likes, etc.)
        cur.execute("DELETE FROM Ente WHERE id_ente = %s", (id_ente,))
        conn.commit()
        flash("Usuario y todos sus datos eliminados permanentemente.")
    except Exception as e:
        conn.rollback()
        flash(f"Error al eliminar usuario: {e}")
    finally:
        cur.close(); conn.close()
    return redirect(url_for('admin_panel'))

@app.route('/admin/delete_group/<int:id_grupo>')
def admin_delete_group(id_grupo):
    if session.get('db_role') != 'rol_admin_dba': return redirect(url_for('login'))
    
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM Grupo WHERE id_grupo = %s", (id_grupo,))
        conn.commit()
        flash("Grupo eliminado.")
    except Exception as e:
        conn.rollback()
        flash(f"Error: {e}")
    cur.close(); conn.close()
    return redirect(url_for('admin_panel'))

@app.route('/admin/delete_event/<int:id_evento>')
def admin_delete_event(id_evento):
    if session.get('db_role') != 'rol_admin_dba': return redirect(url_for('login'))
    
    conn = get_db_connection_with_role()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM Evento WHERE id_evento = %s", (id_evento,))
        conn.commit()
        flash("Evento eliminado.")
    except Exception as e:
        conn.rollback()
        flash(f"Error: {e}")
    cur.close(); conn.close()
    return redirect(url_for('admin_panel'))

if __name__ == '__main__':
    app.run(debug=True, port=5000)