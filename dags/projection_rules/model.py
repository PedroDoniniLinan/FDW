"""Projection model: every component of every category, as plain data.

Edit this file to change a pattern or a value. Nothing here uses Excel.

Conventions
- Months are 'YYYY-MM'. A window is start (inclusive) to end (exclusive); end None means open-ended.
- '$name' refers to an input in BASE (or a scenario override). '$name*2' multiplies by a number.
- Growth: `growth.rate` is the inflation input; the amount is multiplied once per growth point,
  first growth point at `growth.from` (default: start + `every`), then every `growth.every` months.
- Kids: ages are whole years since birth. Every kid is born in `kid_birth_month` (August), and yearly
  kid costs are paid in that month. Stage ages, growth points and `until_age` are in years.
  Kid costs stop at `kid_stop_age` (22).
- Gates: 'working' = until the retirement year; 'through_house_year' = up to and including the house year;
  'house_by_deadline' / 'no_house_by_deadline' = house bought by / not bought by `house_deadline_year`.
- `scale`: multiply by a factor from a given month (for example the IRS change from 2033-08).
- `leave`: share of pay lost to a child's birth leave (profile in LEAVE_PROFILE).

Category keys are (transaction_type, budget_level, level_2), as used in bronze.projections_generated.

Derived values (rent switch-over, rent 3 amount, IRS factor, kid birth months) are in derive(), below.
"""

import math

# ---------------------------------------------------------------------------
# Inputs. Scenario files override these by name.
# ---------------------------------------------------------------------------
BASE = {
    # rates
    'salary_inflation': 0.02,
    'rent_inflation': 0.03,
    'expense_inflation': 0.03,
    'ir_inflation': 0.12,
    'irs_change': 1 - 0.51 / 0.69,          # share of salary lost after the IRS change
    # child: birth year, or None if there is no child. The child is born in kid_birth_month of that year.
    'child_birth_year': 2029,
    'kid_birth_month': 8,                    # August: every yearly kid cost is paid in this month
    'kid_stop_age': 22,                      # kid costs stop at this age (years)
    # salary and work
    'salary_1': 3000, 'salary_2': 2835, 'salary_3': 7200 / 1.15,
    'salary_4': 7200 / 1.15 * (1 - 0.214 * 0.7),
    'teaching': 800,
    'retirement_year': 2062,                 # last working year
    # housing
    'rent_1': 1000, 'rent_2': 900, 'rent_3': 1050,
    'utilities': 180,
    'house_year': 2027,
    'house_deadline_year': 2027,             # no house by this year: the 3rd move cost replaces the house move
    'move_3': 800,                           # 3rd move (used instead of the house move, see above)
    'liquidation_min_downpayment': 70000,    # house liquidation applies only above this downpayment
    'house_value': 729697,                   # house price used for the years of payments
    'downpayment': 63000,
    'monthly_payment': 1388,
    'land_year': 2029,
    'land_value': 300000 / 7,
    'fgts': 50000 / 7 + 3300,                # received July 2026
    # car: purchase year (bought in January), or None if there is no car
    'car_year': 2028,
    'car_downpayment': 18000, 'car_monthly': 0, 'car_monthly_months': 11,
    'car_adjustment': 2,                    # transport cost is divided by this when a car is owned
    # travel
    'trip_br': 1600, 'trip_ru': 2000,       # one-off trips
    'trip_1y': 1200, 'trip_2y': 750, 'trip_4y': 750, 'trip_8y': 3250,
    # transport and fuel
    'transport': 70, 'kid_transport': 5, 'fuel': 180,
    # self care
    'pharmacy': 50, 'gym': 60, 'self_care_free_d': 50, 'self_care_free_p': 0,
    'self_care_kid': 20, 'self_care_kid_high': 100,
}

