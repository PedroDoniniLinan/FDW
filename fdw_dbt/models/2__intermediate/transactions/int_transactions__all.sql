{{ config(schema='silver', materialized='view') }}

/*
    Unifies transactions from exchange, transfer and external sources
*/
with

    unioned_transactions as (
        select
            transaction_id,
            source_id,
            transaction_type,
            transaction_description,
            units,
            account,
            calendar_date,
            category,
            asset,
            count_to_balance
        from {{ ref("stg_transactions__exchanges") }}
        union all
        select * from {{ ref("stg_transactions__internal") }}
        union all
        select * from {{ ref("stg_transactions__external") }}
    )

select
    l.transaction_id,
    l.source_id,
    l.transaction_type,
    l.transaction_description,
    round(
        l.units::numeric,
        r.round_num
    ) as units,
    l.account,
    l.calendar_date,
    l.category,
    l.asset,
    l.count_to_balance
from unioned_transactions l
    left join {{ ref('int_shared__asset_rounding') }} r on (r.rounding_asset = l.asset)
