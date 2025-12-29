from datetime import datetime
from pathlib import Path
import numpy as np
import pandas as pd
from dbt.cli.main import dbtRunner, dbtRunnerResult

from lib import postgresql_lib, utils
from lib.constants import *

SCRIPT_DIR = Path(__file__).resolve().parent.parent


def update_dbt_models():
    dbt = dbtRunner()
    cli_args = ["seed", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt')]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "+int_apport_projections_monthly"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "+int_fiat_balances_daily"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "+int_yield_stats"]
    res: dbtRunnerResult = dbt.invoke(cli_args)


def update_target_dbt_models():
    dbt = dbtRunner()
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "int_budget_monthly+"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "transaction_projections_mart"]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "int_balance_projections_monthly+"]
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


def _calculate_projections(df_projections, balance, df_yields, 
                           pos_iteration_init=0, 
                           rate_i_init=None,
                           update_yearly=False):
    """
    Unified projection calculation function.
    
    Parameters:
    - pos_iteration_init: Initial value for pos_iteration (0 for method_1, 1 for method_2)
    - rate_i_init: Initial value for rate_i (None/0 for method_1, 'avg_pos_yield' for method_2)
    - update_yearly: If True, only update yields every 12 months (method_2), else every period (method_1)
    - use_allocation_yields: If True, use allocation_pos_yield/allocation_neg_yield (method_2),
                            else use avg_pos_yield/avg_neg_yield (method_1)
    """
    # Initialize simulation columns
    df_yields['iteration'] = 0                # Count of periods simulated per asset
    df_yields['pos_iteration'] = pos_iteration_init
    if isinstance(rate_i_init, str):
        df_yields['rate_i'] = df_yields[rate_i_init]
    else:
        df_yields['rate_i'] = rate_i_init
    df_yields['rate_i'] = df_yields['rate_i'].astype(float)
    
    # Initialize balance per asset based on target_allocation
    for _, asset_row in df_yields.iterrows():
        asset_name = asset_row['level_3']
        df_projections[f'balance_{asset_name}'] = balance * asset_row['target_allocation']
        df_projections[f'interest_{asset_name}'] = 0.0
    
    # Initialize total columns
    df_projections['interest'] = 0.0
    df_projections['balance'] = balance

    for index, row in df_projections.iterrows():
        # Increment period counter for each asset
        df_yields.loc[:, 'iteration'] += 1

        # Determine if we should update yields this period
        should_update = True
        update_period = 12 if update_yearly else 1
        if update_yearly:
            should_update = df_yields['iteration'].max() % 12 == 0

        if should_update:
            # Calculate for each asset: realized positive period ratio so far
            df_yields.loc[:, 'cond'] = df_yields.apply(
                lambda x: float(x['pos_iteration']) / (max(x['iteration'] - 1, 1) / update_period) <= x['pos_year_pct'],
                axis=1
            )


            # Pick yield of this asset for this period: positive or negative
            pos_yield_col = 'avg_pos_yield'
            neg_yield_col = 'avg_neg_yield'

            df_yields.loc[:, 'rate_i'] = df_yields.apply(
                lambda x: x[pos_yield_col] if x['cond'] else x[neg_yield_col],
                axis=1
            )

            # Update positive period counter if it was a positive period in this draw
            df_yields.loc[:, 'pos_iteration'] += df_yields.apply(
                lambda x: 1 if x['cond'] else 0,
                axis=1
            )

        # First year is baseline: set 0 interest, skip updating balance
        if row['calendar_date'].year == 2023:
            continue

        # Calculate per-asset interest and update balances
        interest = 0.0
        for _, asset_row in df_yields.iterrows():
            asset_name = asset_row['level_3']
            asset_rate = asset_row['rate_i']
            
            # If the projection year is after 2040, dampen (shrink) the returns for this asset
            if row['calendar_date'].year > 2040:
                asset_rate = (asset_rate - 1) * 0.75 + 1
            
            # Calculate interest for this asset
            asset_interest = df_projections.at[index, f'balance_{asset_name}'] * (asset_rate - 1)
            df_projections.at[index, f'interest_{asset_name}'] = asset_interest
            
            interest += asset_interest
        
        apport = df_projections.at[index, 'apport']
        balance = balance + interest + apport
        for _, asset_row in df_yields.iterrows():
            asset_name = asset_row['level_3']
            df_projections.at[index, f'balance_{asset_name}'] = balance * asset_row['target_allocation']
        df_projections.at[index, 'interest'] = interest
        df_projections.at[index, 'balance'] = balance

    # Transform to long format
    cols_to_drop = ['balance', 'interest']
    df_assets = df_projections.drop(columns=cols_to_drop).copy()
    
    balance_cols = [col for col in df_assets.columns if col.startswith('balance_')]

    asset_rows = []
    for balance_col in balance_cols:
        asset_name = balance_col.replace('balance_', '')
        interest_col = f"interest_{asset_name}"
        df_asset = df_assets.copy()
        columns_needed = [
            'calendar_date',
            'is_end_of_period',
            'simulation_set',
            balance_col,
            interest_col,
            'apport'
        ]
        df_asset = df_asset[columns_needed]
        df_asset = df_asset.rename(columns={balance_col: 'balance', interest_col: 'interest'})
        df_asset['level_3'] = asset_name
        asset_rows.append(df_asset)

    df_long = pd.concat(asset_rows, ignore_index=True)
    df_long = df_long[
        [
            'calendar_date',
            'is_end_of_period',
            'simulation_set',
            'level_3',
            'interest',
            'apport',
            'balance',
        ]
    ]
    print(df_long)

    return df_long


def method_1(df_projections, balance, df_yields):
    """Method 1: Updates yields every period"""
    return _calculate_projections(
        df_projections, balance, df_yields,
        pos_iteration_init=0,
        rate_i_init=None,
        update_yearly=False
    )


def method_2(df_projections, balance, df_yields):
    """Method 2: Updates yields every 12 months"""
    return _calculate_projections(
        df_projections, balance, df_yields,
        pos_iteration_init=1,
        rate_i_init='avg_pos_yield',
        update_yearly=True
    )


def project_set(df_projections, balance, df_yields, yield_method=0):
    if yield_method == 1:
        df_projections = method_1(df_projections, balance, df_yields)
    else:
        df_projections = method_2(df_projections, balance, df_yields)
    return df_projections


def calculate_projections(df_projections, extracted_balance, df_yields, yield_methods=[1, 2, 2]):
    balance = float(extracted_balance) 
    df_results = None
    for i in range(1):
        # i = 15
    # for i in range(df_projections['simulation_set'].max() + 1):
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
    # print('--')
    # update_dbt_models()
    print('-- Data')
    df_projections, balance, df_yields = extract_data()
    df = calculate_projections(df_projections, balance, df_yields)    
    print('-- Insert')
    update_tables(df, 'prod')
    # print('--')
    # update_target_dbt_models()