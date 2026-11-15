select *
from {{ ref("agg_inv__yield_periods") }}
where currency = 'EUR'
{# and aggregation_level = 'budget_level_3' #}
and aggregation_level = 'Budget 3'
and budget_level_3 = 'Portfolio'
and time_grain = 'year'
{# and budget_level_2 = 'Bonds BR' #}
{# order by budget_level_3, calendar_date #}