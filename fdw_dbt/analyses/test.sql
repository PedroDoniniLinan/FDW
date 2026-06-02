select date_trunc('month', calendar_date) as calendar_date, count(1), count(distinct balance_id)
from {{ ref("int_balances__daily") }}
group by 1
order by 1 desc
;