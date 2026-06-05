{% macro get_on_schema_change() %}
  {% if target.name == 'prod' %}
    {{ return('append_new_columns') }}
  {% else %}
    {{ return('fail') }}
  {% endif %}
{% endmacro %}