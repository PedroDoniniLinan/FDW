{{ config(schema='silver', materialized='view') }}

/*
    Unifies transactions from exchange, transfer and external sources
*/

select
    transaction_id,
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
select * from {{ ref("stg_transactions__transfers") }}
union all
select * from {{ ref("stg_transactions__transactions") }}

