select
    account,
    asset,
    calendar_date
from {{ ref("stg_balances__extracts") }}
where units < 0 
    and account not in ('Nubank C')