{{ config(schema='silver', materialized='view') }}

select
    e.estimate_type as expense_estimate,
    e.amount as expected_expense,
    y.estimate_type as yield_estimate,
    y.yield as expected_yearly_yield,
    (1 + y.yield::numeric)^(1.0/12) - 1 as expected_monthly_yield,
    (1 + (1 + y.yield)^(1.0/12) - 1) / ((1 + y.yield)^(1.0/12) - 1) * e.amount as fire_balance
from {{ ref("int_expected_expenses") }} e
    cross join {{ ref("int_expected_yields") }} y


{# 
(x - e) * (1 + y) = x
x (1 - 1 - y) = -e -ey
x = (1 + y)/y * e

(1 + y) = (1 + m)^12
(1 + y)^1/12 - 1 = m
#}