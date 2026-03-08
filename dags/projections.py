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
        from gold.balance_metrics 
        where currency = 'EUR' 
            and calendar_date = '2023-12-31'
            and time_grain = 'day'
        """, code=True)
    
    df_yields = postgresql_lib.execute_query('select * from silver.int_yield_stats', code=True)

    return df_projections, df_balance.iat[0, 0], df_yields


def _calculate_projections(
    df_projections, balance, df_yields, 
    pos_iteration_init=0, 
    rate_i_init=None,
    update_period=1,
    pos_year_pct_modifier=0
):
    """
    Unified projection calculation function.
    
    Parameters:
    - pos_iteration_init: Initial value for pos_iteration
    - rate_i_init: Initial value for rate_i
    - update_period: Integer, how frequently to update yields
    """
    # Initialize simulation columns
    df_yields['iteration'] = -1                # Count of periods simulated per asset
    df_yields['pos_iteration'] = pos_iteration_init
    if rate_i_init is None:
        df_yields['rate_i'] = df_yields['avg_pos_yield']
    else:
        df_yields['rate_i'] = rate_i_init
    df_yields['rate_i'] = df_yields['rate_i'].astype(np.float64)
    
    # Initialize balance per asset based on target_allocation
    for _, asset_row in df_yields.iterrows():
        asset_name = asset_row['level_3']
        df_projections[f'balance_{asset_name}'] = balance * float(asset_row['target_allocation'])
        df_projections[f'interest_{asset_name}'] = 0.0
    
    # Initialize total columns
    df_projections['interest'] = 0.0
    df_projections['balance'] = balance
    df_projections = df_projections.reset_index(drop=True)

    for index, row in df_projections.iterrows():

        # Initialize balance per asset based on target_allocation
        for _, asset_row in df_yields.iterrows():
            asset_name = asset_row['level_3']
            df_projections.at[index,f'balance_{asset_name}'] = balance * float(asset_row['target_allocation'])

        # Increment period counter for each asset
        df_yields.loc[:, 'iteration'] += 1

        # Determine if we should update yields this period
        if rate_i_init is not None:
            should_update = False
        elif update_period <= 1:
            should_update = True
        else:
            should_update = df_yields['iteration'].max() % update_period == 0

        if should_update:
            # Calculate for each asset: realized positive period ratio so far
            df_yields.loc[:, 'cond'] = df_yields.apply(
                lambda x: float(x['pos_iteration']) / (max(x['iteration'] - 1, 1) / update_period) <= (float(x['pos_year_pct']) * (1 + pos_year_pct_modifier)),
                axis=1
            )

            # Pick yield of this asset for this period: positive or negative
            pos_yield_col = 'avg_pos_yield'
            neg_yield_col = 'avg_neg_yield'

            df_yields.loc[:, 'rate_i'] = df_yields.apply(
                lambda x: x[pos_yield_col] if x['cond'] else x[neg_yield_col],
                axis=1
            )
            df_yields.loc[:, 'pos_iteration'] += df_yields.apply(
                lambda x: 1 if x['cond'] else 0,
                axis=1
            )


        # First year is baseline: set 0 interest, skip updating balance
        if row['calendar_date'].year == 2023:
            continue
        

        # Calculate per-asset interest and update balances
        interest = 0.0
        temp_balance = 0.0
        for _, asset_row in df_yields.iterrows():
            asset_name = asset_row['level_3']
            asset_rate = asset_row['rate_i']
            
            # If the projection year is after 2040, dampen (shrink) the returns for this asset
            if row['calendar_date'].year >= 2040:
                asset_rate = (asset_rate - 1) * (0.5 + 0.5 *(2070 - row['calendar_date'].year) / 30) + 1
            
            # Calculate interest for this asset
            asset_interest = df_projections.at[index, f'balance_{asset_name}'] * (asset_rate - 1)
            df_projections.at[index, f'interest_{asset_name}'] = asset_interest

            temp_balance += df_projections.at[index, f'balance_{asset_name}']
            interest += asset_interest
        
        apport = df_projections.at[index, 'apport']
        # print(f'{row["calendar_date"]} - balance: {balance} + ({apport}) (interest: {interest:.2f} / {interest / balance * 100:.2f}%)')
        # print(f' - asset_balance: {temp_balance}')
        balance = balance + interest + apport

        for _, asset_row in df_yields.iterrows():
            asset_name = asset_row['level_3']
            df_projections.at[index, f'balance_{asset_name}'] = balance * float(asset_row['target_allocation'])
        df_projections.at[index, 'interest'] = interest
        df_projections.at[index, 'balance'] = balance

    # Transform to long format
    cols_to_drop = ['balance', 'interest']
    # print(df_projections[['calendar_date', 'balance', 'apport', 'interest']])
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

    return df_long


def method_1(df_projections, balance, df_yields):
    return _calculate_projections(
        df_projections, balance, df_yields,
        rate_i_init=1.007974 #10%
    )


def method_2(df_projections, balance, df_yields):
    return _calculate_projections(
        df_projections, balance, df_yields,
        rate_i_init=1.011715 #15%
    )


def method_3(df_projections, balance, df_yields):
    return _calculate_projections(
        df_projections, balance, df_yields,
        rate_i_init=1.015379 #20%
    )


def method_4(df_projections, balance, df_yields):
    return _calculate_projections(
        df_projections, balance, df_yields,
        pos_iteration_init=0,
        rate_i_init=None,
        pos_year_pct_modifier=-0.05,
        update_period=12 
    )


def method_5(df_projections, balance, df_yields):
    return _calculate_projections(
        df_projections, balance, df_yields,
        pos_iteration_init=0,
        rate_i_init=None,
        pos_year_pct_modifier=-0.1,
        update_period=12   
    )


def project_set(df_projections, balance, df_yields, yield_method=2):
    method_func = globals().get(f'method_{yield_method}')
    if method_func is None:
        raise ValueError(f"No method implemented for yield_method={yield_method}")
    df_projections = method_func(df_projections, balance, df_yields)
    return df_projections


def calculate_projections(df_projections, extracted_balance, df_yields, yield_methods=[3, 2, 4, 5, 1]):
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
    # print('--')
    # update_dbt_models()
    print('-- Data')
    df_projections, balance, df_yields = extract_data()
    df = calculate_projections(df_projections, balance, df_yields)    
    print('-- Insert')
    update_tables(df, 'prod')
    print('--')
    update_target_dbt_models()