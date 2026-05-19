{% set br_bonds = ['TD', 'CDB', 'CRA', 'LCI'] %}
{% set bond_types = ['CDI', 'SELIC', 'IPCA', 'Prefix'] %}
{% set bond_term = ['B', 'L', 'E', ''] %}

select
    md5(t.currency) as id,
    t.currency as name,
    'Income' as transaction_type,
    ic.source as budget_level,
    ic.level_1,
    ic.level_2,
    ic.level_3,
    ic.source
from (
    select distinct 
        case
            {% for bb in br_bonds %}{% for bt in bond_types %}{% for btt in bond_term %}
            when currency ~* '{{bb}}.*{{bt}}.*{{btt}}' then '{{bb}} {{bt}}'
            {% endfor %}{% endfor %}{% endfor %}
        end as level_3,
        currency
    from {{ref("stg_balances__currencies")}}
    where currency ~* '(cdb|td|cra|lci)'
) t
inner join {{ref('dim_income')}} ic on (ic.level_3 = t.level_3)
