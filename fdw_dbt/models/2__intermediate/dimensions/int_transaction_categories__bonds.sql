{% set br_bonds = ['TD', 'CDB', 'CRA', 'LCI'] %}
{% set bond_types = ['CDI', 'SELIC', 'IPCA', 'Prefix'] %}
{% set bond_term = ['B', 'L', 'E', ''] %}

select
    md5(t.asset)::uuid as category_id,
    t.asset as category,
    'Income' as transaction_type,
    ic.financial_level_1,
    ic.financial_level_2,
    ic.budget_level_1,
    ic.budget_level_2,
    ic.budget_level_3
from (
    select distinct 
        case
            {% for bb in br_bonds %}{% for bt in bond_types %}{% for btt in bond_term %}
            when asset ~* '{{bb}}.*{{bt}}.*{{btt}}' then '{{bb}} {{bt}}'
            {% endfor %}{% endfor %}{% endfor %}
        end as budget_level_3,
        asset
    from {{ref("stg_balances__assets")}}
    where asset ~* '(cdb|td|cra|lci)'
) t
inner join {{ref('dim_income')}} ic on (ic.budget_level_3 = t.budget_level_3)
