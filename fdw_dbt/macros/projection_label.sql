{% macro projection_label(kids, car, house, daria) %}
    'Projection '
    || case when kids then '' else '(no kids)' end
    || case when car then '' else '(no car)' end
    || case when house then '' else '(no house)' end
    || case when daria then '' else '(no daria)' end
{% endmacro %}