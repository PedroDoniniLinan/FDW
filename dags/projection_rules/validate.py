"""Check the generator against the values pasted into the sheet's '_' tab.

Run from dags/:
    python -m projection_rules.validate

For every simulation_set in '_', the generator output for 2024-01..2077-12 must have the same
keys (date, type, budget, level_2) and the same amounts (abs diff < 1e-6).
"""
import collections
import datetime as dt

from lib import google_lib
from projection_rules import engine, generate

SHEET_ID = '1Cr8Br53t1wU1EUNEkyKQhAan30iGFzPRbVBDj1veARo'
PASTE_RANGE = "'_'!A2:F216650"
TOLERANCE = 1e-6


def _serial_key(value):
    return int(float(value))


def read_paste():
    sheets = google_lib.create_service('sheets', google_lib.get_credentials()).spreadsheets().values()
    rows = sheets.get(spreadsheetId=SHEET_ID, range=PASTE_RANGE,
                      valueRenderOption='UNFORMATTED_VALUE').execute().get('values', [])
    pasted = collections.defaultdict(dict)
    for r in rows:
        if len(r) < 6:
            continue
        key = (_serial_key(r[0]), r[2], r[3], r[4])
        pasted[str(r[1])][key] = float(r[5])
    return pasted


def main():
    pasted = read_paste()
    sets = sorted(pasted)
    print(f'Pasted sets in sheet: {len(sets)}')
    df = generate.build(sets, dt.date(2077, 12, 1))
    all_ok = True
    for sim in sets:
        part = df[df['simulation_set'] == int(sim)]
        got = {}
        for _, r in part.iterrows():
            serial = engine.excel_serial(r['calendar_date'].date())
            got[(serial, r['transaction_type'], r['budget_level'], r['level_2'])] = r['amount']
        exp = pasted[sim]
        missing = set(exp) - set(got)
        extra = set(got) - set(exp)
        worst = (0.0, None)
        bad = 0
        for key in set(exp) & set(got):
            diff = abs(exp[key] - got[key])
            if diff > worst[0]:
                worst = (diff, key)
            if diff > TOLERANCE:
                bad += 1
        ok = not missing and not extra and bad == 0
        all_ok &= ok
        print(f'{sim}: rows {len(got)} vs pasted {len(exp)} | missing {len(missing)} extra {len(extra)} '
              f'mismatched {bad} max_diff {worst[0]:.3g} {"OK" if ok else "FAIL"}')
    print('ALL OK' if all_ok else 'FAILURES FOUND')


if __name__ == '__main__':
    main()
