from datetime import datetime
import numpy as np
import pandas as pd
from dbt.cli.main import dbtRunner, dbtRunnerResult

from lib import postgresql_lib, utils
from lib.constants import *


def update_dbt_models():
    dbt = dbtRunner()
    cli_args = ["seed", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "+int_apport_projections_monthly"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "+int_fiat_balances_daily"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "+int_yield_stats"]
    res: dbtRunnerResult = dbt.invoke(cli_args)


def update_target_dbt_models():
    dbt = dbtRunner()
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "int_budget_monthly+"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "transaction_projections_mart"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", "F:\Backup\Projects\FDW\\fdw_dbt", "--select", "int_balance_projections_monthly+"]
    res: dbtRunnerResult = dbt.invoke(cli_args)


def extract_data():
    df_projections = postgresql_lib.execute_query("select * from silver.int_apport_projections_monthly where calendar_date < '2060-06-01'", code=True)
    df_projections['calendar_date'] = pd.to_datetime(df_projections['calendar_date'])

    df_balance = postgresql_lib.execute_query("""
        select sum(balance) as balance
        from silver.int_fiat_balances_daily 
        where currency = 'EUR' and calendar_date = '2023-12-31'
        """, code=True)
    
    df_yields = postgresql_lib.execute_query('select * from silver.int_yield_stats', code=True)

    return df_projections, df_balance.iat[0, 0], df_yields


def method_1(df_projections, balance, df_yields):
    df_yields['iteration'] = 0
    df_yields['pos_iteration'] = 0
    df_yields['rate_i'] = 0
    df_yields['rate_i'] = df_yields['rate_i'].astype(float)
    interest = 0.0
    for index, row in df_projections.iterrows():
        df_yields.loc[:, 'iteration'] += 1
        df_yields.loc[:, 'cond'] = df_yields.apply(lambda x: float(x['pos_iteration'])/(max(x['iteration'] - 1, 1)), axis=1)
        df_yields.loc[:, 'rate_i'] = df_yields.apply(lambda x: x['allocation_pos_yield'] if float(x['pos_iteration'])/(max(x['iteration'] - 1, 1)) <= x['pos_year_pct'] else x['allocation_neg_yield'], axis=1)
        df_yields.loc[:, 'pos_iteration'] += df_yields.apply(lambda x: 1 if float(x['pos_iteration'])/(max(x['iteration'] - 1, 1)) <= x['pos_year_pct'] else 0, axis=1)
        rate = df_yields['rate_i'].sum()
        if row['calendar_date'].year > 2040:
            rate = (rate - 1) * 0.75 + 1
        interest = balance*(rate-1)
        if row['calendar_date'].year == 2023:
            df_projections.at[index, 'interest'] = 0
            df_projections.at[index, 'balance'] = balance
            continue
        balance = balance*rate + df_projections.at[index, 'apport']
        df_projections.at[index, 'interest'] = interest
        df_projections.at[index, 'balance'] = balance
    print(df_projections)
    return df_projections


def method_2(df_projections, balance, df_yields):
    df_yields['iteration'] = 0
    df_yields['pos_iteration'] = 1
    df_yields['rate_i'] = df_yields['allocation_pos_yield']
    df_yields['rate_i'] = df_yields['rate_i'].astype(float)
    interest = 0.0
    for index, row in df_projections.iterrows():
        df_yields.loc[:, 'iteration'] += 1
        if df_yields['iteration'].max() % 12 == 0:
            df_yields.loc[:, 'cond'] = df_yields.apply(lambda x: float(x['pos_iteration'])/(max(x['iteration'] - 1, 1)/12) <= x['pos_year_pct'], axis=1)
            df_yields.loc[:, 'rate_i'] = df_yields.apply(lambda x: x['allocation_pos_yield'] if x['cond'] else x['allocation_neg_yield'], axis=1)
            df_yields.loc[:, 'pos_iteration'] += df_yields.apply(lambda x: 1 if x['cond'] else 0, axis=1)
        rate = df_yields['rate_i'].sum()
        if row['calendar_date'].year > 2040:
            rate = (rate - 1) * 0.75 + 1
        interest = balance*(rate-1)
        if row['calendar_date'].year == 2023:
            df_projections.at[index, 'interest'] = 0
            df_projections.at[index, 'balance'] = balance
            continue
        balance = balance*rate + df_projections.at[index, 'apport']
        df_projections.at[index, 'interest'] = interest
        df_projections.at[index, 'balance'] = balance
    print(df_projections)
    return df_projections


def project_set(df_projections, balance, df_yields, yield_method=0):
    if yield_method == 1:
        df_projections = method_1(df_projections, balance, df_yields)
    else:
        df_projections = method_2(df_projections, balance, df_yields)
    return df_projections


def calculate_projections(df_projections, extracted_balance, df_yields, yield_methods=[1, 2, 2]):
    balance = float(extracted_balance) 
    df_results = None
    # for i in range(1):
        # i = 15
    for i in range(df_projections['simulation_set'].max() + 1):
        print(f'Processing simulation set {i}...')
        df_i = project_set(df_projections[df_projections['simulation_set'] == i].copy(), balance, df_yields.copy(), yield_methods[i])
        df_i['simulation_set'] = i
        if df_results is None:
            df_results = df_i
        else:
            df_results = pd.concat([df_results, df_i], ignore_index=True)
    return df_results


def update_tables(df, target_db):
    postgresql_lib.execute_query(f"TRUNCATE TABLE silver.balance_projections", code=True, mode='write', target_db=target_db)
    postgresql_lib.insert_df(df, 'silver.balance_projections', merge=False, target_db=target_db)


def run_projections():
    print('-- Data')
    df_projections, balance, df_yields = extract_data()
    df = calculate_projections(df_projections, balance, df_yields)
    print('-- Insert')
    update_tables(df, 'prod')
    print('--')
    update_target_dbt_models()


if __name__ == '__main__':
    print('--')
    update_dbt_models()
    print('-- Data')
    df_projections, balance, df_yields = extract_data()
    df = calculate_projections(df_projections, balance, df_yields)
    print('-- Insert')
    update_tables(df, 'prod')
    print('--')
    update_target_dbt_models()