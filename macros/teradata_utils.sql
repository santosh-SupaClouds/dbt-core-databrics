{% macro get_teradata_tables(schema_name=none) %}
    {#
        Returns a list of tables in the specified Teradata schema
        Useful for doing complete schema migrations
    #}
    
    {% set schema_to_use = schema_name or target.schema %}
    
    {% if target.type == 'teradata' %}
        {% set query %}
            SELECT TableName 
            FROM DBC.TablesV
            WHERE DatabaseName = '{{ schema_to_use }}'
            AND TableKind = 'T'
            ORDER BY TableName
        {% endset %}
        
        {% set results = run_query(query) %}
        
        {% if execute %}
            {% set table_list = results.columns['TableName'].values() %}
            {{ return(table_list) }}
        {% else %}
            {{ return([]) }}
        {% endif %}
    {% else %}
        {{ log("This macro is intended to be run against Teradata only", info=True) }}
        {{ return([]) }}
    {% endif %}
{% endmacro %}

{% macro get_teradata_column_details(schema_name=none, table_name=none) %}
    {#
        Returns detailed column information for a specific table or all tables in a schema
        Useful for automating schema migrations and type mapping
    #}
    
    {% set schema_to_use = schema_name or target.schema %}
    
    {% if target.type == 'teradata' %}
        {% set query %}
            SELECT 
                TableName,
                ColumnName,
                ColumnType,
                ColumnLength,
                DecimalTotalDigits,
                DecimalFractionalDigits,
                ColumnId,
                Nullable
            FROM DBC.ColumnsV
            WHERE DatabaseName = '{{ schema_to_use }}'
            {% if table_name is not none %}
            AND TableName = '{{ table_name }}'
            {% endif %}
            ORDER BY TableName, ColumnId
        {% endset %}
        
        {% set results = run_query(query) %}
        {{ return(results) }}
    {% else %}
        {{ log("This macro is intended to be run against Teradata only", info=True) }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}

{% macro get_teradata_primary_keys(schema_name=none, table_name=none) %}
    {#
        Returns primary key information for tables
        Useful for setting up appropriate constraints in Databricks
    #}
    
    {% set schema_to_use = schema_name or target.schema %}
    
    {% if target.type == 'teradata' %}
        {% set query %}
            SELECT 
                t.TableName,
                i.ColumnName
            FROM DBC.IndicesV i
            JOIN DBC.TablesV t ON 
                i.DatabaseName = t.DatabaseName 
                AND i.TableName = t.TableName
            WHERE i.DatabaseName = '{{ schema_to_use }}'
            AND i.UniqueFlag = 'Y'
            AND i.IndexType = 'P' -- Primary Key
            {% if table_name is not none %}
            AND t.TableName = '{{ table_name }}'
            {% endif %}
            ORDER BY t.TableName, i.ColumnPosition
        {% endset %}
        
        {% set results = run_query(query) %}
        {{ return(results) }}
    {% else %}
        {{ log("This macro is intended to be run against Teradata only", info=True) }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}