{{ config(
    materialized='table',
    unique_key='id'
) }}

select 1 as id, 'a' as name, 1 as age

{{ config(post_hook=["alter table {{ this }} add primary key (id)"])}}