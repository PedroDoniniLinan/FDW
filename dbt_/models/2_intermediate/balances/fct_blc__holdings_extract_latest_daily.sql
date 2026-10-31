{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with raw_extracts as (
    select
        extract_id,
        account,
        asset,
        calendar_date,
        units
    from {{ ref("stg_balances__extracts") }}
    where calendar_date = {{ get_latest_date(ref("stg_balances__extracts"), "calendar_date") }}
),

raw_asset_rounding as (
    select
        rounding_asset,
        round_num
    from {{ ref("int_com__asset_rounding") }}
),

rounded_extracts as (
    select
        l.extract_id,
        l.account,
        l.asset,
        l.calendar_date,
        round(
            l.units::numeric,
            r.round_num
        ) as units
    from raw_extracts as l
    left join raw_asset_rounding as r on (l.asset = r.rounding_asset)
),

final as (
    select
        extract_id,
        account,
        asset,
        calendar_date,
        units
    from rounded_extracts
)

select * from final
