"""Generate projected monthly transactions for one or more scenarios.

Run from dags/:
    python -m projection_rules.generate --sets 27004032361 --end-date 2077-12-01 --csv out.csv
    python -m projection_rules.generate --sets all --end-date 2077-12-01 --write --target dev

--write replaces each scenario's rows in bronze.projections_generated (delete, then insert).
Writing defaults to the dev database; prod needs --target prod.
"""
import argparse
import datetime as dt
import uuid
from pathlib import Path

import pandas as pd

from lib import postgresql_lib
from projection_rules import engine

TABLE = 'bronze.projections_generated'
CREATE_SQL = Path(__file__).resolve().parent.parent / 'queries' / 'table_creation' / 'create_projections_generated.sql'
NAMESPACE = uuid.UUID('12345678-1234-5678-1234-567812345678')   # same namespace as daily_update.py
KEY_COLUMNS = ['calendar_date', 'simulation_set', 'transaction_type', 'budget_level', 'level_2']


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


def build(simulation_sets, end_date):
    scenarios = engine.load_scenarios()
    categories = engine.load_categories()
    baseline = engine.load_baseline()
    frames = []
    for sim in simulation_sets:
        print(f'Projecting simulation_set {sim} to {end_date} ...', flush=True)
        rows = engine.project(sim, end_date, scenarios, categories, baseline)
        frames.append(pd.DataFrame(rows, columns=engine.OUTPUT_COLUMNS))
    df = pd.concat(frames, ignore_index=True)
    df['calendar_date'] = pd.to_datetime(df['calendar_date'])
    return generate_ids(df)


def write_db(df, simulation_sets, target):
    postgresql_lib.execute_query(str(CREATE_SQL), code=False, mode='write', target_db=target)
    for sim in simulation_sets:
        postgresql_lib.execute_query(
            f"DELETE FROM {TABLE} WHERE simulation_set = {int(sim)}",
            code=True, mode='write', target_db=target)
        part = df[df['simulation_set'] == int(sim)]
        postgresql_lib.insert_df(part, TABLE, merge=False, target_db=target)
        print(f'Wrote {len(part)} rows for simulation_set {sim} to {target}.{TABLE}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sets', required=True,
                        help="comma-separated simulation_set ids, or 'all' for every scenario in seeds/scenarios.csv")
    parser.add_argument('--end-date', default='2077-12-01', help='last month to project (YYYY-MM-DD)')
    parser.add_argument('--csv', help='write the result to this CSV file')
    parser.add_argument('--write', action='store_true', help=f'write to {TABLE}')
    parser.add_argument('--target', choices=['dev', 'prod'], default='dev')
    args = parser.parse_args()

    end_date = dt.date.fromisoformat(args.end_date)
    scenarios = engine.load_scenarios()
    if args.sets == 'all':
        sets = list(scenarios)
    else:
        sets = [s.strip() for s in args.sets.split(',') if s.strip()]
    unknown = [s for s in sets if s not in scenarios]
    if unknown:
        raise SystemExit(f'Unknown simulation_set(s): {unknown}')
    if engine.extended(end_date):
        print(f'WARNING: {end_date} is past 2077-12. Months after 2077-12 are extrapolated and are not '
              f'validated against the sheet.')

    df = build(sets, end_date)
    print(f'Built {len(df)} rows for {len(sets)} scenario(s).')
    if args.csv:
        df.to_csv(args.csv, index=False)
        print(f'Wrote CSV {args.csv}')
    if args.write:
        write_db(df, sets, args.target)
    if not args.csv and not args.write:
        print('Nothing written. Use --csv and/or --write.')


if __name__ == '__main__':
    main()
