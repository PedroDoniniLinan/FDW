import os
from pathlib import Path

import pandas as pd
import psycopg2
from dotenv import load_dotenv


def execute_query(query_name, code=False, mode='select', target_db='prod'):
    """Execute a SQL query against a PostgreSQL database.
    
    Args:
        query_name (str): Either a SQL query string (if code=True) or path to SQL file
        code (bool, optional): If True, query_name contains SQL code. If False, query_name is a file path. Defaults to False.
        mode (str, optional): Query execution mode - 'select', 'update' or 'management'. Defaults to 'select'.
    
    Returns:
        Union[pd.DataFrame, str]: For select queries, returns DataFrame with results. For other modes returns 'Success' or 'Failed'.
    """
    load_dotenv()
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_DATABASE') if target_db == 'prod' else os.getenv('DB_DATABASE_DEV'),
        port=5433
    )

    if not code:
        with open(query_name) as file:
            query = file.read()
    else:
        query = query_name

    cursor = conn.cursor()
    cursor.execute(query)
    df = 'Failed'
    if mode == 'select':
        results = cursor.fetchall()
        df = pd.DataFrame(results, columns=[desc[0] for desc in cursor.description])
    elif mode == 'write':
        conn.commit()
        df = 'Query executed successfully'
    cursor.close()
    conn.close()

    return df


def list_row_values(row):
    """Convert row values to a list of SQL-safe strings.
    
    Args:
        row (pd.Series): Row from a pandas DataFrame
        
    Returns:
        list: List of values formatted as SQL strings, with NULL handling and quote escaping
    """
    result = []
    for val in row.values:
        if str(val) == 'nan':
            result.append('NULL')
        else:
            result.append("'" + str(val).replace("'", "") + "'")
    return result


def generate_insert_query(df, table, keys, merge=True):
    """Generate a PostgreSQL INSERT or UPSERT query from a DataFrame.
    
    Args:
        df (pd.DataFrame): DataFrame containing data to insert
        table (str): Target table name
        keys (list): List of column names that form the unique key
        merge (bool, optional): If True, generates UPSERT query with ON CONFLICT clause. Defaults to True.
    
    Returns:
        str: Generated SQL query string
    """
    if merge:
        merge_clause = """
        ON CONFLICT ({keys}) DO UPDATE SET 
        {update_sets}
        """
    else:
        merge_clause = ''

    query = """
    INSERT INTO {table} 
    {columns} VALUES {values}
    """ + merge_clause + ";"

    rows = []
    for i, row in df.iterrows():
        row_values = "\n(" + ", ".join(list_row_values(row)) + ")"
        rows.append(row_values)
    values_string = ", ".join(rows)

    update_sets = ", ".join(f"{k} = EXCLUDED.{k}" for k in df.columns if k not in keys)
    keys_string = ", ".join(keys)

    query = query.format(
        table=table,
        columns="\n(" + ", ".join(df.columns) + ")",
        values=values_string,
        keys=keys_string,
        update_sets=update_sets
    )
    return query


def insert_df(df, table, keys=[], merge=True, target_db='prod'):
    """Insert a DataFrame into a PostgreSQL table.
    
    Args:
        df (pd.DataFrame): DataFrame to insert
        table (str): Target table name
        keys (list): List of column names that form the unique key
        merge (bool, optional): If True, performs UPSERT instead of INSERT. Defaults to True.
    """
    query = generate_insert_query(df, table, keys, merge)
    query_dir = Path('queries')
    query_dir.mkdir(exist_ok=True)
    with open(query_dir / 'debug_query.sql', 'w+') as f:
        f.write(query)
    execute_query(query, code=True, mode='write', target_db=target_db)


def recreate_tables():
    """Recreate all bronze tables in both main and dev databases."""
    tables = ['external_transactions', 'exchanges', 'balances', 'prices', 'transfers']
    script_dir = Path(__file__).resolve().parent.parent
    for table in tables:
        query_path = script_dir / 'queries' / 'table_creation' / f'create_{table}.sql'
        # for target_db in ['dev']:
        for target_db in ['prod', 'dev']:
            print(f"Recreating table {table} in {target_db} database")
            execute_query(f"DROP TABLE IF EXISTS bronze.{table} CASCADE", code=True, mode='write', target_db=target_db)
            execute_query(str(query_path), code=False, mode='write', target_db=target_db)


if __name__ == '__main__':
    recreate_tables()
