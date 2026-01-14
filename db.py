# --- EN ARCHIVO: db.py ---
import psycopg2
from psycopg2.extras import RealDictCursor

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="soyucab_db",
            # CAMBIO AQUÍ: Usamos el usuario limitado, no postgres
            user="app_backend",      
            password="soyucab_pass", 
            port="5432"
        )
        return conn
    except Exception as e:
        print(f"Error conectando a la BD: {e}")
        return None