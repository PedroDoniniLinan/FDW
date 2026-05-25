{%- macro latest_date(relation, column) -%}
(select max({{ column }}) from {{ relation }})
{%- endmacro -%}