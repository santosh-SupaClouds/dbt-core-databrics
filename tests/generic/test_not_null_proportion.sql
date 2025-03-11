{% test not_null_proportion(model, column_name, at_least) %}

{# 
    Test that verifies that a specified proportion of rows have non-null values in a column
    Example: {{ test_not_null_proportion(ref('my_model'), 'my_column', 0.95) }}
#}

{% set at_least = at_least or 0.95 %}

with validation as (
    select 
        sum(case when {{ column_name }} is null then 0 else 1 end) * 1.0 / count(*) as not_null_proportion
    from {{ model }}
),

validation_errors as (
    select 
        not_null_proportion
    from validation 
    where not_null_proportion < {{ at_least }}
)

select 
    *
from validation_errors

{% endtest %}
