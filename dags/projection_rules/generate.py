"""Generate projected monthly transactions for the scenarios in model.SCENARIOS.

Run from dags/:
    python -m projection_rules.generate --sets all --end-date 2077-12-01 --csv out.csv
    python -m projection_rules.generate --sets all --write --target prod

--sets takes simulation_set ids (comma-separated), or 'all'.
--write truncates bronze.projections and inserts the full output. It requires --sets all.
Writing defaults to the dev database; prod needs --target prod. Nothing reads Google Sheets or Excel.
"""
import argparse
import datetime as dt
import uuid
from pathlib import Path

import pandas as pd

from lib import postgresql_lib
from projection_rules.model import BASELINE, MODEL, SCENARIOS
from projection_rules.projector import build_params, month_date, months_between, project, scenario_id

TABLE = 'bronze.projections'
CREATE_SQL = Path(__file__).resolve().parent.parent / 'queries' / 'table_creation' / 'create_projections.sql'
NAMESPACE = uuid.UUID('12345678-1234-5678-1234-567812345678')   # same namespace as daily_update.py
KEY_COLUMNS = ['calendar_date', 'simulation_set', 'transaction_type', 'budget_level', 'level_2']
OUTPUT_COLUMNS = ['calendar_date', 'simulation_set', 'transaction_type', 'budget_level', 'level_2', 'amount']
DEFAULT_END_DATE = dt.date(2077, 12, 1)


def generate_ids(df):
    """Deterministic uuid per row, the same scheme as daily_update.generate_ids."""
    df = df.sort_values(KEY_COLUMNS).copy()
    df['_row_num'] = df.groupby(KEY_COLUMNS).cumcount()

    def make_id(row):
        natural_key = '|'.join(str(row[c]) for c in KEY_COLUMNS) + f"|{row['_row_num']}"
        return str(uuid.uuid5(NAMESPACE, natural_key))

    df['id'] = df.apply(make_id, axis=1)
    df = df.drop(columns=['_row_num'])
    return df[['id'] + [c for c in df.columns if c != 'id']]


def rows_for(sim, end_date):
    """Output rows for one simulation_set: every modelled category for every month, plus baseline rows."""
    params = build_params(SCENARIOS[sim])
    if str(scenario_id(params)) != str(sim):
        raise SystemExit(f'SCENARIOS[{sim}] computes simulation_set {scenario_id(params)}')
    n = months_between(end_date)
    series = project(n, params)
    rows = []
    for cat, amounts in series.items():
        for k, amount in enumerate(amounts):
            rows.append({'calendar_date': month_date(k), 'simulation_set': int(sim),
                         'transaction_type': cat[0], 'budget_level': cat[1], 'level_2': cat[2],
                         'amount': float(amount)})
    for cat, date, amount in BASELINE:
        rows.append({'calendar_date': dt.date.fromisoformat(date), 'simulation_set': int(sim),
                     'transaction_type': cat[0], 'budget_level': cat[1], 'level_2': cat[2],
                     'amount': amount})
    return rows


def build(sims, end_date):
    frames = []
    for sim in sims:
        print(f'Projecting simulation_set {sim} to {end_date} ...', flush=True)
        frames.append(pd.DataFrame(rows_for(sim, end_date), columns=OUTPUT_COLUMNS))
    df = pd.concat(frames, ignore_index=True)
    df['calendar_date'] = pd.to_datetime(df['calendar_date'])
    return generate_ids(df)


def write_db(df, sims, target):
    """Replace the whole table with df. sims must be every scenario, or the other sets would be lost."""
    if sorted(str(s) for s in sims) != sorted(str(s) for s in SCENARIOS):
        raise SystemExit('write_db needs every scenario in model.SCENARIOS (a full overwrite)')
    postgresql_lib.execute_query(str(CREATE_SQL), code=False, mode='write', target_db=target)
    postgresql_lib.execute_query(f"TRUNCATE TABLE {TABLE}", code=True, mode='write', target_db=target)
    postgresql_lib.insert_df(df, TABLE, merge=False, target_db=target)
    print(f'Wrote {len(df)} rows for {len(sims)} simulation_set(s) to {target}.{TABLE} (table replaced)')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sets', default='all',
                        help="comma-separated simulation_set ids, or 'all'")
    parser.add_argument('--end-date', default=DEFAULT_END_DATE.isoformat(),
                        help='last month to project (YYYY-MM-DD)')
    parser.add_argument('--csv', help='write the result to this CSV file')
    parser.add_argument('--write', action='store_true', help=f'write to {TABLE}')
    parser.add_argument('--target', choices=['dev', 'prod'], default='dev')
    args = parser.parse_args()

    end_date = dt.date.fromisoformat(args.end_date)
    if args.sets == 'all':
        sims = sorted(SCENARIOS)
    else:
        sims = [s.strip() for s in args.sets.split(',') if s.strip()]
        unknown = [s for s in sims if s not in SCENARIOS]
        if unknown:
            raise SystemExit(f'Not in model.SCENARIOS: {", ".join(unknown)}')

    df = build(sims, end_date)
    print(f'Built {len(df)} rows for {len(sims)} scenario(s).')
    if args.csv:
        df.to_csv(args.csv, index=False)
        print(f'Wrote CSV {args.csv}')
    if args.write:
        write_db(df, sims, args.target)
    if not args.csv and not args.write:
        print('Nothing written. Use --csv and/or --write.')


if __name__ == '__main__':
    main()
