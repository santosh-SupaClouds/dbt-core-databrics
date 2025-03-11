#!/bin/bash
# Script to create Teradata to Databricks migration project structure

# Create base directory
mkdir -p teradata_to_databricks
cd teradata_to_databricks

# Create directory structure
mkdir -p .dbt
mkdir -p .github/workflows
mkdir -p analyses
mkdir -p macros
mkdir -p models/marts/core
mkdir -p models/marts/marketing
mkdir -p models/intermediate
mkdir -p models/staging
mkdir -p seeds
mkdir -p snapshots
mkdir -p tests/generic
mkdir -p tests/singular
mkdir -p scripts
mkdir -p data

# Create .dbt files
cat > .dbt/profiles.yml << 'EOF'
teradata_to_databricks:
  target: teradata
  outputs:
    teradata:
      type: teradata
      host: "{{ env_var('TERADATA_HOST', 'your_teradata_host') }}"
      username: "{{ env_var('TERADATA_USERNAME', 'migration_user') }}"
      password: "{{ env_var('DBT_TERADATA_PASSWORD') }}"
      schema: "{{ env_var('TERADATA_SCHEMA', 'your_teradata_schema') }}"
      database: "{{ env_var('TERADATA_DATABASE', 'your_teradata_database') }}"
      port: 1025
      tmode: ANSI
      threads: 4
      
    databricks:
      type: databricks
      host: "{{ env_var('DATABRICKS_HOST', 'your_databricks_host') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH', '/sql/protocolv1/o/0123456789/0123456789') }}"
      token: "{{ env_var('DBT_DATABRICKS_TOKEN') }}"
      catalog: "{{ env_var('DATABRICKS_CATALOG', 'teradata_migration') }}"
      schema: "{{ env_var('DATABRICKS_SCHEMA', 'transformed_data') }}"
      threads: 8
      connect_timeout: 30
      connect_retries: 5
EOF

# Create GitHub workflow
cat > .github/workflows/dbt_migration.yml << 'EOF'
name: Teradata to Databricks Migration Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 5 * * *'  # Run daily at 5 AM UTC

jobs:
  # Test against Teradata
  test_teradata:
    name: Test against Teradata
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install dbt-core dbt-teradata
          dbt deps
      
      - name: Run dbt tests against Teradata
        run: |
          mkdir -p ~/.dbt
          echo "$DBT_PROFILES_YML" > ~/.dbt/profiles.yml
          dbt debug --target teradata
          dbt seed --target teradata
          dbt run --target teradata
          dbt test --target teradata
        env:
          DBT_PROFILES_YML: ${{ secrets.DBT_PROFILES_YML }}
          TERADATA_HOST: ${{ secrets.TERADATA_HOST }}
          TERADATA_USERNAME: ${{ secrets.TERADATA_USERNAME }}
          DBT_TERADATA_PASSWORD: ${{ secrets.TERADATA_PASSWORD }}
          TERADATA_DATABASE: ${{ secrets.TERADATA_DATABASE }}
          TERADATA_SCHEMA: ${{ secrets.TERADATA_SCHEMA }}

  # Deploy to Databricks
  deploy_databricks:
    name: Deploy to Databricks
    needs: test_teradata
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install dbt-core dbt-databricks
          dbt deps
      
      - name: Deploy to Databricks
        run: |
          mkdir -p ~/.dbt
          echo "$DBT_PROFILES_YML" > ~/.dbt/profiles.yml
          dbt debug --target databricks
          dbt seed --target databricks
          dbt run --target databricks
          dbt test --target databricks
          dbt docs generate --target databricks
        env:
          DBT_PROFILES_YML: ${{ secrets.DBT_PROFILES_YML }}
          DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
          DATABRICKS_HTTP_PATH: ${{ secrets.DATABRICKS_HTTP_PATH }}
          DBT_DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
          DATABRICKS_CATALOG: ${{ secrets.DATABRICKS_CATALOG }}
          DATABRICKS_SCHEMA: ${{ secrets.DATABRICKS_SCHEMA }}

  # Compare environments (optional)
  compare_environments:
    name: Compare Teradata and Databricks environments
    needs: deploy_databricks
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install dbt-core dbt-teradata dbt-databricks pandas tabulate
          dbt deps
      
      - name: Run comparison
        run: |
          mkdir -p ~/.dbt
          echo "$DBT_PROFILES_YML" > ~/.dbt/profiles.yml
          
          # Run data quality check in Teradata
          dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: teradata, output: "data/teradata_counts.csv"}'
          
          # Run data quality check in Databricks
          dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: databricks, output: "data/databricks_counts.csv"}'
          
          # Compare results with Python
          python scripts/compare_environments.py
        env:
          DBT_PROFILES_YML: ${{ secrets.DBT_PROFILES_YML }}
          TERADATA_HOST: ${{ secrets.TERADATA_HOST }}
          TERADATA_USERNAME: ${{ secrets.TERADATA_USERNAME }}
          DBT_TERADATA_PASSWORD: ${{ secrets.TERADATA_PASSWORD }}
          DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
          DATABRICKS_HTTP_PATH: ${{ secrets.DATABRICKS_HTTP_PATH }}
          DBT_DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
          DATABRICKS_CATALOG: ${{ secrets.DATABRICKS_CATALOG }}
          DATABRICKS_SCHEMA: ${{ secrets.DATABRICKS_SCHEMA }}
EOF

# Create analyses files
cat > analyses/data_quality_check.sql << 'EOF'
/*
  Analysis to check data quality and completeness across the Teradata to Databricks migration
  This is meant to be run in both environments to compare results
*/

