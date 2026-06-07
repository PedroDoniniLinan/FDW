{{ config(schema='silver', materialized='view') }}

select 'Expected yields' as estimate_type, 0.09 as yield
union all
select 'Low estimate' as estimate_type, 0.05 as yield