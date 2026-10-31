select date_trunc('month', calendar_date) as calendar_date, count(1), count(distinct balance_id)
from {{ ref("fct_blc__balances_daily") }}
group by 1
order by 1 desc
;
