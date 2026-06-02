{%- macro get_latest_date(relation, column, lookback_window=0, lookback_unit='day') -%}
(select max({{ column }}) - interval '{{ lookback_window }} {{ lookback_unit }}' from {{ relation }})
{%- endmacro -%}

