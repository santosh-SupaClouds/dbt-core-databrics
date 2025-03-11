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
