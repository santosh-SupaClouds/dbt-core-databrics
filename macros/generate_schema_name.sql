{% macro generate_schema_name(custom_schema_name, node) %}
    {#
        Override default schema generation to handle differences between
        Teradata and Databricks schema handling
    #}
    
    {% set default_schema = target.schema %}
    
    {% if target.type == 'teradata' %}
        {# Teradata schema handling #}
        {% if custom_schema_name is not none %}
            {{ custom_schema_name | trim }}
        {% else %}
            {{ default_schema | trim }}
        {% endif %}
    {% elif target.type == 'databricks' %}
        {# Databricks schema handling with catalog #}
        {% if custom_schema_name is not none %}
            {{ custom_schema_name | trim }}
        {% else %}
            {{ default_schema | trim }}
        {% endif %}
    {% else %}
        {# Default handling for other database types #}
        {% if custom_schema_name is not none %}
            {{ custom_schema_name | trim }}
        {% else %}
            {{ default_schema | trim }}
        {% endif %}
    {% endif %}
{% endmacro %}