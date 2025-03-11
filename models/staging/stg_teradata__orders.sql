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
