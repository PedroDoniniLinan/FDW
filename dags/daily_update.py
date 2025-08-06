import pandas as pd
import datetime as dt
from time import time
from dbt.cli.main import dbtRunner, dbtRunnerResult

from lib import postgresql_lib, google_lib
from lib.constants import *

from projections import run_projections


def format_amounts(df, column):
    if column in df.columns:
        # df[column] = df[column].apply(lambda x: float(x)*1e9)
        df[column] = df[column].astype(float)
    return df


def update_source(source_name, df, target_db):
    """
    Updates a source table in the database with data from a DataFrame.
    
    Args:
        source_name (str): Name of the source to update ('income', 'expenses', 'prices', etc.)
        df (pandas.DataFrame): DataFrame containing the data to insert
        
    The function handles different data transformations based on the source:
    - Converts amount columns to float
    - For income/expenses: Adds transaction type and handles sign of amount
    - For prices: Melts the dataframe and filters empty values
    - Converts calendar dates to datetime
    - Truncates existing data before inserting (except for expenses)
    """
    table_name = db[source_name]['table']

    if source_name == 'prices':
        df = pd.melt(df, id_vars=['ticker', 'currency'], var_name='calendar_date', value_name='price')
        df = df[(df['price'] != '') & (df['price'].notna())]

    for column in ['amount', 'price', 'units', 'tax']:
        format_amounts(df, column)
    
    if source_name in ['income', 'expenses']:
        df['transaction_type'] = source_name.capitalize()
        df['amount'] = -df['amount'] if source_name == 'expenses' else df['amount']
    
    if 'calendar_date' in df.columns:
        df['calendar_date'] = df['calendar_date'].apply(lambda x : dt.datetime.strptime(str(x),'%d/%m/%Y'))
    
    if source_name != 'expenses':
        postgresql_lib.execute_query(f"TRUNCATE TABLE {table_name}", code=True, mode='write', target_db=target_db)
    
    postgresql_lib.insert_df(df, table_name, merge=False, target_db=target_db)


def update_source_from_sheets(target_db):
    """
    Updates all source tables by reading data from Google Sheets and inserting into database.
    
    Reads data from configured Google Sheets (defined in constants.sheets) and updates
    corresponding database tables using update_source().
    
    Returns:
        float: Total execution time in seconds
    """
    print('\n---------------- Update source -----------------')
    start_time = time()
    for s in sheets:
        print(s)
        df = google_lib.read_spreadsheet(sheets[s]['id'], sheets[s]['range'])
        update_source(s, df, target_db)
    print("--------------- %.4f seconds ---------------" % (time() - start_time))
    return (time() - start_time)


def run_validation_dbt():
    print('\n-------------- DBT block ----------------')
    start_time = time()
    dbt = dbtRunner()
    # cli_args = ["seed", "--select", "income_mapping"]
    # res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "+balance_discrepancies"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    print("--------------- %.4f seconds ---------------" % (time() - start_time))
    return (time() - start_time)


def validate_balances():
    print('\n-------------- Validation block --------------')
    start_time = time()
    df = postgresql_lib.execute_query('select * from gold.balance_discrepancies', code=True)
    validated = df.size == 0
    if not validated:
        print('====ERROR====')
        print(df)
    else:
        print('Validation: OK')
    print("--------------- %.4f seconds ---------------" % (time() - start_time))
    return validated, (time() - start_time)


def run_dbt():
    print('\n-------------- DBT block ----------------')
    start_time = time()
    dbt = dbtRunner()
    cli_args = ["seed", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--full-refresh"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    dbt = dbtRunner()
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    print("--------------- %.4f seconds ---------------" % (time() - start_time))
    return (time() - start_time)


if __name__ == '__main__':
    run_time = 0
    run_time += update_source_from_sheets('prod')
    run_time += run_validation_dbt()
    validated, run_time_ = validate_balances()
    if validated:
        run_time += run_time_
        run_time += run_dbt()
        run_projections()