-- Count comparison across all tables
WITH table_counts AS (
    -- Source tables
    SELECT 
        'teradata_source.customers' AS table_name,
        COUNT(*) AS record_count
    FROM {{ source('teradata_source', 'customers') }}
    
    UNION ALL
    
    SELECT 
        'teradata_source.orders' AS table_name,
        COUNT(*) AS record_count
    FROM {{ source('teradata_source', 'orders') }}
    
    UNION ALL
    
    SELECT 
        'teradata_source.products' AS table_name,
        COUNT(*) AS record_count
    FROM {{ source('teradata_source', 'products') }}
    
    UNION ALL
    
    -- Dimension and fact tables
    SELECT 
        'dim_customers' AS table_name,
        COUNT(*) AS record_count
    FROM {{ ref('dim_customers') }}
    
    UNION ALL
    
    SELECT 
        'fact_orders' AS table_name,
        COUNT(*) AS record_count
    FROM {{ ref('fact_orders') }}
    
    UNION ALL
    
    SELECT 
        'dim_products' AS table_name,
        COUNT(*) AS record_count
    FROM {{ ref('dim_products') }}
)

SELECT 
    table_name,
    record_count,
    '{{ target.type }}' AS environment
FROM table_counts
ORDER BY table_name
EOF

# Create macros
cat > macros/data_type_conversion.sql << 'EOF'
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
EOF

cat > macros/generate_schema_name.sql << 'EOF'
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
EOF

cat > macros/teradata_utils.sql << 'EOF'
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
EOF

# Create models
# Create models/sources.yml
cat > models/sources.yml << 'EOF'
version: 2

sources:
  - name: teradata_source
    database: "{{ var('raw_database') }}"
    schema: "{{ env_var('TERADATA_SCHEMA', 'your_teradata_schema') }}"
    description: "Raw data from Teradata production database"
    
    tables:
      - name: customers
        description: "Customer master data from Teradata"
        columns:
          - name: customer_id
            description: "Primary key for customer"
            tests:
              - unique
              - not_null
          - name: customer_name
            description: "Customer full name"
          - name: email
            description: "Customer email address"
            tests:
              - not_null
          - name: phone
            description: "Customer phone number"
          - name: address
            description: "Customer physical address"
          - name: city
            description: "Customer city"
          - name: state
            description: "Customer state/province"
          - name: zip_code
            description: "Customer postal code"
          - name: country
            description: "Customer country"
          - name: region_code
            description: "Region code"
          - name: created_at
            description: "Date customer was created"
          - name: updated_at
            description: "Date customer was last updated"
      
      - name: orders
        description: "Order transactions from Teradata"
        columns:
          - name: order_id
            description: "Primary key for order"
            tests:
              - unique
              - not_null
          - name: customer_id
            description: "Foreign key to customers table"
            tests:
              - relationships:
                  to: source('teradata_source', 'customers')
                  field: customer_id
              - not_null
          - name: order_date
            description: "Date order was placed"
            tests:
              - not_null
          - name: order_status
            description: "Current status of order"
            tests:
              - accepted_values:
                  values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
          - name: order_total
            description: "Total amount of the order"
            tests:
              - not_null
          - name: created_at
            description: "Date order was created"
          - name: updated_at
            description: "Date order was last updated"
      
      - name: products
        description: "Product catalog from Teradata"
        columns:
          - name: product_id
            description: "Primary key for product"
            tests:
              - unique
              - not_null
          - name: product_name
            description: "Product name"
            tests:
              - not_null
          - name: description
            description: "Product description"
          - name: price
            description: "Product price"
            tests:
              - not_null
          - name: category_id
            description: "Product category ID"
          - name: created_at
            description: "Date product was created"
          - name: updated_at
            description: "Date product was last updated"
EOF

# Create staging models
cat > models/staging/stg_teradata__customers.sql << 'EOF'
{{ config(
    materialized='view'
) }}

with source as (
    select * from {{ source('teradata_source', 'customers') }}
),

renamed as (
    select
        customer_id,
        customer_name,
        email,
        phone,
        address,
        city,
        state,
        zip_code,
        country,
        region_code,
        {{ handle_teradata_timestamp('created_at') }} as created_at,
        {{ handle_teradata_timestamp('updated_at') }} as updated_at
    from source
),

final as (
    select
        -- Primary key
        customer_id,
        
        -- Customer attributes
        customer_name,
        email,
        phone,
        address,
        city,
        state,
        zip_code,
        country,
        region_code,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Add a source identifier for the migration
        '{{ target.type }}' as data_source
    from renamed
)

select * from final
EOF

cat > models/staging/stg_teradata__orders.sql << 'EOF'
{{ config(
    materialized='view'
) }}