# Scenarios: each is a sparse dict of BASE names -> values that differ from BASE.
# The key is the simulation_set id the scenario produces (derived from the inputs, see projector.scenario_id).
# These are the 12 sets in bronze.projections (prod).
SCENARIOS = {
    '32634029620': {'house_value': 729697.0, 'house_year': 2032},
    '27004032361': {'car_year': 2027, 'downpayment': 0.0, 'expense_inflation': 0.02, 'house_value': 625991.0, 'ir_inflation': 0.1, 'land_year': 2032, 'monthly_payment': 1304.0, 'rent_inflation': 0.0216, 'retirement_year': 2036, 'salary_inflation': 0.025},
    '27004032381': {'car_year': 2027, 'downpayment': 0.0, 'expense_inflation': 0.02, 'house_value': 625991.0, 'ir_inflation': 0.1, 'land_year': 2032, 'monthly_payment': 1304.0, 'rent_inflation': 0.0216, 'retirement_year': 2038, 'salary_inflation': 0.025},
    '27004029560': {'downpayment': 0.0, 'house_value': 625991.0, 'monthly_payment': 1304.0, 'retirement_year': 2056},
    '27004029600': {'downpayment': 0.0, 'house_value': 625991.0, 'monthly_payment': 1304.0, 'retirement_year': 2060},
    '27534032381': {'car_year': 2027, 'downpayment': 53000.0, 'expense_inflation': 0.02, 'house_value': 581064.0, 'ir_inflation': 0.1, 'land_year': 2032, 'monthly_payment': 1100.0, 'rent_inflation': 0.0216, 'retirement_year': 2038, 'salary_inflation': 0.025},
    '27534032401': {'car_year': 2027, 'downpayment': 53000.0, 'expense_inflation': 0.02, 'house_value': 581064.0, 'ir_inflation': 0.1, 'land_year': 2032, 'monthly_payment': 1100.0, 'rent_inflation': 0.0216, 'retirement_year': 2040, 'salary_inflation': 0.025},
    '27534029580': {'downpayment': 53000.0, 'house_value': 581064.0, 'monthly_payment': 1100.0, 'retirement_year': 2058},
    '27534029620': {'downpayment': 53000.0, 'house_value': 581064.0, 'monthly_payment': 1100.0},
    '32634035381': {'car_year': 2027, 'expense_inflation': 0.02, 'house_value': 729697.0, 'house_year': 2032, 'ir_inflation': 0.1, 'land_year': 2035, 'rent_inflation': 0.0216, 'retirement_year': 2038, 'salary_inflation': 0.025},
    '32634035401': {'car_year': 2027, 'expense_inflation': 0.02, 'house_value': 729697.0, 'house_year': 2032, 'ir_inflation': 0.1, 'land_year': 2035, 'rent_inflation': 0.0216, 'retirement_year': 2040, 'salary_inflation': 0.025},
    '32634029580': {'house_value': 729697.0, 'house_year': 2032, 'retirement_year': 2058},
}

# ---------------------------------------------------------------------------
# Leave profile: share of pay on leave by months from the child's birth. Last value holds.
# Full leave from 8 months before birth to 17 months after, then a taper to zero.
# ---------------------------------------------------------------------------
LEAVE_PROFILE = [
    (-8, 1.0), (18, 0.95), (19, 0.875), (20, 0.8), (21, 0.725), (22, 0.65), (23, 0.575),
    (24, 0.5), (25, 0.425), (26, 0.35), (27, 0.275), (28, 0.2), (29, 0.15), (30, 0.075), (31, 0.0),
]

