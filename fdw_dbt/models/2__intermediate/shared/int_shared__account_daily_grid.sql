{{ config(
    materialized='table',
    tags=['refactored', 'balance_validation', 'main']
) }}

with

transaction_assets as (
    select distinct
        account,
        asset
    from {{ ref("int_transactions__all") }}
)

select
    t.account,
    t.asset,
    g.calendar_date,
    g.is_end_of_period
from {{ ref("int_shared__daily_grid") }} as g
cross join transaction_assets as t
