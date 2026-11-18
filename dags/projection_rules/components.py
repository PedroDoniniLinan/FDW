"""Evaluators for the component types used in model.py.

Timeline: month index k = 0 is 2024-01 (the first row of the sheet). Each evaluator returns a list of
monthly amounts for k = 0 .. n-1.

Value syntax (anywhere an amount or a month is written in model.py)
- a number                    -> that number
- '$name'                     -> the input `name` (a number, a 'YYYY-MM' string, or a year)
- '$name*2', '-$name', '$name/12', '2*$name' -> simple arithmetic on inputs
- 'YYYY-MM' or 'YYYY'         -> a month (YYYY alone means January)

Kids
- A child's age is counted in whole years from the birth month. Each child is born in `kid_birth_month`
  (August), so an age-N birthday falls in the same month every year.
- Stage ages, growth points and stop ages for kids are in years.
"""
import re

FIRST_YEAR = 2024
_NAME = re.compile(r'\$([a-zA-Z_][a-zA-Z0-9_]*)')


def value(expr, params):
    """Evaluate a number or simple expression with '$name' inputs. Returns a float."""
    if not isinstance(expr, str):
        return float(expr)

    def sub(m):
        v = params[m.group(1)]
        if isinstance(v, str):
            raise ValueError(f'{m.group(0)} is a month, not a number')
        return repr(float(v))
    text = _NAME.sub(sub, expr)
    if not re.fullmatch(r'[0-9eE+\-*/(). ]+', text):
        raise ValueError(f'cannot evaluate {expr!r}')
    return float(eval(text, {'__builtins__': {}}, {}))   # local config only; see model.py


def month_index(text, params):
    """Month index of 'YYYY-MM', 'YYYY' (January), or '$name' holding either."""
    if isinstance(text, str) and text.startswith('$'):
        text = params[text[1:]]
    if isinstance(text, (int, float)):
        text = str(int(text))
    parts = str(text).split('-')
    year = int(parts[0])
    if year < 100:                       # two-digit year as the sheet writes it
        year += 2000
    month = int(parts[1]) if len(parts) > 1 else 1
    return (year - FIRST_YEAR) * 12 + (month - 1)


def calendar_month(k):
    return k % 12 + 1


def growth_factor(k, rate, first, every, params):
    """(1+rate)^n where n counts growth points first, first+every, ... that are <= k."""
    if k < first:
        return 1.0
    steps = (k - first) // every + 1
    return (1.0 + params[rate]) ** steps


def gate_open(gate, k, params):
    """Named on/off rules."""
    if gate == 'working':
        # open until the end of the retirement year
        return k < month_index(f"{int(params['retirement_year']) + 1}-01", params)
    if gate == 'through_house_year':
        return k < month_index(f"{int(params['house_year']) + 1}-01", params)
    if gate == 'after_house_year':
        return k >= month_index(f"{int(params['house_year']) + 1}-01", params)
    if gate == 'house_by_deadline':
        # a house is bought in or before the deadline year (no liquidation, the move cost applies)
        return params['house_year'] <= params['house_deadline_year']
    if gate == 'no_house_by_deadline':
        # no house by the deadline year: the 3rd move cost applies instead of the house move
        return params['house_year'] > params['house_deadline_year']
    if gate == 'downpayment_over_threshold':
        return params['downpayment'] > params['liquidation_min_downpayment']
    if gate == 'car_owned':
        return params['car_purchase'] is not None and k >= month_index(params['car_purchase'], params)
    raise KeyError(f'unknown gate {gate!r}')


def child_factor(spec, k, params):
    """Multiplier from children present, by the child's age in years.
    Before birth: 1. Under `under_age` years: `under`. From `under_age` to `until_age`: `over`.
    From `until_age` on (the kid's costs have stopped): 1."""
    f = 1.0
    for child in spec['children']:
        if params[child + '_birth'] is None:
            continue
        age_years = (k - month_index(params[child + '_birth'], params)) // 12
        if age_years < 0:
            continue
        until = value(spec['until_age'], params)
        if age_years >= until:
            continue
        f *= value(spec['under'], params) if age_years < spec['under_age'] else value(spec['over'], params)
    return f


def leave_share(k, params):
    """Share of pay on maternity leave in month k (larger of the children's shares)."""
    from projection_rules.model import LEAVE_PROFILE
    share = 0.0
    for child in ('child',):
        if params[child + '_birth'] is None:
            continue
        birth = month_index(params[child + '_birth'], params)
        off = k - birth
        current = 0.0
        for start, s in LEAVE_PROFILE:
            if off >= start:
                current = s
        share = max(share, current)
    return share


def _scale(rules, k, params):
    factor = 1.0
    for rule in rules:
        if k >= month_index(rule['from'], params):
            factor *= value(rule['factor'], params)
    return factor