with source as (
    select * from {{ source('teradata_source', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_date,
        order_status,
        order_total,
        {{ handle_teradata_timestamp('created_at') }} as created_at,
        {{ handle_teradata_timestamp('updated_at') }} as updated_at
    from source
),

final as (
    select
        -- Primary key
        order_id,
        
        -- Foreign keys
        customer_id,
        
        -- Order attributes
        order_date,
        order_status,
        order_total,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Add a source identifier for the migration
        '{{ target.type }}' as data_source
    from renamed
)

select * from final
EOF

cat > models/staging/stg_teradata__products.sql << 'EOF'
{{ config(
    materialized='view'
) }}

with source as (
    select * from {{ source('teradata_source', 'products') }}
),

renamed as (
    select
        product_id,
        product_name,
        description,
        price,
        category_id,
        {{ handle_teradata_timestamp('created_at') }} as created_at,
        {{ handle_teradata_timestamp('updated_at') }} as updated_at
    from source
),

final as (
    select
        -- Primary key
        product_id,
        
        -- Product attributes
        product_name,
        description,
        price,
        category_id,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Add a source identifier for the migration
        '{{ target.type }}' as data_source
    from renamed
)

select * from final
EOF

cat > models/staging/schema.yml << 'EOF'
version: 2

models:
  - name: stg_teradata__customers
    description: "Staged customer data from Teradata"
    columns:
      - name: customer_id
        description: "Primary key for customer"
        tests:
          - unique
          - not_null
      - name: customer_name
        description: "Customer full name"
      - name: email
        description: "Customer email address"
        tests:
          - not_null
      - name: phone
        description: "Customer phone number"
      - name: address
        description: "Customer physical address"
      - name: city
        description: "Customer city"
      - name: state
        description: "Customer state/province"
      - name: zip_code
        description: "Customer postal code"
      - name: country
        description: "Customer country"
      - name: region_code
        description: "Region code"
      - name: created_at
        description: "Date customer was created"
      - name: updated_at
        description: "Date customer was last updated"
      - name: data_source
        description: "Data source identifier"

  - name: stg_teradata__orders
    description: "Staged order data from Teradata"
    columns:
      - name: order_id
        description: "Primary key for order"
        tests:
          - unique
          - not_null
      - name: customer_id
        description: "Foreign key to customers table"
        tests:
          - relationships:
              to: ref('stg_teradata__customers')
              field: customer_id
          - not_null
      - name: order_date
        description: "Date order was placed"
        tests:
          - not_null
      - name: order_status
        description: "Current status of order"
        tests:
          - accepted_values:
              values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
      - name: order_total
        description: "Total amount of the order"
        tests:
          - not_null
      - name: created_at
        description: "Date order was created"
      - name: updated_at
        description: "Date order was last updated"
      - name: data_source
        description: "Data source identifier"

  - name: stg_teradata__products
    description: "Staged product data from Teradata"
    columns:
      - name: product_id
        description: "Primary key for product"
        tests:
          - unique
          - not_null
      - name: product_name
        description: "Product name"
        tests:
          - not_null
      - name: description
        description: "Product description"
      - name: price
        description: "Product price"
        tests:
          - not_null
      - name: category_id
        description: "Product category ID"
      - name: created_at
        description: "Date product was created"
      - name: updated_at
        description: "Date product was last updated"
      - name: data_source
        description: "Data source identifier"
EOF

# Create intermediate models
cat > models/intermediate/int_customer_orders.sql << 'EOF'
{{ config(
    materialized='ephemeral'
) }}

with customers as (
    select * from {{ ref('stg_teradata__customers') }}
),

orders as (
    select * from {{ ref('stg_teradata__orders') }}
),

-- Join customer data with their orders
customer_orders as (
    select
        -- Customer information
        customers.customer_id,
        customers.customer_name,
        customers.email,
        customers.region_code,
        
        -- Order information
        orders.order_id,
        orders.order_date,
        orders.order_status,
        orders.order_total
    from customers
    left join orders on customers.customer_id = orders.customer_id
),

-- Aggregate order metrics by customer
customer_order_summary as (
    select
        customer_id,
        customer_name,
        email,
        region_code,
        count(order_id) as total_orders,
        sum(order_total) as lifetime_value,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        datediff(
            {% if target.type == 'teradata' %}
                day
            {% else %}
                'day'
            {% endif %},
            min(order_date), 
            max(order_date)
        ) as customer_tenure_days
    from customer_orders
    group by 1, 2, 3, 4
)

select * from customer_order_summary
EOF

cat > models/intermediate/schema.yml << 'EOF'
version: 2

models:
  - name: int_customer_orders
    description: "Aggregated customer order information with metrics"
    columns:
      - name: customer_id
        description: "Primary key for customer"
        tests:
          - unique
          - not_null
      - name: customer_name
        description: "Customer full name"
      - name: email
        description: "Customer email address"
      - name: region_code
        description: "Region code"
      - name: total_orders
        description: "Total number of orders placed by customer"
        tests:
          - not_null
      - name: lifetime_value
        description: "Total lifetime value of customer (sum of all order totals)"
        tests:
          - not_null
      - name: first_order_date
        description: "Date of customer's first order"
      - name: last_order_date
        description: "Date of customer's most recent order"
      - name: customer_tenure_days
        description: "Number of days between first and last order"
EOF

# Create mart models
cat > models/marts/core/dim_customers.sql << 'EOF'
{{ config(
    materialized='table',
    file_format='delta',
    location_root='/mnt/migration/dim_customers'
) }}

with customers as (
    select * from {{ ref('stg_teradata__customers') }}
),

customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

-- Join region mapping from seed file if running in Databricks
{% if target.type == 'databricks' %}
region_mapping as (
    select * from {{ ref('region_mapping') }}
),
{% endif %}

final as (
    select
        customers.customer_id,
        customers.customer_name,
        customers.email,
        customers.phone,
        customers.address,
        customers.city,
        customers.state,
        customers.zip_code,
        customers.country,
        customers.region_code,
        
        {% if target.type == 'databricks' %}
        -- Enrich with region name from seed file when in Databricks
        coalesce(region_mapping.region_name, 'Unknown') as region_name,
        {% else %}
        -- Placeholder when running in Teradata
        'N/A' as region_name,
        {% endif %}
        
        -- Add metrics from customer orders
        coalesce(customer_orders.total_orders, 0) as lifetime_orders,
        coalesce(customer_orders.lifetime_value, 0) as lifetime_value,
        customer_orders.first_order_date,
        customer_orders.last_order_date,
        
        -- Customer segmentation
        case
            when customer_orders.lifetime_value > 1000 then 'High Value'
            when customer_orders.lifetime_value between 500 and 1000 then 'Medium Value'
            when customer_orders.lifetime_value > 0 then 'Low Value'
            else 'No Orders'
        end as customer_segment,
        
        -- Metadata
        customers.created_at,
        customers.updated_at,
        current_timestamp() as loaded_at
    from customers
    left join customer_orders using (customer_id)
    {% if target.type == 'databricks' %}
    left join region_mapping on customers.region_code = region_mapping.region_code
    {% endif %}
)

select * from final
EOF

cat > models/marts/core/fact_orders.sql << 'EOF'
{{ config(
    materialized='table',
    file_format='delta',
    location_root='/mnt/migration/fact_orders',
    partition_by=['order_year', 'order_month']
) }}

with orders as (
    select * from {{ ref('stg_teradata__orders') }}
),

final as (
    select
        -- Primary key
        order_id,
        
        -- Foreign keys
        customer_id,
        
        -- Order attributes
        order_date,
        order_status,
        order_total,
        
        -- Date dimensions for partitioning and analysis
        extract(year from order_date) as order_year,
        extract(month from order_date) as order_month,
        extract(day from order_date) as order_day,
        
        -- Order metrics
        case 
            when order_status = 'cancelled' then 0
            else order_total
        end as valid_order_total,
        
        -- Metadata
        created_at,
        updated_at,
        current_timestamp() as loaded_at
    from orders
)

select * from final
EOF

cat > models/marts/core/dim_products.sql << 'EOF'
{{ config(
    materialized='table',
    file_format='delta',
    location_root='/mnt/migration/dim_products'
) }}

with products as (
    select * from {{ ref('stg_teradata__products') }}
),

-- Join category mapping from seed file if running in Databricks
{% if target.type == 'databricks' %}
category_mapping as (
    select * from {{ ref('product_category_mapping') }}
),
{% endif %}

cat > models/marts/core/dim_products.sql << 'EOF'
{{ config(
    materialized='table',
    file_format='delta',
    location_root='/mnt/migration/dim_products'
) }}

with products as (
    select * from {{ ref('stg_teradata__products') }}
),

-- Join category mapping from seed file if running in Databricks
{% if target.type == 'databricks' %}
category_mapping as (
    select * from {{ ref('product_category_mapping') }}
),
{% endif %}

final as (
    select
        -- Primary key
        products.product_id,
        
        -- Product attributes
        products.product_name,
        products.description,
        products.price,
        products.category_id,
        
        {% if target.type == 'databricks' %}
        -- Enrich with category details from seed file when in Databricks
        coalesce(category_mapping.category_name, 'Unknown') as category_name,
        coalesce(category_mapping.department, 'Unknown') as department,
        {% else %}
        -- Placeholders when running in Teradata
        'N/A' as category_name,
        'N/A' as department,
        {% endif %}
        
        -- Price tiers
        case
            when products.price > 100 then 'Premium'
            when products.price > 50 then 'Standard'
            else 'Basic'
        end as price_tier,
        
        -- Metadata
        products.created_at,
        products.updated_at,
        current_timestamp() as loaded_at
    from products
    {% if target.type == 'databricks' %}
    left join category_mapping on products.category_id = category_mapping.category_id
    {% endif %}
)

select * from final
EOF

cat > models/marts/core/schema.yml << 'EOF'
version: 2

models:
  - name: dim_customers
    description: "Customer dimension table with enriched attributes and metrics"
    config:
      tags: ["core", "dimension"]
    columns:
      - name: customer_id
        description: "Primary key for customer"
        tests:
          - unique
          - not_null
      - name: customer_name
        description: "Customer full name"
      - name: email
        description: "Customer email address"
      - name: phone
        description: "Customer phone number"
      - name: address
        description: "Customer physical address"
      - name: city
        description: "Customer city"
      - name: state
        description: "Customer state/province"
      - name: zip_code
        description: "Customer postal code"
      - name: country
        description: "Customer country"
      - name: region_code
        description: "Region code"
      - name: region_name
        description: "Region name (from region mapping)"
      - name: lifetime_orders
        description: "Total number of orders placed by customer"
      - name: lifetime_value
        description: "Total lifetime value of customer (sum of all order totals)"
      - name: first_order_date
        description: "Date of customer's first order"
      - name: last_order_date
        description: "Date of customer's most recent order"
      - name: customer_segment
        description: "Customer segment based on lifetime value"
        tests:
          - accepted_values:
              values: ['High Value', 'Medium Value', 'Low Value', 'No Orders']
      - name: created_at
        description: "Date customer was created"
      - name: updated_at
        description: "Date customer was last updated"
      - name: loaded_at
        description: "Timestamp when this record was loaded into the data warehouse"

  - name: fact_orders
    description: "Order fact table with transaction details"
    config:
      tags: ["core", "fact"]
    columns:
      - name: order_id
        description: "Primary key for order"
        tests:
          - unique
          - not_null
      - name: customer_id
        description: "Foreign key to dim_customers"
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
          - not_null
      - name: order_date
        description: "Date order was placed"
        tests:
          - not_null
      - name: order_status
        description: "Current status of order"
        tests:
          - accepted_values:
              values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
      - name: order_total
        description: "Total amount of the order"
      - name: order_year
        description: "Year of order date (for partitioning)"
      - name: order_month
        description: "Month of order date (for partitioning)"
      - name: order_day
        description: "Day of order date"
      - name: valid_order_total
        description: "Order total that excludes cancelled orders"
      - name: created_at
        description: "Date order was created"
      - name: updated_at
        description: "Date order was last updated"
      - name: loaded_at
        description: "Timestamp when this record was loaded into the data warehouse"

  - name: dim_products
    description: "Product dimension table with enriched attributes"
    config:
      tags: ["core", "dimension"]
    columns:
      - name: product_id
        description: "Primary key for product"
        tests:
          - unique
          - not_null
      - name: product_name
        description: "Product name"
      - name: description
        description: "Product description"
      - name: price
        description: "Product price"
      - name: category_id
        description: "Product category ID"
      - name: category_name
        description: "Category name (from category mapping)"
      - name: department
        description: "Department (from category mapping)"
      - name: price_tier
        description: "Price tier classification"
        tests:
          - accepted_values:
              values: ['Premium', 'Standard', 'Basic']
      - name: created_at
        description: "Date product was created"
      - name: updated_at
        description: "Date product was last updated"
      - name: loaded_at
        description: "Timestamp when this record was loaded into the data warehouse"
EOF

cat > models/marts/marketing/customer_sales_summary.sql << 'EOF'
{{ config(
    materialized='table',
    file_format='delta',
    location_root='/mnt/migration/customer_sales_summary'
) }}

with customers as (
    select * from {{ ref('dim_customers') }}
),

orders as (
    select * from {{ ref('fact_orders') }}
),

-- Calculate customer sales metrics by period
customer_period_sales as (
    select
        customer_id,
        order_year,
        order_month,
        count(*) as order_count,
        sum(order_total) as total_sales,
        avg(order_total) as avg_order_value,
        min(order_date) as first_order_in_period,
        max(order_date) as last_order_in_period
    from orders
    group by 1, 2, 3
),

-- Join customer details with their period sales
final as (
    select
        -- Time period
        customer_period_sales.order_year,
        customer_period_sales.order_month,
        
        -- Customer information
        customers.customer_id,
        customers.customer_name,
        customers.email,
        customers.region_code,
        customers.region_name,
        customers.customer_segment,
        
        -- Period metrics
        customer_period_sales.order_count,
        customer_period_sales.total_sales,
        customer_period_sales.avg_order_value,
        
        -- Overall metrics
        customers.lifetime_orders,
        customers.lifetime_value,
        
        -- Metadata
        current_timestamp() as loaded_at
    from customers
    inner join customer_period_sales 
        on customers.customer_id = customer_period_sales.customer_id
)

select * from final
EOF

cat > models/marts/marketing/schema.yml << 'EOF'
version: 2

models:
  - name: customer_sales_summary
    description: "Customer sales aggregated by year and month for marketing analysis"
    config:
      tags: ["marketing", "reporting"]
    columns:
      - name: order_year
        description: "Year of orders"
        tests:
          - not_null
      - name: order_month
        description: "Month of orders"
        tests:
          - not_null
          - accepted_values:
              values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
      - name: customer_id
        description: "Customer identifier"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: customer_name
        description: "Customer name"
      - name: email
        description: "Customer email"
      - name: region_code
        description: "Region code"
      - name: region_name
        description: "Region name"
      - name: customer_segment
        description: "Customer segment based on lifetime value"
      - name: order_count
        description: "Number of orders in this period"
        tests:
          - not_null
      - name: total_sales
        description: "Total sales amount in this period"
        tests:
          - not_null
      - name: avg_order_value
        description: "Average order value in this period"
        tests:
          - not_null
      - name: lifetime_orders
        description: "Total lifetime orders for this customer"
      - name: lifetime_value
        description: "Total lifetime value for this customer"
      - name: loaded_at
        description: "Timestamp when this record was loaded"
EOF

# Create seed files
cat > seeds/region_mapping.csv << 'EOF'
region_code,region_name
N,North
S,South
E,East
W,West
NE,Northeast
NW,Northwest
SE,Southeast
SW,Southwest
C,Central
EU,Europe
APAC,Asia Pacific
LATAM,Latin America
MENA,Middle East & North Africa
EOF

cat > seeds/product_category_mapping.csv << 'EOF'
category_id,category_name,department
1,Electronics,Technology
2,Computers,Technology
3,Smartphones,Technology
4,Home Appliances,Home
5,Kitchen,Home
6,Furniture,Home
7,Clothing,Fashion
8,Shoes,Fashion
9,Jewelry,Fashion
10,Books,Media
11,Movies,Media
12,Music,Media
13,Toys,Kids
14,Baby,Kids
15,Sports,Outdoors
16,Fitness,Outdoors
17,Beauty,Personal Care
18,Health,Personal Care
EOF

# Create snapshot
cat > snapshots/customer_snapshot.sql << 'EOF'
{% snapshot customer_snapshot %}

{{
    config(
      target_database='teradata_migration',
      target_schema='snapshots',
      unique_key='customer_id',
      
      strategy='timestamp',
      updated_at='updated_at',
      
      invalidate_hard_deletes=True,
    )
}}

select * from {{ ref('stg_teradata__customers') }}

{% endsnapshot %}
EOF

# Create tests
cat > tests/generic/test_not_null_proportion.sql << 'EOF'
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
EOF

cat > tests/singular/test_email_format.sql << 'EOF'
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
EOF

cat > tests/singular/test_order_total_check.sql << 'EOF'
-- Test to verify that order_total is positive for non-cancelled orders
-- Returns records that fail the validation

SELECT 
    order_id,
    order_status,
    order_total
FROM {{ ref('fact_orders') }}
WHERE order_status != 'cancelled' 
  AND order_total <= 0
EOF

# Create scripts
cat > scripts/compare_environments.py << 'EOF'
#!/usr/bin/env python
"""
Script to compare table counts between Teradata and Databricks environments
Used in the migration process to verify data integrity
"""

import os
import pandas as pd
from tabulate import tabulate

def main():
    """Compare record counts between Teradata and Databricks environments."""
    # Read CSV files with counts from each environment
    teradata_df = pd.read_csv('data/teradata_counts.csv')
    databricks_df = pd.read_csv('data/databricks_counts.csv')
    
    # Merge dataframes to compare counts
    comparison_df = pd.merge(
        teradata_df, 
        databricks_df,
        on='table_name',
        suffixes=('_teradata', '_databricks')
    )
    
    # Calculate difference and percentage
    comparison_df['count_diff'] = comparison_df['record_count_databricks'] - comparison_df['record_count_teradata']
    comparison_df['diff_percentage'] = (
        comparison_df['count_diff'] / comparison_df['record_count_teradata'] * 100
    ).fillna(0).round(2)
    
    # Add a pass/fail column
    comparison_df['status'] = comparison_df.apply(
        lambda row: 'PASS' if abs(row['diff_percentage']) < 1 else 'FAIL',
        axis=1
    )
    
    # Print results
    print("\n=== RECORD COUNT COMPARISON: TERADATA VS DATABRICKS ===\n")
    print(tabulate(
        comparison_df[[
            'table_name', 
            'record_count_teradata', 
            'record_count_databricks',
            'count_diff',
            'diff_percentage',
            'status'
        ]],
        headers=[
            'Table', 
            'Teradata Count', 
            'Databricks Count',
            'Difference',
            'Diff %',
            'Status'
        ],
        tablefmt='pretty'
    ))
    
    # Check if there are any failures
    failures = comparison_df[comparison_df['status'] == 'FAIL']
    if not failures.empty:
        print(f"\n⚠️ WARNING: Found {len(failures)} tables with count mismatches!\n")
        failed_tables = ", ".join(failures['table_name'].tolist())
        print(f"Failed tables: {failed_tables}")
        exit(1)
    else:
        print("\n✅ SUCCESS: All table counts match between environments!\n")
        exit(0)

if __name__ == "__main__":
    main()
EOF

chmod +x scripts/compare_environments.py

# Create dbt project files
cat > dbt_project.yml << 'EOF'
name: 'teradata_to_databricks'
version: '1.0.0'
config-version: 2

profile: 'teradata_to_databricks'

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
analysis-paths: ["analyses"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"
  - "logs"

require-dbt-version: ">=1.0.0"

# Global configurations
vars:
  # Variables used for environment-specific configurations
  is_prod: "{{ target.name == 'databricks' }}"
  raw_database: "{{ target.database }}"

# Model configurations by directory
models:
  teradata_to_databricks:
    # Staging models (direct source mapping)
    staging:
      +materialized: view
      +schema: "{% if var('is_prod') %}raw_data{% else %}staging{% endif %}"
      +tags: ["staging"]
    
    # Intermediate models (business logic)
    intermediate:
      +materialized: ephemeral
      +schema: "{% if var('is_prod') %}intermediate{% else %}intermediate{% endif %}"
      +tags: ["intermediate"]
    
    # Mart models (business entities)
    marts:
      +materialized: table
      +schema: "{% if var('is_prod') %}transformed_data{% else %}marts{% endif %}"
      +tags: ["marts"]
      
      # Core business entities
      core:
        +tags: ["core"]
        
      # Marketing analytics models
      marketing:
        +tags: ["marketing"]

# Seed configurations
seeds:
  teradata_to_databricks:
    +schema: "{% if var('is_prod') %}reference_data{% else %}seeds{% endif %}"
    region_mapping:
      +column_types:
        region_code: varchar
        region_name: varchar
    
    product_category_mapping:
      +column_types:
        category_id: int
        category_name: varchar
        department: varchar

# Snapshot configurations
snapshots:
  teradata_to_databricks:
    +target_schema: "{% if var('is_prod') %}snapshots{% else %}snapshots{% endif %}"
    +strategy: timestamp
    +updated_at: updated_at
EOF

cat > packages.yml << 'EOF'
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
  
  - package: calogica/dbt_expectations
    version: 0.9.0
    
  - package: dbt-labs/audit_helper
    version: 0.9.0
EOF

cat > requirements.txt << 'EOF'
dbt-core>=1.0.0
dbt-teradata>=1.0.0
dbt-databricks>=1.0.0
pandas>=1.3.0
tabulate>=0.8.9
PyYAML>=6.0
pytest>=7.0.0
great_expectations>=0.15.0
sqlfluff>=0.9.0
colorama>=0.4.4
EOF

# Create setup script
cat > setup.sh << 'EOF'
#!/bin/bash
# Setup script for Teradata to Databricks migration
set -e

# Print with colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Teradata to Databricks Migration Setup ===${NC}"

# Check required environment variables
check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}Error: ${1} environment variable is not set${NC}"
        exit 1
    fi
}

# Teradata variables
echo -e "${YELLOW}Checking Teradata configuration...${NC}"
check_env_var "TERADATA_HOST"
check_env_var "TERADATA_USERNAME"
check_env_var "DBT_TERADATA_PASSWORD"
check_env_var "TERADATA_DATABASE"
check_env_var "TERADATA_SCHEMA"

# Databricks variables
echo -e "${YELLOW}Checking Databricks configuration...${NC}"
check_env_var "DATABRICKS_HOST"
check_env_var "DATABRICKS_HTTP_PATH"
check_env_var "DBT_DATABRICKS_TOKEN"
check_env_var "DATABRICKS_CATALOG"
check_env_var "DATABRICKS_SCHEMA"

# Check required tools
echo -e "${YELLOW}Checking required tools...${NC}"

if ! command -v python &> /dev/null; then
    echo -e "${RED}Error: Python is not installed${NC}"
    exit 1
fi

if ! command -v pip &> /dev/null; then
    echo -e "${RED}Error: pip is not installed${NC}"
    exit 1
fi

if ! command -v dbt &> /dev/null; then
    echo -e "${YELLOW}Installing dbt...${NC}"
    pip install dbt-core dbt-teradata dbt-databricks
fi

# Install dependencies
echo -e "${YELLOW}Installing project dependencies...${NC}"
pip install -r requirements.txt
dbt deps

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p data logs

# Run against Teradata
echo -e "${YELLOW}=== Running against Teradata ===${NC}"
echo -e "${YELLOW}1. Testing connection to Teradata...${NC}"
dbt debug --target teradata

echo -e "${YELLOW}2. Loading seed data to Teradata...${NC}"
dbt seed --target teradata

echo -e "${YELLOW}3. Running models in Teradata...${NC}"
dbt run --target teradata

echo -e "${YELLOW}4. Testing models in Teradata...${NC}"
dbt test --target teradata

echo -e "${YELLOW}5. Generating documentation for Teradata...${NC}"
dbt docs generate --target teradata

# Run against Databricks
echo -e "${YELLOW}=== Running against Databricks ===${NC}"
echo -e "${YELLOW}1. Testing connection to Databricks...${NC}"
dbt debug --target databricks

echo -e "${YELLOW}2. Loading seed data to Databricks...${NC}"
dbt seed --target databricks

echo -e "${YELLOW}3. Running models in Databricks...${NC}"
dbt run --target databricks

echo -e "${YELLOW}4. Testing models in Databricks...${NC}"
dbt test --target databricks

echo -e "${YELLOW}5. Generating documentation for Databricks...${NC}"
dbt docs generate --target databricks

# Compare environments
echo -e "${YELLOW}=== Comparing environments ===${NC}"
echo -e "${YELLOW}1. Running data quality check in Teradata...${NC}"
dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: teradata, output: "data/teradata_counts.csv"}'

echo -e "${YELLOW}2. Running data quality check in Databricks...${NC}"
dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: databricks, output: "data/databricks_counts.csv"}'

