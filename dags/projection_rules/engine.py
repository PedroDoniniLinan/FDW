"""Compute projected monthly transactions for one scenario from the sheet's own formulas.

The model is template/option_manual_template.xlsx (formulas only). For a scenario, the seed
values from seeds/scenarios.csv are written into the active input column ('option 1v2'!D). The
formulas are compiled to Python and evaluated by lib/formula_engine (no spreadsheet engine).

Horizon: the template covers 2024-01 .. 2077-12 (648 months). Later end dates copy the last
template row forward (formulas are translated, typed-in constants are repeated). Those months
are NOT validated against the sheet, because the sheet does not contain them.
"""
import csv
import datetime as dt
from functools import lru_cache
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.formula.translate import Translator

from lib.formula_engine import Book, XLError, normalise_cell

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / 'template' / 'option_manual_template.xlsx'
SEED_DIR = HERE / 'seeds'
OPTION_TAB = 'option 1v2'
MANUAL_TAB = 'manual - option 1v2'
INPUT_COL = 'D'
FIRST_MONTH = dt.date(2024, 1, 1)
TEMPLATE_LAST_ROW = 649
TEMPLATE_MONTHS = TEMPLATE_LAST_ROW - 1          # 648
OUTPUT_COLUMNS = ['calendar_date', 'simulation_set', 'transaction_type', 'budget_level', 'level_2', 'amount']
EXCEL_EPOCH = dt.date(1899, 12, 30)


def excel_serial(d):
    return (d - EXCEL_EPOCH).days


def serial_to_date(serial):
    return EXCEL_EPOCH + dt.timedelta(days=int(serial))


def months_between(end_date):
    """Number of monthly rows needed from 2024-01 through end_date's month."""
    n = (end_date.year - FIRST_MONTH.year) * 12 + (end_date.month - FIRST_MONTH.month) + 1
    if n < 1:
        raise ValueError(f'end_date {end_date} is before {FIRST_MONTH}')
    return n


def load_scenarios():
    """Return {simulation_set: (scenario_column, [(row, value), ...])}, first column wins for duplicates."""
    scenarios = {}
    with open(SEED_DIR / 'scenarios.csv', newline='', encoding='utf-8') as f:
        for rec in csv.DictReader(f):
            sim = rec['simulation_set']
            if sim not in scenarios:
                scenarios[sim] = (rec['scenario_column'], [])
            if scenarios[sim][0] == rec['scenario_column']:
                scenarios[sim][1].append((int(rec['row']), rec['value']))
    return scenarios


def load_categories():
    with open(SEED_DIR / 'categories.csv', newline='', encoding='utf-8') as f:
        return [(r['transaction_type'], r['budget_level'], r['level_2'], r['manual_column'])
                for r in csv.DictReader(f)]


def load_baseline():
    with open(SEED_DIR / 'baseline_rows.csv', newline='', encoding='utf-8') as f:
        return [(r['transaction_type'], r['budget_level'], r['level_2'],
                 dt.date.fromisoformat(r['calendar_date']), float(r['amount']))
                for r in csv.DictReader(f)]


@lru_cache(maxsize=1)
def _template_cells():
    """{sheet: {(col, row): raw}} read once from the template (formulas kept as text)."""
    wb = load_workbook(TEMPLATE)
    cells = {}
    for ws in wb.worksheets:
        d = {}
        for row in ws.iter_rows():
            for c in row:
                v = c.value
                if v is None or v == '':
                    continue
                if isinstance(v, int) and not isinstance(v, bool):
                    v = float(v)
                d[(c.column_letter, c.row)] = v
        cells[ws.title] = d
    return cells


@lru_cache(maxsize=8)
def _manual_cells(n_months):
    """Template manual tab extended to n_months rows (copies the last template row forward)."""
    base = _template_cells()[MANUAL_TAB]
    cells = dict(base)
    if n_months <= TEMPLATE_MONTHS:
        return cells
    last = TEMPLATE_LAST_ROW
    last_cols = sorted({c for (c, r) in base if r == last})
    for r in range(last + 1, last + 1 + (n_months - TEMPLATE_MONTHS)):
        k = r - 2                                  # month index, row 2 = 2024-01
        cells[('A', r)] = float(excel_serial(dt.date(FIRST_MONTH.year + k // 12,
                                                     FIRST_MONTH.month + k % 12, 1)))
        for col in last_cols:
            if col == 'A':
                continue
            src = base[(col, last)]
            if isinstance(src, str) and src.startswith('='):
                cells[(col, r)] = Translator(src, origin=f'{col}{last}').translate_formula(f'{col}{r}')
            else:
                cells[(col, r)] = src
    return cells


def _option_cells(source_col, entries):
    """'option 1v2' cells with the scenario written into the input column."""
    cells = {k: v for k, v in _template_cells()[OPTION_TAB].items() if k[0] != INPUT_COL}
    for row, raw in entries:
        if isinstance(raw, str) and raw.startswith('='):
            cells[(INPUT_COL, row)] = Translator(raw, origin=f'{source_col}{row}').translate_formula(f'{INPUT_COL}{row}')
        else:
            value = normalise_cell(raw)
            if value is not None:
                cells[(INPUT_COL, row)] = value
    return cells


def project(simulation_set, end_date, scenarios=None, categories=None, baseline=None):
    """Return a list of output dicts for one scenario from 2024-01 to end_date (plus baseline rows)."""
    scenarios = scenarios or load_scenarios()
    categories = categories or load_categories()
    baseline = baseline or load_baseline()
    if str(simulation_set) not in scenarios:
        raise KeyError(f'simulation_set {simulation_set} is not in seeds/scenarios.csv')
    source_col, entries = scenarios[str(simulation_set)]
    n_months = months_between(end_date)

    book = Book({OPTION_TAB: _option_cells(source_col, entries),
                 MANUAL_TAB: _manual_cells(n_months)})
    rows = []
    for k in range(n_months):
        r = k + 2
        date = serial_to_date(book.value(MANUAL_TAB, 'A', r))
        for typ, bud, l2, col in categories:
            amount = book.value(MANUAL_TAB, col, r)
            if isinstance(amount, XLError):
                raise ValueError(f'error {amount.code} at {col}{r} for set {simulation_set}')
            if not isinstance(amount, (int, float)) or isinstance(amount, bool):
                raise ValueError(f'non-numeric value {amount!r} at {col}{r} for set {simulation_set}')
            rows.append({'calendar_date': date, 'simulation_set': int(simulation_set),
                         'transaction_type': typ, 'budget_level': bud, 'level_2': l2,
                         'amount': float(amount)})
    for typ, bud, l2, date, amount in baseline:
        rows.append({'calendar_date': date, 'simulation_set': int(simulation_set),
                     'transaction_type': typ, 'budget_level': bud, 'level_2': l2, 'amount': amount})
    return rows


def extended(end_date):
    """True when end_date is beyond the months the sheet actually contains."""
    return months_between(end_date) > TEMPLATE_MONTHS
