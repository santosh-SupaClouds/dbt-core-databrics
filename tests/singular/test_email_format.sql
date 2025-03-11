-- Test to verify that email addresses follow a valid format
-- Returns records that fail the validation

{% if target.type == 'teradata' %}
-- Teradata regex syntax
SELECT 
    customer_id,
    email
FROM {{ ref('stg_teradata__customers') }}
WHERE email IS NOT NULL
  AND NOT REGEXP_INSTR(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') > 0
{% else %}
-- Databricks regex syntax
SELECT 
    customer_id,
    email
FROM {{ ref('stg_teradata__customers') }}
WHERE email IS NOT NULL
  AND NOT RLIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
{% endif %}
