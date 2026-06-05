{{ config(
    tags=['refactored', 'categories', 'main']
) }}

{% set br_bonds = ['TD', 'CDB', 'CRA', 'LCI'] %}
{% set bond_types = ['CDI', 'SELIC', 'IPCA', 'Prefix'] %}
{% set bond_term = ['B', 'L', 'E', ''] %}

with

bonds_categorization as (
    select distinct
        case
                {% for bb in br_bonds %}{% for bt in bond_types %}{% for btt in bond_term %}
                when asset ~* '{{ bb }}.*{{ bt }}.*{{ btt }}' then '{{ bb }} {{ bt }}'
            {% endfor %}{% endfor %}{% endfor %}
        end as budget_level_3,
        asset
    from {{ ref("stg_balances__assets") }}
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
    inner join {{ ref('dim_income') }} as ic on (t.budget_level_3 = ic.budget_level_3)
)

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
