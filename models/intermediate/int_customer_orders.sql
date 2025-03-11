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
