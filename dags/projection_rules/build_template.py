"""One-off extraction of the projections model from the Google Sheet into the repo.

Writes:
- template/option_manual_template.xlsx : the 'option 1v2' and 'manual - option 1v2' tabs as formulas
- seeds/scenarios.csv                  : every scenario column of 'option 1v2' (long format)
- seeds/categories.csv                 : the 20 monthly series and which manual column feeds each
- seeds/baseline_rows.csv              : the one constant 2023-12 row of the Salary series

Only reads the sheet. Re-run it if the sheet's formulas change.
"""
import csv
import datetime as dt
import re
from pathlib import Path

from openpyxl import Workbook
from openpyxl.utils import get_column_letter

from lib import google_lib
from lib.formula_engine import normalise_cell

SHEET_ID = '1Cr8Br53t1wU1EUNEkyKQhAan30iGFzPRbVBDj1veARo'
HERE = Path(__file__).resolve().parent
TEMPLATE_DIR = HERE / 'template'
SEED_DIR = HERE / 'seeds'
OPTION_TAB = 'option 1v2'
MANUAL_TAB = 'manual - option 1v2'
AUTO_TAB = 'auto_'
OPTION_LAST_ROW = 140
OPTION_FIRST_COL, OPTION_LAST_COL = 4, 73        # D..BU
MANUAL_LAST_ROW = 649                            # 2024-01 .. 2077-12 (648 months)
AUTO_LAST_ROW = 12962
_MANUAL_REF = re.compile(r"'manual - option 1v2'!\$?([A-Z]+)\$?(\d+)")


def _values(sheets, rng, render):
    return sheets.get(spreadsheetId=SHEET_ID, range=rng, valueRenderOption=render).execute().get('values', [])


def main():
    sheets = google_lib.create_service('sheets', google_lib.get_credentials()).spreadsheets().values()
    option = _values(sheets, f"'{OPTION_TAB}'!A1:BU{OPTION_LAST_ROW}", 'FORMULA')
    manual = _values(sheets, f"'{MANUAL_TAB}'!A1:GZ{MANUAL_LAST_ROW}", 'FORMULA')
    auto = _values(sheets, f"'{AUTO_TAB}'!A2:F{AUTO_LAST_ROW}", 'FORMULA')
    ids = _values(sheets, f"'{OPTION_TAB}'!D2:BU2", 'UNFORMATTED_VALUE')[0]

    TEMPLATE_DIR.mkdir(exist_ok=True)
    SEED_DIR.mkdir(exist_ok=True)

    # 1. template workbook: formulas only (compatibility rewrites applied)
    wb = Workbook()
    ws_opt = wb.active
    ws_opt.title = OPTION_TAB
    ws_man = wb.create_sheet(MANUAL_TAB)
    for tab, grid in ((ws_opt, option), (ws_man, manual)):
        for r, row in enumerate(grid, 1):
            for c, v in enumerate(row, 1):
                nv = normalise_cell(v)
                if nv is not None:
                    tab.cell(r, c, nv)
    wb.save(TEMPLATE_DIR / 'option_manual_template.xlsx')

    # 2. scenarios seed: every option column, long format
    with open(SEED_DIR / 'scenarios.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['scenario_column', 'simulation_set', 'row', 'label', 'value'])
        for c in range(OPTION_FIRST_COL, OPTION_LAST_COL + 1):
            col = get_column_letter(c)
            idx = c - OPTION_FIRST_COL
            sim_id = str(ids[idx]) if idx < len(ids) else ''
            if sim_id in ('', 'None'):
                continue                       # column has no scenario id (empty trailing columns)
            for r, row in enumerate(option, 1):
                v = row[c - 1] if c - 1 < len(row) else ''
                if v in ('', None):
                    continue
                label = row[2] if len(row) > 2 else ''
                w.writerow([col, sim_id, r, label, v])

    # 3. categories and baseline from the auto_ tab
    groups = {}
    for i, r in enumerate(auto, 2):
        amt = str(r[5]) if len(r) > 5 else ''
        m = _MANUAL_REF.search(amt)
        if m:
            key = (r[2], r[3], r[4], m.group(1))
            groups.setdefault(key, []).append((i, int(m.group(2))))
        else:
            # constant row: baseline
            baseline = (r[2], r[3], r[4], r[0], amt)
    cats = []
    for (typ, bud, l2, col), rows in groups.items():
        manual_rows = [mr for _, mr in rows]
        assert manual_rows == list(range(2, MANUAL_LAST_ROW + 1)), (typ, bud, l2, col)
        cats.append((typ, bud, l2, col))
    with open(SEED_DIR / 'categories.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['transaction_type', 'budget_level', 'level_2', 'manual_column'])
        w.writerows(cats)
    with open(SEED_DIR / 'baseline_rows.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['transaction_type', 'budget_level', 'level_2', 'calendar_date', 'amount'])
        serial = int(float(baseline[3]))
        date = dt.date(1899, 12, 30) + dt.timedelta(days=serial)
        w.writerow([baseline[0], baseline[1], baseline[2], date.isoformat(), float(baseline[4])])

    print(f'template ok; scenarios written; {len(cats)} categories; baseline {baseline[:3]} on {date}')


if __name__ == '__main__':
    main()
