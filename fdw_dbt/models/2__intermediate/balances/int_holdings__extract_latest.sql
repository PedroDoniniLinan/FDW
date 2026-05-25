{{
  config(
    materialized = 'view',
    )
}}

{% set src = ref("stg_balances__extracts") %}

select
    l.account,
    l.asset,
    l.calendar_date,
    round(
        l.units::numeric,
        r.round_num
    ) as units
from {{ src }} l
    left join {{ ref('int_shared__asset_rounding') }} r on (r.rounding_asset = l.asset)
where calendar_date = {{ latest_date(src, "calendar_date") }}