{{ config(schema='silver', materialized='view') }}
{% set br_bonds = ['TD', 'CDB'] %}
{% set bond_types = ['CDI', 'SELIC', 'IPCA', 'Prefix'] %}
{% set bond_term = ['B', 'L', 'E'] %}

select * from (
    select
        budget_level,
        level_1,
        level_2,
        level_3,
        source,
        label,
        transaction_type,
        row_number() over (partition by label, transaction_type order by level_1) as rn
    from (
        select
            budget_level,
            level_1,
            level_2,
            level_3,
            frequency as source,
            label,
            'Expenses' as transaction_type
        from {{ref('expenses_categories')}}
        union all
        select
            source as budget_level,
            level_1,
            level_2,
            level_3,
            source,
            label,
            'Income' as transaction_type
        from {{ref('income_categories')}}
        union all
        select
            ic.source as budget_level,
            ic.level_1,
            ic.level_2,
            ic.level_3,
            ic.source,
            t.currency as label,
            'Income' as transaction_type
        from (
            select distinct 
                case
                    {% for bb in br_bonds %}{% for bt in bond_types %}{% for btt in bond_term %}
                    when currency ~* '{{bb}}.*{{bt}}.*{{btt}}' then '{{bb}} {{bt}}'
                    {% endfor %}{% endfor %}{% endfor %}
                end as level_3,
                currency
            from {{ref("src_balance_checks")}}
            where currency ~* '(cdb|td)'
        ) t
        inner join {{ref('income_categories')}} ic on (ic.level_3 = t.level_3)
    ) t
    where label is not null
)
where rn = 1