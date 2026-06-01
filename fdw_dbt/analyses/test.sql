{%- set lookback_days = var('lookback_days_eop', 365) -%}

{# select max(calendar_date) - interval '{{ lookback_days }} days' from {{ ref("fct_balances_eop") }} #}
select max(calendar_date) - interval '121 days' from {{ ref("fct_balances_enriched") }}