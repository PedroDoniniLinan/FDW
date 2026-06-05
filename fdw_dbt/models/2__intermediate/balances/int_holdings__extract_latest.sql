{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

{% set src = ref("stg_balances__extracts") %}

select
    l.extract_id,
    l.account,
    l.asset,
    l.calendar_date,
    round(
        l.units::numeric,
        r.round_num
    ) as units
from {{ src }} as l
left join {{ ref('int_shared__asset_rounding') }} as r on (l.asset = r.rounding_asset)
where l.calendar_date = {{ get_latest_date(src, "calendar_date") }}
