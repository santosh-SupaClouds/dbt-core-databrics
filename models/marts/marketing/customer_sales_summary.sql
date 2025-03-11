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
