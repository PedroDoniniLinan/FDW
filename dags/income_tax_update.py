from pathlib import Path

import numpy as np
import pandas as pd
from dbt.cli.main import dbtRunner, dbtRunnerResult
from lib import postgresql_lib
from lib.constants import *

SCRIPT_DIR = Path(__file__).resolve().parent.parent


def update_dbt_models():
    dbt = dbtRunner()
    cli_args = ["seed", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt')]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "+int_fiat_exchanges"]
    res: dbtRunnerResult = dbt.invoke(cli_args)


def extract_data():
    df_exchanges = postgresql_lib.execute_query('select * from silver.int_fiat_exchanges', code=True)
    df_exchanges['calendar_date'] = pd.to_datetime(df_exchanges['calendar_date'])
    return df_exchanges


def calculate_taxes(df):
    df['avg_price'] = 0
    avg_price_list = []
    sales = []
    print('Calculating avg price and sales...')
    for t in df['ticker'].unique():
        for c in df['currency'].unique():
            df_t = df.loc[(df['ticker'] == t)&(df['currency'] == c)]
            avg_price = 0
            for index, row in df_t.iterrows():
                if round(row['net_amount'], 6) <= 0:
                    avg_price = avg_price
                elif row['net_amount'] > 0:
                    try:
                        avg_price = (avg_price * (row['total_amount'] - row['net_amount']) + row['exchange_value']) / row['total_amount']
                    except:
                        print(row)
                        raise Exception
                avg_price_list.append([
                    # row['id'] ,
                    row['ticker'],
                    row['currency'],
                    row['calendar_date'],
                    avg_price, row['total_amount'],
                    avg_price * max(row['total_amount'], 0)])
                if row['net_amount'] < 0:
                    sales.append([
                        # row['security_type'],
                        row['ticker'],
                        row['currency'],
                        row['calendar_date'],
                        row['net_amount'],
                        avg_price,
                        row['price'],
                        row['abs_amount'] * avg_price,
                        row['abs_amount'] * row['price'],
                        (avg_price - row['price']) * row['net_amount'] - row['tax']])
    df_pos = pd.DataFrame(np.array(avg_price_list), columns=['ticker', 'currency', 'calendar_date', 'avg_price', 'units', 'position'])
    print(df_pos)

    # if len(sales) > 0:
    df_s = pd.DataFrame(np.array(sales), columns=['ticker', 'currency', 'calendar_date', 'net_amount', 'avg_price', 'sale_price',
                                                'applied_value', 'sale_value', 'pnl'])
    print(df_s)

    return df_pos, df_s


def update_tables(df_pos, df_sales, target_db):
    postgresql_lib.execute_query("TRUNCATE TABLE silver.taxes_avg_price_raw", code=True, mode='write', target_db=target_db)
    postgresql_lib.execute_query("TRUNCATE TABLE silver.taxes_pnl_raw", code=True, mode='write', target_db=target_db)
    postgresql_lib.insert_df(df_pos, 'silver.taxes_avg_price_raw', merge=False, target_db=target_db)
    postgresql_lib.insert_df(df_sales, 'silver.taxes_pnl_raw', merge=False, target_db=target_db)


if __name__ == '__main__':
    print('--')
    update_dbt_models()
    print('-- Data')
    df_exchange = extract_data()
    print(df_exchange)
    df_pos, df_sales = calculate_taxes(df_exchange)
    print('-- Insert')
    update_tables(df_pos, df_sales, 'prod')
