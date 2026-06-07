{{ config(schema='silver', materialized='view') }}

/*
    Unifies transactions from exchange, transfer and external sources
*/

select
    transaction_id,
    transaction_type,
    tag,
    amount,
    account,
    calendar_date,
    subcategory,
    currency,
    count_to_balance
from {{ ref('src_exchange_transactions') }}
union all
select * from {{ ref('src_transfer_transactions') }}
union all
select * from {{ ref("src_external_transactions") }}

