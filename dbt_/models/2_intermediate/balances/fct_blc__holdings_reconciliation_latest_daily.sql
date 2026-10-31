{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with

last_extract as (
    select
        extract_id,
        account,
        asset,
        calendar_date,
        units
    from {{ ref("fct_blc__holdings_extract_latest_daily") }}
),

current_holdings as (
    select
        account,
        asset,
        calendar_date,
        units
    from {{ ref("fct_blc__holdings_unfiltered_daily") }}
    where calendar_date = {{ get_latest_date(src_calculated, "calendar_date") }}
),

reconciliation as (
    select
        cb.extract_id,
        coalesce(cb.account, ab.account) as account,
        coalesce(cb.asset, ab.asset) as asset,
        coalesce(cb.calendar_date, ab.calendar_date) as calendar_date,
        coalesce(cb.units, 0) as units_actual,
        coalesce(ab.units, 0) as units_calculated,
        (coalesce(ab.units, 0) - coalesce(cb.units, 0)) as delta
    from last_extract as cb
    left join current_holdings as ab
        on (
            cb.account = ab.account
            and cb.asset = ab.asset
        )
    where (coalesce(ab.units, 0) - coalesce(cb.units, 0)) != 0
),

final as (
    select
        extract_id,
        account,
        asset,
        calendar_date,
        units_actual,
        units_calculated,
        delta
    from reconciliation
)

select * from final