def recurring(spec, n, params):
    start = month_index(spec['start'], params)
    end = month_index(spec['end'], params) if spec.get('end') else None
    every = spec.get('every', 1)
    months = spec.get('months')
    amount = value(spec['amount'], params)
    growth = spec.get('growth')
    out = [0.0] * n
    for k in range(n):
        if k < start or (end is not None and k >= end):
            continue
        if (k - start) % every:
            continue
        if months and calendar_month(k) not in months:
            continue
        if any(not gate_open(g, k, params) for g in spec.get('gates', [])):
            continue
        v = amount
        if growth:
            first = month_index(growth['from'], params) if growth.get('from') else start + growth['every']
            v *= growth_factor(k, growth['rate'], first, growth['every'], params)
        v *= _scale(spec.get('scale', []), k, params)
        if spec.get('leave'):
            v *= 1.0 - leave_share(k, params)
        if spec.get('child_factor'):
            v *= child_factor(spec['child_factor'], k, params)
        out[k] = v
    return out


def car(spec, n, params):
    """A car: downpayment in the purchase month, then `monthly` for `months` months. Off if no car."""
    out = [0.0] * n
    if params['car_purchase'] is None:
        return out
    k0 = month_index(params['car_purchase'], params)
    if 0 <= k0 < n:
        out[k0] += value(spec['downpayment'], params)
    for k in range(k0 + 1, min(n, k0 + 1 + spec.get('months', 0))):
        out[k] += value(spec['monthly'], params)
    return out


def events(spec, n, params):
    out = [0.0] * n
    for when, amount in spec['events']:
        k = month_index(when, params)
        if 0 <= k < n:
            out[k] += value(amount, params)
    return out


def _one_child_stages(child, spec, n, params):
    if params[child + '_birth'] is None:
        return [0.0] * n
    birth = month_index(params[child + '_birth'], params)     # the kid's birth month (August)
    rate = params[spec['rate']] if spec.get('rate') else 0.0
    stages = sorted(spec['stages'], key=lambda s: s['age'])
    until = value(spec['until_age'], params) if 'until_age' in spec else None
    yearly = spec.get('payment') == 'yearly'
    every = spec.get('payment_every_years', 1)                  # payments every N years (yearly kids only)
    out = [0.0] * n
    for k in range(n):
        months = k - birth
        if months < 0:
            continue
        age = months // 12                                      # whole years since birth
        if until is not None and age >= until:
            continue
        if yearly and months % 12:                              # yearly costs fall in the birth month
            continue
        stage_index = None
        for i, s in enumerate(stages):
            if age >= s['age']:
                stage_index = i
        if stage_index is None:
            continue
        s = stages[stage_index]
        if yearly and (age - s['age']) % every:                # counted from the stage's own start
            continue
        next_age = stages[stage_index + 1]['age'] if stage_index + 1 < len(stages) else 10**9
        steps = 0
        if 'grow_from' in s and s.get('grow_every'):
            p = s['grow_from']
            while p <= age and p < next_age:
                steps += 1
                p += s['grow_every']
        out[k] = value(s['amount'], params) * (1.0 + rate) ** steps
    return out


def child_stages(spec, n, params):
    """Costs by the child's age in years. Each stage has an amount and its own growth points.

    stage = {'age': years, 'amount': x, 'grow_from': years, 'grow_every': years}
    - Growth points within a stage multiply the stage amount by (1+rate) each time. Amounts do not carry
      across stages.
    - payment 'monthly' (default) pays every month. payment 'yearly' pays once a year in the kid's birth
      month; `payment_every_years` = 2 pays every second year, counted from the stage start.
    - `until_age` (years) stops the cost for good.
    `child` may be a list: the cost is then the largest of the children's amounts in each month, as in
    the sheet's MAX(...) formulas (one cost per household, not one per child).
    """
    children = spec['child'] if isinstance(spec['child'], list) else [spec['child']]
    series = [_one_child_stages(c, spec, n, params) for c in children]
    return [max(vals) for vals in zip(*series)]


def child_events(spec, n, params):
    """Costs tied to the child's birth. Each item is (from_offset, to_offset, amount): inclusive month
    offsets from the birth month (negative = before birth)."""
    if params[spec['child'] + '_birth'] is None:
        return [0.0] * n
    birth = month_index(params[spec['child'] + '_birth'], params)
    out = [0.0] * n
    for lo, hi, amount in spec['items']:
        for off in range(lo, hi + 1):
            k = birth + off
            if 0 <= k < n:
                out[k] += value(amount, params)
    return out


EVALUATORS = {
    'recurring': recurring,
    'events': events,
    'child_stages': child_stages,
    'child_events': child_events,
    'car': car,
}
