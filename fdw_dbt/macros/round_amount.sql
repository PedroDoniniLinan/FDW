{% macro round_amount(amount, currency) %}
round({{ amount }}::numeric, 
    (select round_num 
    from {{ref("src_currency_rounding_decimals")}} c 
    where rounding_currency = {{ currency }}))
{% endmacro %}
