{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

select 
    t.account, 
    t.asset, 
    g.calendar_date,
    g.is_end_of_period
from {{ ref("int_shared__daily_grid") }} g
    cross join (
        select distinct 
            account, 
            asset 
        from {{ ref("int_transactions__all") }}
    ) t