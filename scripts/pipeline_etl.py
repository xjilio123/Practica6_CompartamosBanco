import os
import urllib
import pandas as pd
from sqlalchemy import create_engine

def ingestar_datos_raw():
    print("==================================================================")
    print("🚀 FASE 1: INGESTA DE DATOS EN ENTORNOS AUTOMATIZADOS (ZONA RAW)")
    print("==================================================================")
    
    # Configuración de los parámetros para el servidor local y base de datos dedicada
    SERVER = r'JOAQUINCR\SQLEXPRESS'
    DATABASE = 'Compartamos_Banco'
    
    connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"
    params = urllib.parse.quote_plus(connection_string)
    engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
    
    # Manejo dinámico de rutas relativas basadas en la estructura del proyecto
    base_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(base_dir)
    
    # Mapeo estricto de archivos CSV origen a las tablas de destino de la zona RAW
    archivos = {
        "customers.csv": "raw_customers",
        "products.csv": "raw_products",
        "orders.csv": "raw_orders"
    }
    
    for csv_name, table_name in archivos.items():
        file_path = os.path.join(project_dir, "datasets", csv_name)
        
        # Validación de seguridad: Controla que el usuario local haya colocado los datasets
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"❌ Error Crítico: No se ubicó el archivo obligatorio en: {file_path}")
            
        print(f"📖 Leyendo origen: {file_path}")
        
        # SOLUCIÓN DE ENCODING: Intentamos leer primero con UTF-8. 
        # Si falla por caracteres especiales (como pasará con Latin-1 / ANSI), se activa el fallback automático.
        try:
            df_raw = pd.read_csv(file_path, dtype=str, encoding='utf-8')
        except UnicodeDecodeError:
            print(f"⚠️ El archivo no está en UTF-8. Aplicando decodificación alternativa (latin-1) para preservar caracteres especiales...")
            df_raw = pd.read_csv(file_path, dtype=str, encoding='latin-1')
        
        # Ingesta masiva aplicando idempotencia (if_exists='replace') para asegurar que sea re-procesable
        df_raw.to_sql(table_name, con=engine, index=False, if_exists='replace', schema='dbo')
        print(f"✅ Capa RAW: Tabla '{table_name}' cargada con {len(df_raw)} filas de forma exitosa.")

if __name__ == "__main__":
    ingestar_datos_raw()