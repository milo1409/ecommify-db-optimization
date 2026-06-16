CREATE SCHEMA IF NOT EXISTS ecommify;

DROP TABLE IF EXISTS ecommify.reviews CASCADE;
DROP TABLE IF EXISTS ecommify.payments CASCADE;
DROP TABLE IF EXISTS ecommify.order_items CASCADE;
DROP TABLE IF EXISTS ecommify.orders CASCADE;
DROP TABLE IF EXISTS ecommify.products CASCADE;
DROP TABLE IF EXISTS ecommify.sellers CASCADE;
DROP TABLE IF EXISTS ecommify.customers CASCADE;

CREATE TABLE ecommify.customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix INTEGER,
    customer_city TEXT,
    customer_state TEXT
);

CREATE TABLE ecommify.sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city TEXT,
    seller_state TEXT
);

CREATE TABLE ecommify.products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE TABLE ecommify.orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT REFERENCES ecommify.customers(customer_id),
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE ecommify.order_items (
    order_id TEXT REFERENCES ecommify.orders(order_id),
    order_item_id INTEGER,
    product_id TEXT REFERENCES ecommify.products(product_id),
    seller_id TEXT REFERENCES ecommify.sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE ecommify.payments (
    payment_id BIGSERIAL PRIMARY KEY,
    order_id TEXT REFERENCES ecommify.orders(order_id),
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(12,2)
);

CREATE TABLE ecommify.reviews (
    review_internal_id BIGSERIAL PRIMARY KEY,
    review_id TEXT,
    order_id TEXT REFERENCES ecommify.orders(order_id),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);