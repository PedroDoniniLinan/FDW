{{ config(
    materialized='incremental',
    unique_key='fiat_transaction_id',
    incremental_strategy='merge',
    tags=['refactored', 'main', 'rated']
) }}
{# {{ config(
    materialized='table',
    tags=['refactored', 'main', 'rated']
) }} #}


{%- set lookback_days = var('lookback_days', 30) -%}

with 

    fiat_converted_transactions as (
        select
            fiat_transaction_id,
            transaction_id,
            calendar_date,
            transaction_type,
            transaction_description,
            account,
            category,
            asset,
            currency,
            units,
            exchange_rate,
            amount
        from {{ref("int_transactions__fiat_converted")}}
        {% if is_incremental() -%}
        where calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
        {% endif %}
    ),

    dod_gains_transactions as (
        select
            fiat_transaction_id,
            fiat_transaction_id as transaction_id,
            calendar_date,
            'Income' as transaction_type,
            asset||'/'||currency as transaction_description,
            account,
            asset as category,
            asset,
            currency,
            amount as units,
            1 as exchange_rate,
            amount
        from {{ref("int_transactions__dod_gains")}}
        {% if is_incremental() -%}
        where calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
        {% endif %}
    ),

    intraday_gains_transactions as (
        select
            fiat_transaction_id,
            fiat_transaction_id as transaction_id,
            calendar_date,
            'Income' as transaction_type,
            asset||'/'||currency||'/intra' as transaction_description,
            account,
            asset as category,
            asset,
            currency,
            amount as units,
            1 as exchange_rate,
            amount
        from {{ref("int_transactions__intraday_gains")}}
        {% if is_incremental() -%}
        where calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
        {% endif %}
    )

select * from fiat_converted_transactions
union all
select * from dod_gains_transactions
union all
select * from intraday_gains_transactions
