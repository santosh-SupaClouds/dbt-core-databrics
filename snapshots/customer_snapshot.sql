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
