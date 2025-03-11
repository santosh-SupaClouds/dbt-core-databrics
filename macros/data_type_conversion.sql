{% macro convert_teradata_to_databricks_type(column_type) %}
    {# 
        This macro converts Teradata data types to their Databricks equivalents.
        Used during the migration process to ensure proper type mapping.
    #}
    {% if column_type is none %}
        NULL
    {% elif column_type|upper in ('VARCHAR', 'CHAR', 'CHARACTER', 'CLOB', 'LONG VARCHAR') %}
        STRING
    {% elif column_type|upper in ('DECIMAL', 'NUMERIC', 'NUMBER') %}
        DECIMAL
    {% elif column_type|upper in ('INTEGER', 'INT', 'SMALLINT', 'BYTEINT') %}
        INT
    {% elif column_type|upper in ('BIGINT') %}
        BIGINT
    {% elif column_type|upper in ('FLOAT', 'REAL', 'DOUBLE PRECISION') %}
        DOUBLE
    {% elif column_type|upper in ('DATE') %}
        DATE
    {% elif column_type|upper in ('TIME', 'TIME WITH TIME ZONE') %}
        STRING
    {% elif column_type|upper in ('TIMESTAMP', 'TIMESTAMP WITH TIME ZONE') %}
        TIMESTAMP
    {% elif column_type|upper in ('BLOB', 'BYTE', 'VARBYTE') %}
        BINARY
    {% elif column_type|upper in ('BOOLEAN') %}
        BOOLEAN
    {% elif column_type|upper in ('INTERVAL DAY TO SECOND', 'INTERVAL YEAR TO MONTH') %}
        STRING
    {% elif column_type|upper in ('XML', 'JSON') %}
        STRING
    {% else %}
        STRING
    {% endif %}
{% endmacro %}

{% macro handle_teradata_timestamp(column_name) %}
    {# 
        Handles Teradata timestamp formatting issues by standardizing output
        for compatibility with Databricks' timestamp expectations
    #}
    {% if target.type == 'teradata' %}
        CAST({{ column_name }} AS TIMESTAMP FORMAT 'YYYY-MM-DDBHH:MI:SS.S(6)')
    {% else %}
        {{ column_name }}
    {% endif %}
{% endmacro %}

{% macro handle_teradata_null(column_name, default_value='') %}
    {# 
        Replaces Teradata nulls with default values to avoid NULL handling issues
    #}
    COALESCE({{ column_name }}, {{ default_value }})
{% endmacro %}