echo -e "${YELLOW}3. Comparing count results...${NC}"
python scripts/compare_environments.py

echo -e "${GREEN}=== Migration setup completed successfully ===${NC}"
echo -e "${GREEN}To view documentation, run: dbt docs serve${NC}"
EOF

chmod +x setup.sh

# Create Makefile
cat > Makefile << 'EOF'
# Makefile for Teradata to Databricks Migration

.PHONY: help setup install deps env-check teradata-check databricks-check
.PHONY: teradata-seed teradata-run teradata-test teradata-docs
.PHONY: databricks-seed databricks-run databricks-test databricks-docs
.PHONY: compare clean all

# Default target
help:
	@echo "Teradata to Databricks Migration Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  help                 Show this help message"
	@echo "  setup                Run complete setup and migration"
	@echo "  install              Install required dependencies"
	@echo "  deps                 Install dbt dependencies"
	@echo "  env-check            Check required environment variables"
	@echo "  teradata-check       Test connection to Teradata"
	@echo "  teradata-seed        Load seed data to Teradata"
	@echo "  teradata-run         Run models in Teradata"
	@echo "  teradata-test        Test models in Teradata"
	@echo "  teradata-docs        Generate documentation for Teradata"
	@echo "  databricks-check     Test connection to Databricks"
	@echo "  databricks-seed      Load seed data to Databricks"
	@echo "  databricks-run       Run models in Databricks"
	@echo "  databricks-test      Test models in Databricks"
	@echo "  databricks-docs      Generate documentation for Databricks"
	@echo "  compare              Compare environments"
	@echo "  clean                Clean generated files"
	@echo "  all                  Run all steps (full migration)"
	@echo ""
	@echo "Example: make setup"

