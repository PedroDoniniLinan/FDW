from datetime import datetime
from pathlib import Path

import pandas as pd
from dbt.cli.main import dbtRunner, dbtRunnerResult
from lib import postgresql_lib, utils
from lib.constants import *

SCRIPT_DIR = Path(__file__).resolve().parent.parent


def extract_data():
    df_balance = postgresql_lib.execute_query('select * from silver.int_balance_allocations_yearly', code=True)
    df_balance['calendar_date'] = pd.to_datetime(df_balance['calendar_date'])
    df_performance = postgresql_lib.execute_query("select * from silver.int_price_yields_monthly where calendar_date >= '2022-01-01'", code=True)
    df_performance['calendar_date'] = pd.to_datetime(df_performance['calendar_date'])
    return df_balance, df_performance

def apply_performance(row, df_month_performance, month):
    try:
        return df_month_performance[df_month_performance['level_3'] == row['asset']]['performance'].reset_index(drop=True)[0]
    except:
        # print(month, ' - ', row['asset'])
        return 1

def simulate_set(set_num, start_date, df_balance, df_performance):
    results = []
    # for method in ['no rebalance']:
    for method in ['no rebalance', 'monthly rebalance', 'bimonthly rebalance', 'quarterly rebalance', 'quarterly rebalance (-1)', 'quarterly rebalance (-2)', 'semi-annual rebalance']:
        df_year_balance = df_balance[(df_balance['calendar_date'] == start_date)&(df_balance['set'] == set_num)].copy()
        results.append({'set': set_num, 'method': method, 'start_date': start_date, 'calendar_date': utils.date_add(start_date, -1, 'month').strftime('%Y-%m-%d'), 'balance': float(round(df_year_balance['allocated_balance'].sum(), 2)), 'capital_gain': 0})
        month = datetime.fromisoformat(start_date)
        while month < datetime.fromisoformat('2026-04-01'):
            # print(month)
            df_month_performance = df_performance[df_performance['calendar_date'] == month].copy()
            df_year_balance.loc[:, 'performance'] = df_year_balance.apply(lambda row: apply_performance(row, df_month_performance, month), axis=1)
            df_year_balance.loc[:, 'new_balance'] = df_year_balance.apply(lambda row: row['allocated_balance']*float(row['performance']), axis=1)
            results.append({'set': set_num, 'method': method, 'start_date': start_date, 'calendar_date': month.strftime('%Y-%m-%d'), 'balance': float(round(df_year_balance['new_balance'].sum(), 2)), 'capital_gain': float(round(df_year_balance['new_balance'].sum() - df_year_balance['allocated_balance'].sum(), 2))})
            # if set_num == 2:
            #     print(df_year_balance)
            if method == 'monthly rebalance' or method == 'bimonthly rebalance' and month.strftime('%m') in ['02', '04', '06', '08', '10', '12'] or method == 'quarterly rebalance' and month.strftime('%m') in ['03', '06', '09', '12'] or method == 'quarterly rebalance (-1)' and month.strftime('%m') in ['02', '05', '08', '11'] or method == 'quarterly rebalance (-2)' and month.strftime('%m') in ['01', '04', '07', '10'] or method == 'semi-annual rebalance' and month.strftime('%m') in ['06', '12']:
                df_year_balance.loc[:, 'allocated_balance'] = df_year_balance['allocation']*df_year_balance['asset_allocation']*(df_year_balance['new_balance'].sum())
            else:
                df_year_balance.loc[:, 'allocated_balance'] = df_year_balance['new_balance']
            month = utils.date_add(month, 1, 'month')
    return pd.DataFrame(results)


def update_dbt_models():
    dbt = dbtRunner()
    cli_args = ["seed", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt')]
    res: dbtRunnerResult = dbt.invoke(cli_args)
    cli_args = ["run", "--project-dir", str(SCRIPT_DIR / 'fdw_dbt'), "--select", "int_balance_allocations_yearly"]
    res: dbtRunnerResult = dbt.invoke(cli_args)


if __name__ == '__main__':
    print('--')
    update_dbt_models()
    print('-- Data')
    df_balance, df_performance= extract_data()
    df = None
    print('-- Simulation')
    for sn in range(7):
        # for sd in ['2022-01-01']:
        for sd in ['2022-01-01', '2023-01-01', '2024-01-01', '2025-01-01']:
            if df is None:
                df = simulate_set(sn+1, sd, df_balance, df_performance)
            else:
                df = pd.concat([df, simulate_set(sn+1, sd, df_balance, df_performance)])
    postgresql_lib.execute_query("TRUNCATE TABLE gold.allocation_simulations", code=True, mode='write', target_db='prod')
    postgresql_lib.insert_df(df, 'gold.allocation_simulations', merge=False, target_db='prod')
    print('Simulation DONE')
