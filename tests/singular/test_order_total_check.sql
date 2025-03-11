-- Test to verify that order_total is positive for non-cancelled orders
-- Returns records that fail the validation

SELECT 
    order_id,
    order_status,
    order_total
FROM {{ ref('fact_orders') }}
WHERE order_status != 'cancelled' 
  AND order_total <= 0
