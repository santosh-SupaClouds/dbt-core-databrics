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