# Complete setup
setup: install deps env-check

# Install required dependencies
install:
	@echo "Installing required dependencies..."
	pip install -r requirements.txt

# Install dbt dependencies
deps:
	@echo "Installing dbt dependencies..."
	dbt deps

# Check environment variables
env-check:
	@echo "Checking environment variables..."
	@if [ -z "$$TERADATA_HOST" ]; then echo "Error: TERADATA_HOST is not set"; exit 1; fi
	@if [ -z "$$TERADATA_USERNAME" ]; then echo "Error: TERADATA_USERNAME is not set"; exit 1; fi
	@if [ -z "$$DBT_TERADATA_PASSWORD" ]; then echo "Error: DBT_TERADATA_PASSWORD is not set"; exit 1; fi
	@if [ -z "$$TERADATA_DATABASE" ]; then echo "Error: TERADATA_DATABASE is not set"; exit 1; fi
	@if [ -z "$$TERADATA_SCHEMA" ]; then echo "Error: TERADATA_SCHEMA is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_HOST" ]; then echo "Error: DATABRICKS_HOST is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_HTTP_PATH" ]; then echo "Error: DATABRICKS_HTTP_PATH is not set"; exit 1; fi
	@if [ -z "$$DBT_DATABRICKS_TOKEN" ]; then echo "Error: DBT_DATABRICKS_TOKEN is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_CATALOG" ]; then echo "Error: DATABRICKS_CATALOG is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_SCHEMA" ]; then echo "Error: DATABRICKS_SCHEMA is not set"; exit 1; fi
	@echo "All environment variables are set"

