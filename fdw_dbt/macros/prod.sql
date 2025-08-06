{% macro prod(amount) %}(exp(sum(ln({{ amount }})))){% endmacro %}
