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
