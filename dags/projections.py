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


def method_1(df_projections, balance, df_yields):
    """
    Simulate yearly yield application to a monthly projection using a stochastic method.

    For each row (month) in df_projections:
    - For each asset in df_yields, update how many periods/years ('iterations') and 'positive' periods it has seen.
    - Calculate the probability of seeing a positive yield so far.
    - Assign either the positive or negative yield to this cycle, based on whether the realized positive ratio is below or at the expected probability (pos_year_pct).
    - Track whether the current simulation period is a positive year for this asset, and increment accordingly.
    - Sum all asset returns to get overall portfolio rate for this period.
    - If the projection date is after 2040, dampen the rate (simulate uncertainty/caution).
    - Calculate interest for the period based on current balance and rate.
    - If the projection is still year 2023 (baseline year), set interest to 0 and leave balance unchanged.
    - Otherwise, update balance by applying yield and this month's apport (contribution).
    - Store the results back into df_projections as 'interest' and 'balance'.
    """
    # Initialize simulation columns
    df_yields['iteration'] = 0                # Count of periods simulated per asset
    df_yields['pos_iteration'] = 0            # How many of those periods were 'positive'
    df_yields['rate_i'] = 0                   # Per-asset rate applied each cycle
    df_yields['rate_i'] = df_yields['rate_i'].astype(float)
    interest = 0.0

    for index, row in df_projections.iterrows():
        # Increment period counter for each asset
        df_yields.loc[:, 'iteration'] += 1

        # Calculate for each asset: realized positive period ratio so far
        df_yields.loc[:, 'cond'] = df_yields.apply(
            lambda x: float(x['pos_iteration']) / (max(x['iteration'] - 1, 1)),
            axis=1
        )

        # Pick yearly yield of this asset for this period: positive or negative
        df_yields.loc[:, 'rate_i'] = df_yields.apply(
            lambda x: x['allocation_pos_yield'] 
                if float(x['pos_iteration']) / (max(x['iteration'] - 1, 1)) <= x['pos_year_pct']
                else x['allocation_neg_yield'],
            axis=1
        )

        # Update positive period counter if it was a positive year in this draw
        df_yields.loc[:, 'pos_iteration'] += df_yields.apply(
            lambda x: 1 
                if float(x['pos_iteration']) / (max(x['iteration'] - 1, 1)) <= x['pos_year_pct']
                else 0,
            axis=1
        )

        # The overall period return is the sum of all asset returns
        rate = df_yields['rate_i'].sum()

        # If the projection year is after 2040, dampen (shrink) the returns
        if row['calendar_date'].year > 2040:
            rate = (rate - 1) * 0.75 + 1

        # Calculate period's interest
        interest = balance * (rate - 1)

        # First year is baseline: set 0 interest, skip updating balance
        if row['calendar_date'].year == 2023:
            df_projections.at[index, 'interest'] = 0
            df_projections.at[index, 'balance'] = balance
            continue

        # Update the portfolio: apply rate & new apport
        balance = balance * rate + df_projections.at[index, 'apport']
        df_projections.at[index, 'interest'] = interest
        df_projections.at[index, 'balance'] = balance

    print(df_projections)
    return df_projections


def method_2(df_projections, balance, df_yields):
    """
    Simulates asset yields and portfolio balance evolution using a monthly-to-yearly aggregation approach.

    This method increments an 'iteration' counter for each asset monthly. Every 12 periods (i.e., yearly),
    it evaluates, for each asset, whether the simulated ratio of positive periods matches the expected positive
    year percentage (`pos_year_pct`). Based on this, it assigns either the positive or negative yield for the
    coming year, updates the positive-period counter, and computes the resulting portfolio growth.

    Args:
        df_projections (pd.DataFrame): DataFrame with dates, apport, and initial portfolio projections per period.
        balance (float): Starting balance for the projection.
        df_yields (pd.DataFrame): DataFrame summarizing assets' yields and allocation splits.

    Returns:
        pd.DataFrame: The input df_projections with updated 'interest' and 'balance' columns.
    """
    df_yields['iteration'] = 0
    df_yields['pos_iteration'] = 1
    df_yields['rate_i'] = df_yields['allocation_pos_yield']
    df_yields['rate_i'] = df_yields['rate_i'].astype(float)
    interest = 0.0
    for index, row in df_projections.iterrows():
        # Increment the period (month) counter for all assets
        df_yields.loc[:, 'iteration'] += 1

        # Each 12 iterations (yearly), pick yearly return: positive or negative for each asset
        if df_yields['iteration'].max() % 12 == 0:
            # Check if positive periods so far match expected ratio
            df_yields.loc[:, 'cond'] = df_yields.apply(
                lambda x: float(x['pos_iteration']) / (max(x['iteration'] - 1, 1) / 12) <= x['pos_year_pct'],
                axis=1
            )
            # Assign yearly yield (positive/negative) based on the check
            df_yields.loc[:, 'rate_i'] = df_yields.apply(
                lambda x: x['allocation_pos_yield'] if x['cond'] else x['allocation_neg_yield'],
                axis=1
            )
            # Increment positive year counter only if positive year assigned
            df_yields.loc[:, 'pos_iteration'] += df_yields.apply(
                lambda x: 1 if x['cond'] else 0, axis=1
            )

        # Calculate portfolio rate as sum of asset-weighted rates
        rate = df_yields['rate_i'].sum()

        # Dampen returns after year 2040
        if row['calendar_date'].year > 2040:
            rate = (rate - 1) * 0.75 + 1

        # Calculate interest for this period
        interest = balance * (rate - 1)

        # If baseline year (2023), set interest to 0 and do not update balance
        if row['calendar_date'].year == 2023:
            df_projections.at[index, 'interest'] = 0
            df_projections.at[index, 'balance'] = balance
            continue

        # Update portfolio balance with interest and new apport
        balance = balance * rate + df_projections.at[index, 'apport']
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