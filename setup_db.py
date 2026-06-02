import os
import re
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

# Get connection strings from env
def get_engine(prefix):
    user = os.getenv(f"{prefix}_USER", "root")
    password = os.getenv(f"{prefix}_PASS", "")
    host = os.getenv(f"{prefix}_HOST", "localhost")
    port = os.getenv(f"{prefix}_PORT", "3306")
    db_name = os.getenv(f"{prefix}_NAME", "railway")
    return create_engine(f"mysql+pymysql://{user}:{password}@{host}:{port}/{db_name}")

sales_engine = get_engine("SALES_DB")
warehouse_engine = get_engine("WAREHOUSE_DB")
marketing_engine = get_engine("MARKETING_DB")

def execute_sql_script(engine, file_path):
    print(f"Executing {file_path}...")
    with open(file_path, 'r') as f:
        sql = f.read()
    
    # Remove USE statements
    sql = re.sub(r'USE\s+\w+;', '', sql, flags=re.IGNORECASE)
    
    # Split by semicolon and execute
    statements = sql.split(';')
    with engine.begin() as conn:
        for stmt in statements:
            stmt = stmt.strip()
            if stmt:
                conn.execute(text(stmt))

if __name__ == "__main__":
    execute_sql_script(sales_engine, "scripts/sales_tables.sql")
    execute_sql_script(warehouse_engine, "scripts/warehouse_tables.sql")
    execute_sql_script(marketing_engine, "scripts/marketing_tables.sql")
    print("Tables created successfully.")