# Teradata operations
teradata-check:
	@echo "Testing connection to Teradata..."
	dbt debug --target teradata

teradata-seed: teradata-check
	@echo "Loading seed data to Teradata..."
	dbt seed --target teradata

teradata-run: teradata-check
	@echo "Running models in Teradata..."
	dbt run --target teradata

teradata-test: teradata-run
	@echo "Testing models in Teradata..."
	dbt test --target teradata

teradata-docs: teradata-run
	@echo "Generating documentation for Teradata..."
	dbt docs generate --target teradata

teradata-all: teradata-seed teradata-run teradata-test teradata-docs
	@echo "Completed all Teradata operations"

# Databricks operations
databricks-check:
	@echo "Testing connection to Databricks..."
	dbt debug --target databricks

databricks-seed: databricks-check
	@echo "Loading seed data to Databricks..."
	dbt seed --target databricks

databricks-run: databricks-check
	@echo "Running models in Databricks..."
	dbt run --target databricks

databricks-test: databricks-run
	@echo "Testing models in Databricks..."
	dbt test --target databricks

databricks-docs: databricks-run
	@echo "Generating documentation for Databricks..."
	dbt docs generate --target databricks

databricks-all: databricks-seed databricks-run databricks-test databricks-docs
	@echo "Completed all Databricks operations"

