import os

# Configuración
RUTA_PROYECTO = r'C:\Users\Alessi\Documents\BASES DE DATOS\Proyecto\SoyUCAB_App'
ARCHIVO_SALIDA = 'contenido_proyecto_soyucab.txt'
# Carpetas o extensiones a ignorar
IGNORAR_CARPETAS = {'__pycache__', '.git', '.venv', 'node_modules'}
EXTENSIONES_PERMITIDAS = {'.py', '.html', '.css', '.js', '.sql', '.txt'}

def exportar_proyecto():
    with open(ARCHIVO_SALIDA, 'w', encoding='utf-8') as f_salida:
        f_salida.write(f"ESTRUCTURA Y CONTENIDO DEL PROYECTO: {os.path.basename(RUTA_PROYECTO)}\n")
        f_salida.write("="*60 + "\n\n")

        for raiz, carpetas, archivos in os.walk(RUTA_PROYECTO):
            # Filtrar carpetas a ignorar
            carpetas[:] = [d for d in carpetas if d not in IGNORAR_CARPETAS]

            for nombre_archivo in archivos:
                ruta_completa = os.path.join(raiz, nombre_archivo)
                extension = os.path.splitext(nombre_archivo)[1]

                # Solo procesar si es una extensión permitida
                if extension in EXTENSIONES_PERMITIDAS:
                    rel_path = os.path.relpath(ruta_completa, RUTA_PROYECTO)
                    
                    f_salida.write(f"\n--- INICIO DE ARCHIVO: {rel_path} ---\n")
                    f_salida.write("-" * 40 + "\n")
                    
                    try:
                        with open(ruta_completa, 'r', encoding='utf-8') as f_entrada:
                            f_salida.write(f_entrada.read())
                    except Exception as e:
                        f_salida.write(f"[ERROR AL LEER EL ARCHIVO: {str(e)}]")
                    
                    f_salida.write(f"\n--- FIN DE ARCHIVO: {rel_path} ---\n")
                    f_salida.write("="*60 + "\n")

    print(f"Éxito: El contenido ha sido exportado a {ARCHIVO_SALIDA}")

if __name__ == "__main__":
    exportar_proyecto()