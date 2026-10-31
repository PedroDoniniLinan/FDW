{{ config(
    tags=['refactored', 'categories', 'main']
) }}

{% set br_bonds = ['TD', 'CDB', 'CRA', 'LCI'] %}
{% set bond_types = ['CDI', 'SELIC', 'IPCA', 'Prefix'] %}
{% set bond_term = ['B', 'L', 'E', ''] %}

with

raw_assets as (
    select asset
    from {{ ref("stg_balances__assets") }}
),

raw_income_categories as (
    select
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref('dim_income') }}
),

bonds_categorization as (
    select distinct
        case
                {% for bb in br_bonds %}{% for bt in bond_types %}{% for btt in bond_term %}
                when asset ~* '{{ bb }}.*{{ bt }}.*{{ btt }}' then '{{ bb }} {{ bt }}'
            {% endfor %}{% endfor %}{% endfor %}
        end as budget_level_3,
        asset
    from raw_assets
    where asset ~* '(cdb|td|cra|lci)'
),

all_dims as (
    select
        t.asset as category,
        'Income' as transaction_type,
        ic.financial_level_1,
        ic.financial_level_2,
        ic.budget_level_1,
        ic.budget_level_2,
        ic.budget_level_3,
        md5(t.asset)::uuid as category_id
    from bonds_categorization as t
    inner join raw_income_categories as ic on (t.budget_level_3 = ic.budget_level_3)
),

final as (
    select
        category_id,
        category,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from all_dims
)

select * from final
