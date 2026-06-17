CREATE SCHEMA IF NOT EXISTS ecommify;

-- Habilitar extensiones requeridas para la nota máxima
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS ecommify.geolocation CASCADE;
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

-- Tabla products modificada con tipos avanzados: JSONB y arrays TEXT[]
CREATE TABLE ecommify.products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER,
    product_metadata JSONB, -- Almacena especificaciones flexibles (color, material, etc.)
    tags TEXT[] -- Array de etiquetas de búsqueda
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

-- Tabla order_items con CHECK constraints
CREATE TABLE ecommify.order_items (
    order_id TEXT REFERENCES ecommify.orders(order_id),
    order_item_id INTEGER,
    product_id TEXT REFERENCES ecommify.products(product_id),
    seller_id TEXT REFERENCES ecommify.sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2) CHECK (price >= 0),
    freight_value NUMERIC(12,2) CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);

-- Tabla payments con CHECK constraint
CREATE TABLE ecommify.payments (
    payment_id BIGSERIAL PRIMARY KEY,
    order_id TEXT REFERENCES ecommify.orders(order_id),
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(12,2) CHECK (payment_value >= 0)
);

-- Tabla reviews con CHECK constraint para score entre 1 y 5
CREATE TABLE ecommify.reviews (
    review_internal_id BIGSERIAL PRIMARY KEY,
    review_id TEXT,
    order_id TEXT REFERENCES ecommify.orders(order_id),
    review_score INTEGER CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Nueva tabla de geolocalización utilizando PostGIS para almacenar puntos geométricos
CREATE TABLE ecommify.geolocation (
    geolocation_id BIGSERIAL PRIMARY KEY,
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state TEXT,
    geolocation_point GEOMETRY(Point, 4326) -- Punto PostGIS (SRID 4326: WGS84)
);