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
