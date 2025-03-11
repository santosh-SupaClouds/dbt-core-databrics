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
