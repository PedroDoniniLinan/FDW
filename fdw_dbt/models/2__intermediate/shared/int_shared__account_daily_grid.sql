select 
    t.account, 
    t.currency, 
    g.calendar_date,
    g.is_end_of_period
from {{ ref("int_shared__daily_grid") }} g
    cross join (
        select distinct 
            account, 
            currency 
        from {{ ref("int_transactions__united") }}
    ) t