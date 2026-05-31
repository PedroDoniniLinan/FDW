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
    ),

    dod_gains_transactions as (
        select
            transaction_id as fiat_transaction_id,
            transaction_id,
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
    ),

    intraday_gains_transactions as (
        select
            transaction_id as fiat_transaction_id,
            transaction_id,
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
    )

select * from fiat_converted_transactions
union all
select * from dod_gains_transactions
union all
select * from intraday_gains_transactions