# Compare environments
compare: teradata-run databricks-run
	@echo "Comparing environments..."
	@mkdir -p data
	dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: teradata, output: "data/teradata_counts.csv"}'
	dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: databricks, output: "data/databricks_counts.csv"}'
	python scripts/compare_environments.py

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf target
	rm -rf logs
	rm -rf dbt_packages
	rm -rf .pytest_cache
	rm -rf data/*.csv
	@echo "Clean completed"

# Run all steps
all: setup teradata-all databricks-all compare
	@echo "Migration completed successfully"
EOF

# Create gitignore
cat > .gitignore << 'EOF'
# dbt specific
target/
dbt_packages/
logs/
.user.yml
profiles.yml

# Python specific
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Environment variables
.env
.envrc
.direnv

# IDE specific files
.idea/
.vscode/
*.swp
*.swo
.DS_Store

# Data files
data/*.csv
data/*.json
data/*.parquet

# Logs
logs/
*.log

# Temporary files
tmp/
temp/
EOF

# Create README.md
cat > README.md << 'EOF'
# Teradata to Databricks Migration Framework

## Overview
This repository contains a comprehensive dbt-based framework for migrating data and analytics workloads from Teradata to Databricks. The framework provides a structured approach to extract, transform, and load data while maintaining referential integrity and business logic across platforms.

## Key Features
- **Modular Architecture**: Follows dbt best practices with staging, intermediate, and mart model layers
- **Type Handling**: Automatic data type conversion between Teradata and Databricks
- **Data Validation**: Built-in tests and comparison utilities to ensure migration accuracy
- **CI/CD Integration**: GitHub Actions workflow for automated testing and deployment
- **Documentation**: Comprehensive model documentation and data lineage

### Key Files and Their Purpose

#### Configuration Files
- **dbt_project.yml**: The main configuration file for the dbt project, specifying model materialization strategies, directory configurations, and project variables.
- **profiles.yml**: Contains connection details for both Teradata and Databricks environments.
- **packages.yml**: Lists external dbt packages used in the project, including dbt_utils and dbt_expectations.

#### Source Mapping
- **models/sources.yml**: Maps Teradata source tables to dbt sources, including column definitions, tests, and documentation.

#### Model Layers
1. **Staging Models**:
   - First layer of transformation that standardizes data from source tables
   - Handles type conversions, renames columns to a consistent format
   - Examples: `stg_teradata__customers.sql`, `stg_teradata__orders.sql`

2. **Intermediate Models**:
   - Contains business logic that spans multiple staging models
   - Not meant for direct consumption by end users
   - Example: `int_customer_orders.sql` joins customer and order data

3. **Mart Models**:
   - Final layer of transformation that produces business-ready data
   - Organized into subject areas like "core" and "marketing"
   - Examples: `dim_customers.sql`, `fact_orders.sql`, `customer_sales_summary.sql`

#### Utility Macros
- **data_type_conversion.sql**: Contains `convert_teradata_to_databricks_type()` macro for handling data type conversions between platforms.
- **generate_schema_name.sql**: Customizes schema name generation based on the target platform.
- **teradata_utils.sql**: Includes utilities for extracting Teradata metadata like tables, columns, and primary keys.

#### Testing Framework
- **tests/generic/test_not_null_proportion.sql**: Tests that a minimum proportion of rows have non-null values.
- **tests/singular/test_email_format.sql**: Validates that email addresses follow a valid format.
- **tests/singular/test_order_total_check.sql**: Ensures that order totals are positive for non-cancelled orders.

#### Reference Data
- **seeds/region_mapping.csv**: Lookup table that maps region codes to human-readable region names.
- **seeds/product_category_mapping.csv**: Lookup table for product category details.

#### Automation
- **setup.sh**: Shell script that automates the full migration process from Teradata to Databricks.
- **Makefile**: Provides make targets for common operations and simplified command execution.
- **.github/workflows/dbt_migration.yml**: GitHub Actions workflow that tests, deploys, and compares environments.

#### Comparison and Validation
- **analyses/data_quality_check.sql**: SQL query that compares record counts between environments.
- **scripts/compare_environments.py**: Python script that verifies data integrity across platforms.

## Command Summary

### Initial Setup

```bash
# Create project structure
mkdir -p teradata_to_databricks
cd teradata_to_databricks

# Clone the repository if using version control
git clone https://github.com/your-org/teradata_to_databricks.git .
# OR initialize a new git repository
git init

# Install dependencies
pip install -r requirements.txt
dbt deps

# Set environment variables for credentials
export TERADATA_HOST='your_teradata_host'
export TERADATA_USERNAME='migration_user'
export DBT_TERADATA_PASSWORD='your_secure_password'
export TERADATA_DATABASE='your_teradata_database'
export TERADATA_SCHEMA='your_teradata_schema'
export DATABRICKS_HOST='your_databricks_host'
export DATABRICKS_HTTP_PATH='/sql/protocolv1/o/0123456789/0123456789'
export DBT_DATABRICKS_TOKEN='your_databricks_token'
export DATABRICKS_CATALOG='teradata_migration'
export DATABRICKS_SCHEMA='transformed_data'