# ---------------------------------------------------------------------------
# Components by category. Each leaf has a name and a type (see components.py).
# ---------------------------------------------------------------------------
MODEL = {
    ('Income', 'Work', 'Salary'): [
        {'name': 'salary_1', 'type': 'recurring', 'amount': '$salary_1',
         'start': '2024-01', 'end': '2025-01'},
        {'name': 'salary_2', 'type': 'recurring', 'amount': '$salary_2',
         'start': '2025-01', 'end': '2026-05', 'gates': ['working'],
         'growth': {'rate': 'salary_inflation', 'from': '2029-10', 'every': 24},
         'scale': [{'from': '2033-08', 'factor': '$irs_factor'}]},
        # June and November bonus (the "atd" step): same amount as salary 2, paid twice a year in 2025
        {'name': 'salary_2_atd', 'type': 'recurring', 'amount': '$salary_2',
         'start': '2025-01', 'end': '2026-05', 'months': [6, 11], 'gates': ['working']},
        {'name': 'salary_3', 'type': 'recurring', 'amount': '$salary_3',
         'start': '2026-05', 'end': '2027-05', 'gates': ['working']},
        {'name': 'salary_4', 'type': 'recurring', 'amount': '$salary_4',
         'start': '2027-05', 'end': None, 'gates': ['working'],
         'growth': {'rate': 'salary_inflation', 'from': '2029-10', 'every': 24},
         'scale': [{'from': '2033-08', 'factor': '$irs_factor'}]},
    ],
    ('Income', 'Work', 'Teaching'): [
        # quarterly (Mar, Jun, Sep, Dec) from 2024-03, reduced by maternity leave of child 28
        {'name': 'teaching', 'type': 'recurring', 'amount': '$teaching',
         'start': '2024-03', 'every': 3, 'gates': ['working'], 'leave': ['child'],
         'growth': {'rate': 'salary_inflation', 'from': '2029-10', 'every': 24}},
    ],
    ('Income', 'Other', 'Other'): [
        {'name': 'fgts', 'type': 'events', 'events': [('2026-07', '$fgts')]},
        # land sale: paid evenly over the land year, +1% a year from 2028
        {'name': 'land_sale', 'type': 'recurring', 'amount': '$land_value/12',
         'start': '$land_year', 'end': '$land_year_end',
         'growth': {'rate': 'land_growth', 'from': '2028-01', 'every': 12}},
    ],
    ('Expenses', 'Shared', 'Domestic Goods & Services'): [
        # Dec maintenance, 500 while living before the house year, 1000 after it
        {'name': 'maintenance', 'type': 'recurring', 'amount': 500, 'start': '2024-12', 'months': [12],
         'gates': ['through_house_year'],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'maintenance_house', 'type': 'recurring', 'amount': 1000, 'start': '2024-12', 'months': [12],
         'gates': ['after_house_year'],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'moves', 'type': 'events', 'events': [('2024-02', 3000), ('2026-02', 2000)]},
        # house move, paid in April of the house year, when a house is bought by the deadline year
        {'name': 'move_house', 'type': 'recurring', 'amount': 2500, 'start': '$house_year', 'end': '$house_year_end',
         'months': [4], 'gates': ['house_by_deadline']},
        # no house by the deadline year: the 3rd move cost is paid in April of the house year instead
        {'name': 'move_3', 'type': 'recurring', 'amount': '$move_3', 'start': '$house_year', 'end': '$house_year_end',
         'months': [4], 'gates': ['no_house_by_deadline']},
    ],
    ('Expenses', 'Shared', 'House'): [
        {'name': 'down_payment', 'type': 'recurring', 'amount': '$downpayment', 'start': '$house_year',
         'end': '$house_year_end', 'months': [4]},
        {'name': 'payments_house_year', 'type': 'recurring', 'amount': '$monthly_payment',
         'start': '$house_year', 'end': '$house_year_end', 'months': [5, 6, 7, 8, 9, 10, 11, 12]},
        {'name': 'payments_after', 'type': 'recurring', 'amount': '$monthly_payment',
         'start': '$house_year_end', 'end': '$house_payoff_year'},
    ],
    ('Expenses', 'Shared', 'Taxes & Fees'): [
        {'name': 'legal', 'type': 'recurring', 'amount': '840/5', 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'legal_high', 'type': 'recurring', 'amount': 840, 'start': '2024-01', 'every': 48,
         'growth': {'rate': 'ir_inflation', 'from': '2028-01', 'every': 48}},
        # house liquidation, paid in the purchase month (April of the house year), only with a downpayment
        # above liquidation_min_downpayment
        {'name': 'house_liquidation', 'type': 'recurring', 'amount': 8700, 'start': '$house_year',
         'end': '$house_year_end', 'months': [4], 'gates': ['downpayment_over_threshold']},
        {'name': 'trx_fees', 'type': 'recurring', 'amount': 200, 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'ir_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'trx_fees_high', 'type': 'recurring', 'amount': 600, 'start': '2025-01', 'every': 36,
         'growth': {'rate': 'ir_inflation', 'from': '2028-01', 'every': 36}},
        {'name': 'ir', 'type': 'recurring', 'amount': 50, 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'ir_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'ir_high_first', 'type': 'events', 'events': [('2024-01', 750)]},
        {'name': 'ir_high', 'type': 'recurring', 'amount': 300, 'start': '2025-01', 'every': 36,
         'growth': {'rate': 'ir_inflation', 'from': '2028-01', 'every': 36}},
        # yearly income-tax deduction on salary 3, paid in June while working
        {'name': 'irs_deduction', 'type': 'recurring', 'amount': '$salary_3*12*0.2*0.75*1.05',
         'start': '2027-06', 'every': 12, 'months': [6], 'gates': ['working'],
         'growth': {'rate': 'salary_inflation', 'from': '2029-10', 'every': 24}},
    ],
    ('Expenses', 'Shared', 'Health'): [
        {'name': 'avg_health', 'type': 'recurring', 'amount': 800, 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'high_health', 'type': 'recurring', 'amount': 3000, 'start': '2025-01', 'every': 24,
         'growth': {'rate': 'expense_inflation', 'from': '2027-01', 'every': 24}},
        {'name': 'pregnancy', 'type': 'child_events', 'child': 'child',
         'items': [(-11, -2, 500), (-1, -1, 5100)]},
        # kids, paid yearly in the birth month, stop at kid_stop_age. Stage ages in years.
        {'name': 'kid_base', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 0, 'amount': 500, 'grow_from': 2, 'grow_every': 2},
             {'age': 3, 'amount': 300, 'grow_from': 5, 'grow_every': 2},
             {'age': 11, 'amount': 300, 'grow_from': 13, 'grow_every': 2}]},
        {'name': 'kid_high', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'payment_every_years': 2, 'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 0, 'amount': 1500, 'grow_from': 4, 'grow_every': 4}]},
    ],
    ('Expenses', 'Shared', 'Clothes'): [
        {'name': 'kid_clothes', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 0, 'amount': 600, 'grow_from': 1, 'grow_every': 1},
             {'age': 7, 'amount': 1000, 'grow_from': 8, 'grow_every': 1},
             {'age': 15, 'amount': 600, 'grow_from': 16, 'grow_every': 1},
             {'age': 19, 'amount': 500, 'grow_from': 20, 'grow_every': 1}]},
    ],
    ('Expenses', 'Free P', 'Clothes'): [
        {'name': 'clothes_avg', 'type': 'recurring', 'amount': 80, 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'clothes_high', 'type': 'recurring', 'amount': 100, 'start': '2024-01', 'every': 36,
         'growth': {'rate': 'expense_inflation', 'from': '2027-01', 'every': 36}},
    ],
    ('Expenses', 'Free D', 'Clothes'): [
        {'name': 'clothes_avg', 'type': 'recurring', 'amount': 400, 'start': '2024-01', 'months': [1],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        # two payments in every 3-year cycle (years 1 and 2)
        {'name': 'clothes_high_a', 'type': 'recurring', 'amount': 450, 'start': '2024-01', 'every': 36,
         'growth': {'rate': 'expense_inflation', 'from': '2027-01', 'every': 36}},
        {'name': 'clothes_high_b', 'type': 'recurring', 'amount': 450, 'start': '2025-01', 'every': 36,
         'growth': {'rate': 'expense_inflation', 'from': '2028-01', 'every': 36}},
    ],
    ('Expenses', 'Shared', 'Products & Services'): [
        {'name': 'prod_serv', 'type': 'recurring', 'amount': 70, 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'prod_serv_kid', 'type': 'child_stages', 'child': 'child',
         'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 0, 'amount': 30, 'grow_from': 2, 'grow_every': 2}]},
        {'name': 'gift_1y_a', 'type': 'recurring', 'amount': 100, 'start': '2024-10', 'every': 12,
         'growth': {'rate': 'expense_inflation', 'from': '2026-10', 'every': 24}},
        {'name': 'gift_1y_b', 'type': 'recurring', 'amount': 300, 'start': '2024-12', 'every': 12,
         'growth': {'rate': 'expense_inflation', 'from': '2026-12', 'every': 24}},
        {'name': 'gift_2y', 'type': 'recurring', 'amount': 200, 'start': '2025-12', 'every': 24,
         'growth': {'rate': 'expense_inflation', 'from': '2027-12', 'every': 24}},
        {'name': 'gift_3y', 'type': 'recurring', 'amount': 200, 'start': '2025-10', 'every': 36,
         'growth': {'rate': 'expense_inflation', 'from': '2028-10', 'every': 36}},
        # kid gifts, in the birth month, stop at kid_stop_age
        {'name': 'gift_k_1y', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 3, 'amount': 300, 'grow_from': 4, 'grow_every': 1}]},
        {'name': 'gift_k_2y', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'payment_every_years': 2, 'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 4, 'amount': 200, 'grow_from': 6, 'grow_every': 2}]},
        {'name': 'gift_k_4y', 'type': 'child_stages', 'child': 'child', 'payment': 'yearly',
         'payment_every_years': 4, 'rate': 'expense_inflation', 'until_age': '$kid_stop_age', 'stages': [
             {'age': 3, 'amount': 600, 'grow_from': 7, 'grow_every': 4}]},
    ],
    ('Expenses', 'Free P', 'Products & Services'): [
        {'name': 'prod_serv_p', 'type': 'recurring', 'amount': 30, 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'gift_5y_p', 'type': 'recurring', 'amount': 800, 'start': '2025-10', 'every': 60,
         'growth': {'rate': 'expense_inflation', 'from': '2030-10', 'every': 60}},
    ],
    ('Expenses', 'Free D', 'Products & Services'): [
        {'name': 'prod_serv_d', 'type': 'recurring', 'amount': 40, 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'gift_4y_d', 'type': 'recurring', 'amount': 800, 'start': '2025-06', 'every': 48,
         'growth': {'rate': 'expense_inflation', 'from': '2029-06', 'every': 48}},
    ],
    ('Expenses', 'Shared', 'Self-care'): [
        {'name': 'pharmacy', 'type': 'recurring', 'amount': '$pharmacy', 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'gym', 'type': 'recurring', 'amount': '$gym', 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'kid_self_care', 'type': 'child_stages', 'child': 'child', 'rate': 'expense_inflation',
         'until_age': '$kid_stop_age', 'stages': [{'age': 0, 'amount': '$self_care_kid', 'grow_from': 1, 'grow_every': 1}]},
        {'name': 'kid_self_care_high', 'type': 'child_stages', 'child': 'child', 'rate': 'expense_inflation',
         'payment': 'yearly', 'payment_every_years': 3, 'until_age': '$kid_stop_age',
         'stages': [{'age': 0, 'amount': '$self_care_kid_high', 'grow_from': 3, 'grow_every': 3}]},
    ],
    ('Expenses', 'Free D', 'Self-care'): [
        # December only, same growth pattern as the food December extra
        {'name': 'self_care_free_d', 'type': 'recurring', 'amount': '$self_care_free_d', 'start': '2024-12',
         'months': [12], 'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
    ],
    ('Expenses', 'Free P', 'Self-care'): [
        {'name': 'self_care_free_p', 'type': 'recurring', 'amount': '$self_care_free_p', 'start': '2024-12',
         'months': [12], 'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
    ],
    ('Expenses', 'Shared', 'Travel'): [
        {'name': 'one_off_br', 'type': 'events', 'events': [
            ('2024-03', '$trip_br'), ('2024-07', '$trip_br'), ('2025-03', '$trip_br'),
            ('2025-07', '$trip_br'), ('2026-02', '$trip_br')]},
        {'name': 'one_off_ru', 'type': 'events', 'events': [('2026-06', '$trip_ru')]},
        {'name': 'trip_1y', 'type': 'recurring', 'amount': '$trip_1y', 'start': '2024-09', 'every': 12,
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'trip_2y', 'type': 'recurring', 'amount': '$trip_2y', 'start': '2024-05', 'every': 24,
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        # 4-year and 8-year trips stop in 2058. Children under 5 stop them, children from 5
        # to kid_stop_age add a 1.5 factor, and after kid_stop_age the kid no longer counts
        {'name': 'trip_4y', 'type': 'recurring', 'amount': '$trip_4y', 'start': '2027-05', 'every': 48,
         'end': '2058-01', 'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24},
         'child_factor': {'children': ['child'], 'under_age': 5, 'under': 0,
                          'over': 1.5, 'until_age': '$kid_stop_age'}},
        {'name': 'trip_8y', 'type': 'recurring', 'amount': '$trip_8y', 'start': '2027-05', 'every': 96,
         'end': '2058-01', 'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24},
         'child_factor': {'children': ['child'], 'under_age': 5, 'under': 0,
                          'over': 1.5, 'until_age': '$kid_stop_age'}},
    ],
    ('Expenses', 'Shared', 'Transport'): [
        {'name': 'transport', 'type': 'recurring', 'amount': '$transport', 'start': '2024-01',
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'kid_transport', 'type': 'child_stages', 'child': 'child', 'until_age': '$kid_stop_age',
         'stages': [{'age': 0, 'amount': '$kid_transport'}]},
        # half of the transport cost is removed while a car is owned
        {'name': 'car_adjustment', 'type': 'share_of', 'of': ['transport', 'kid_transport'],
         'divisor': '$car_adjustment', 'gates': ['car_owned']},
        {'name': 'car', 'type': 'car',
         'downpayment': '$car_downpayment', 'monthly': '$car_monthly', 'months': 11},
        {'name': 'fuel', 'type': 'recurring', 'amount': '$fuel', 'start': '2027-01', 'gates': ['car_owned'],
         'growth': {'rate': 'expense_inflation', 'from': '2027-01', 'every': 24}},
    ],
    ('Expenses', 'Shared', 'Food'): [
        {'name': 'essential_food', 'type': 'recurring', 'amount': 630,
         'start': '2024-01', 'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'food_exceptions_december', 'type': 'recurring', 'amount': 300,
         'start': '2024-12', 'months': [12],
         'growth': {'rate': 'expense_inflation', 'from': '2026-01', 'every': 24}},
        {'name': 'kid_food', 'type': 'child_stages', 'child': 'child', 'rate': 'expense_inflation',
         'until_age': '$kid_stop_age', 'stages': [
             {'age': 0, 'amount': 125, 'grow_from': 2, 'grow_every': 1},
             {'age': 7, 'amount': 175, 'grow_from': 8, 'grow_every': 1},
             {'age': 11, 'amount': 225, 'grow_from': 12, 'grow_every': 1},
             {'age': 16, 'amount': 275, 'grow_from': 18, 'grow_every': 2}]},
    ],
    ('Expenses', 'Shared', 'Home'): [
        {'name': 'rent_1', 'type': 'recurring', 'amount': '$rent_1',
         'start': '2024-02', 'end': '2026-02',
         'growth': {'rate': 'rent_inflation', 'from': '2025-02', 'every': 12}},
        {'name': 'rent_2', 'type': 'recurring', 'amount': '$rent_2',
         'start': '2026-02', 'end': '$rent_2_end',
         'growth': {'rate': 'rent_inflation', 'from': '2027-02', 'every': 12}},
        {'name': 'rent_3', 'type': 'recurring', 'amount': '$rent_3_amount',
         'start': '2027-10', 'end': None, 'gates': ['through_house_year'],
         'growth': {'rate': 'rent_inflation', 'from': '2028-10', 'every': 12}},
        {'name': 'insurance_2024', 'type': 'events', 'events': [('2024-02', '$rent_1*2')]},
        {'name': 'insurance_2026', 'type': 'events', 'events': [('2026-01', 2800), ('2026-03', '-$rent_1')]},
        {'name': 'utilities', 'type': 'recurring', 'amount': '$utilities',
         'start': '2024-02', 'growth': {'rate': 'rent_inflation', 'from': '2026-02', 'every': 24}},
    ],
}


# Constant rows written once per simulation_set, outside the monthly projection.
# (category key, calendar_date, amount)
BASELINE = [
    (('Income', 'Work', 'Salary'), '2023-12-01', 0.0),
]


def derive(params):
    """Values computed from inputs. Returns a new dict (inputs are not changed)."""
    p = dict(params)
    p['irs_factor'] = 1 - p['irs_change']
    # the car is bought in January of car_year; no year means no car
    p['car_purchase'] = None if p['car_year'] is None else f"{int(p['car_year'])}-01"
    p['land_growth'] = 0.01
    deadline = p['house_deadline_year']
    # rent 2 stops in February 2027 if the house comes after the deadline; otherwise it runs to the house year
    p['rent_2_end'] = f"{deadline}-02" if p['house_year'] > deadline else f"{p['house_year'] + 1}-01"
    p['rent_3_amount'] = p['rent_3'] if p['house_year'] > deadline else 0
    p['land_year_end'] = p['land_year'] + 1
    p['house_year_end'] = p['house_year'] + 1
    # years of house payments, rounded down
    p['house_years'] = math.floor((p['house_value'] - p['downpayment']) / p['monthly_payment'] / 12)
    p['house_payoff_year'] = p['house_year'] + p['house_years']
    # the child is born in the same fixed month (kid_birth_month); no birth year means no child
    year = p['child_birth_year']
    p['child_birth'] = None if year is None else f"{int(year)}-{int(p['kid_birth_month']):02d}"
    return p
