DROP TABLE IF EXISTS ecommify.orders_partitioned CASCADE;

CREATE TABLE ecommify.orders_partitioned (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
) PARTITION BY RANGE (order_purchase_timestamp);

CREATE TABLE ecommify.orders_2016
PARTITION OF ecommify.orders_partitioned
FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');

CREATE TABLE ecommify.orders_2017
PARTITION OF ecommify.orders_partitioned
FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');

CREATE TABLE ecommify.orders_2018
PARTITION OF ecommify.orders_partitioned
FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');

CREATE TABLE ecommify.orders_default
PARTITION OF ecommify.orders_partitioned
DEFAULT;

INSERT INTO ecommify.orders_partitioned (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM ecommify.orders
WHERE order_purchase_timestamp IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_orders_part_status_date
ON ecommify.orders_partitioned(order_status, order_purchase_timestamp);