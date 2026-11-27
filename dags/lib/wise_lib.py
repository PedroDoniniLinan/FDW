"""Wise ingestion into bronze.transactions (Phase 3, shadow mode).

Rows land with source = 'wise' and are NOT used by any dbt model. They are only
compared against source = 'sheets' (see migrations/phase3_wise/02_shadow_compare.sql).

Configuration (.env):
    WISE_API_TOKEN      personal API token (read-only)
    WISE_ACCOUNT_MAP    JSON mapping Wise profile id -> account name used in the
                        sheets, e.g. {"12345678": "Wise", "87654321": "Wise D"}

Caveat: for EU/UK profiles Wise requires strong customer authentication (SCA) on
the statement endpoints, and a plain personal token gets 403 there. If that
happens, use statement_csv_to_bronze() on a downloaded CSV statement instead.
"""
import json
import os
from datetime import date, datetime, timedelta, timezone

import pandas as pd
import requests
from dotenv import load_dotenv

BASE_URL = 'https://api.wise.com'
SOURCE = 'wise'
COLUMNS = [
    'source', 'account', 'external_id', 'date', 'description', 'amount', 'currency',
    'raw_category', 'transaction_type', 'count_to_balance', 'transfer_id',
]


class WiseClient:
    def __init__(self, token=None, session=None):
        load_dotenv()
        self.token = token or os.getenv('WISE_API_TOKEN')
        if not self.token:
            raise RuntimeError('WISE_API_TOKEN is not set')
        self.session = session or requests.Session()

    def _get(self, path, params=None):
        resp = self.session.get(
            BASE_URL + path,
            params=params,
            headers={'Authorization': f'Bearer {self.token}'},
            timeout=30,
        )
        if resp.status_code == 403:
            raise PermissionError(
                f'Wise returned 403 for {path}. EU/UK statements need SCA; use a CSV statement instead.'
            )
        resp.raise_for_status()
        return resp.json()

    def balances(self, profile_id):
        return self._get(f'/v4/profiles/{profile_id}/balances', {'types': 'STANDARD'})

    def statement(self, profile_id, balance_id, currency, start, end):
        return self._get(
            f'/v1/profiles/{profile_id}/balance-statements/{balance_id}/statement.json',
            {
                'currency': currency,
                'intervalStart': start.strftime('%Y-%m-%dT00:00:00.000Z'),
                'intervalEnd': end.strftime('%Y-%m-%dT23:59:59.999Z'),
                'type': 'COMPACT',
            },
        )


def account_map():
    load_dotenv()
    raw = os.getenv('WISE_ACCOUNT_MAP')
    if not raw:
        raise RuntimeError('WISE_ACCOUNT_MAP is not set')
    return json.loads(raw)


def _rows(account, currency, balance_id, transactions):
    for t in transactions:
        amount = float(t['amount']['value'])
        yield {
            'source': SOURCE,
            'account': account,
            # reference numbers are unique per balance, so prefix with the balance
            'external_id': f"{balance_id}:{t['referenceNumber']}",
            'date': datetime.fromisoformat(t['date'].replace('Z', '+00:00')).date(),
            'description': (t.get('details') or {}).get('description'),
            'amount': amount,
            'currency': currency,
            'raw_category': (t.get('details') or {}).get('type'),
            # Tentative: own-account transfers are not detected yet, so every
            # movement is Income or Expenses. Shadow comparison accounts for this.
            'transaction_type': 'Income' if amount >= 0 else 'Expenses',
            'count_to_balance': True,
            'transfer_id': None,
        }


def statement_to_bronze(account, currency, balance_id, statement):
    """Normalize one Wise statement.json payload to bronze.transactions rows."""
    df = pd.DataFrame(_rows(account, currency, balance_id, statement.get('transactions', [])), columns=COLUMNS)
    return df


def statement_csv_to_bronze(path, account):
    """Normalize a Wise "transaction history" CSV export (fallback when the API gives 403).

    One file covers every currency balance of the profile. Rules:
    - Only Status = COMPLETED rows. REFUNDED rows net to zero and are skipped.
    - IN: +Target amount (after fees), in the target currency, Income.
    - OUT: -(Source amount after fees + Source fee), in the source currency, Expenses
      (this includes payments to own accounts elsewhere; the sheets split those out as transfers).
    - NEUTRAL with different currencies (a conversion between own balances): two Transfer
      legs sharing a transfer_id. Same-currency NEUTRAL rows are skipped, they net to zero.
    The export ID is the external_id (suffixed _out/_in for the two legs of a conversion).
    """
    raw = pd.read_csv(path)
    raw = raw[raw['Status'] == 'COMPLETED']
    rows = []
    for _, r in raw.iterrows():
        day = pd.to_datetime(r['Finished on']).date()
        fee = 0.0 if pd.isna(r['Source fee amount']) else float(r['Source fee amount'])
        ref = r['Reference'] if pd.notna(r['Reference']) else None
        base = {
            'source': SOURCE, 'account': account, 'date': day, 'raw_category': r['Category'],
            'count_to_balance': True,
        }
        if r['Direction'] == 'IN':
            rows.append({**base, 'external_id': r['ID'], 'description': ref or r['Source name'],
                         'amount': float(r['Target amount (after fees)']), 'currency': r['Target currency'],
                         'transaction_type': 'Income', 'transfer_id': None})
        elif r['Direction'] == 'OUT':
            rows.append({**base, 'external_id': r['ID'], 'description': ref or r['Target name'],
                         'amount': -(float(r['Source amount (after fees)']) + fee), 'currency': r['Source currency'],
                         'transaction_type': 'Expenses', 'transfer_id': None})
        elif r['Source currency'] != r['Target currency']:
            desc = f"{r['Source currency']}->{r['Target currency']}"
            rows.append({**base, 'external_id': r['ID'] + '_out', 'description': desc,
                         'amount': -(float(r['Source amount (after fees)']) + fee), 'currency': r['Source currency'],
                         'transaction_type': 'Transfer', 'transfer_id': r['ID']})
            rows.append({**base, 'external_id': r['ID'] + '_in', 'description': desc,
                         'amount': float(r['Target amount (after fees)']), 'currency': r['Target currency'],
                         'transaction_type': 'Transfer', 'transfer_id': r['ID']})
    return pd.DataFrame(rows, columns=COLUMNS)


def fetch_all(client, start, end):
    """Fetch every standard balance of every mapped profile between start and end."""
    frames = []
    for profile_id, account in account_map().items():
        for bal in client.balances(profile_id):
            currency = bal['currency']
            stmt = client.statement(profile_id, bal['id'], currency, start, end)
            frames.append(statement_to_bronze(account, currency, bal['id'], stmt))
    frames = [f for f in frames if not f.empty]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame(columns=COLUMNS)


def load(df, target_db='dev'):
    """Upsert rows into bronze.transactions. Defaults to dev, shadow only."""
    from lib import postgresql_lib

    if df.empty:
        return 0
    # insert_df writes the string 'nan' as NULL, but would write None as the text 'None'.
    df = df.astype(object).where(df.notna(), float('nan'))
    # Rows are fully determined by the key, so an upsert is a safe refresh.
    postgresql_lib.insert_df(
        df, 'bronze.transactions', keys=['source', 'external_id'], merge=True, target_db=target_db
    )
    return len(df)


def run(days=90, target_db='dev'):
    end = datetime.now(timezone.utc).date()
    start = end - timedelta(days=days)
    return load(fetch_all(WiseClient(), start, end), target_db=target_db)


if __name__ == '__main__':
    print(f'loaded {run()} rows')
