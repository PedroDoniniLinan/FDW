"""Project monthly amounts from model.py. No Excel, no Google.

project_category() returns the monthly list for one category. project() returns every modelled category.
Output rows are consumed by generate.py.
"""
import datetime as dt
import math

from projection_rules.components import EVALUATORS, gate_open, value
from projection_rules.model import BASE, MODEL, derive


def share_of(spec, n, params, series):
    """-(sum of sibling series) / divisor, only in months where every gate is open."""
    divisor = value(spec['divisor'], params)
    out = [0.0] * n
    for k in range(n):
        if any(not gate_open(g, k, params) for g in spec.get('gates', [])):
            continue
        base = sum(series[name][k] for name in spec['of'])
        out[k] = -base / divisor
    return out

FIRST_MONTH = dt.date(2024, 1, 1)


def build_params(overrides=None):
    params = dict(BASE)
    params.update(overrides or {})
    return derive(params)


def scenario_id(params):
    """simulation_set derived from the inputs, the same digits the sheet's CONCATENATE builds:
    house year, downpayment in thousands ('00' if under 1000), house years, land year, retirement year,
    car 27 flag (1 if the car is bought in 2027), and the unique tag (blank here)."""
    downpayment_k = math.floor(params['downpayment'] / 1000)
    parts = [
        f"{int(params['house_year']) - 2000:02d}",
        '00' if downpayment_k == 0 else str(downpayment_k),
        str(int(params['house_years'])),
        f"{int(params['land_year']) - 2000:02d}",
        f"{int(params['retirement_year']) - 2000:02d}",
        str(int(params['car_year'] == 2027)),
        '',
    ]
    return int(''.join(parts))


def months_between(end_date):
    n = (end_date.year - FIRST_MONTH.year) * 12 + (end_date.month - FIRST_MONTH.month) + 1
    if n < 1:
        raise ValueError(f'end_date {end_date} is before {FIRST_MONTH}')
    return n


def month_date(k):
    """Date of month index k (0 = 2024-01)."""
    return dt.date(FIRST_MONTH.year + k // 12, k % 12 + 1, 1)


def project_leaf(leaf, n, params):
    return EVALUATORS[leaf['type']](leaf, n, params)


def project_category(category, n, params):
    """Sum of all leaves of one category, one value per month.

    'share_of' leaves are computed after the others, because they take a share of named sibling leaves.
    """
    series = {}
    for leaf in MODEL[category]:
        if leaf['type'] != 'share_of':
            series[leaf['name']] = project_leaf(leaf, n, params)
    for leaf in MODEL[category]:
        if leaf['type'] == 'share_of':
            series[leaf['name']] = share_of(leaf, n, params, series)
    total = [0.0] * n
    for leaf in MODEL[category]:
        total = [a + b for a, b in zip(total, series[leaf['name']])]
    return total


def project(n, params):
    """{category: [monthly amounts]} for every modelled category."""
    return {cat: project_category(cat, n, params) for cat in MODEL}
