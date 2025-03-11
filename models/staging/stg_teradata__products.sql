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
