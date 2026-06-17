-- 01_schema.sql
-- Modelo relacional PostgreSQL de Ecommify.
-- Basado en el documento de diseño técnico.
-- Nombres en inglés para mantener consistencia técnica del repositorio.

SET search_path TO ecommify, public;

-- Limpieza controlada para reconstrucción.
DROP TABLE IF EXISTS search_audit CASCADE;
DROP TABLE IF EXISTS transaction_history CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS shipments CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_details CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS inventories CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS address_type CASCADE;

-- Composite Type: dirección reutilizable.
CREATE TYPE address_type AS (
    city VARCHAR(100),
    country VARCHAR(100),
    address TEXT,
    postal_code VARCHAR(20)
);

-- =========================
-- Tabla: users
-- Equivalente a usuarios
-- =========================
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_users_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED', 'DELETED'))
);

-- =========================
-- Tabla: addresses
-- Equivalente a direcciones
-- Incluye PostGIS para geolocalización
-- =========================

CREATE TYPE address_type AS (
    street TEXT,
    number TEXT,
    neighborhood TEXT,
    reference TEXT
);

CREATE TABLE addresses (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    postal_code VARCHAR(20),
    location GEOGRAPHY(POINT, 4326),
    address_data address_type,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- =========================
-- Tabla: categories
-- Soporte para productos
-- =========================
CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- =========================
-- Tabla: products
-- Equivalente a productos
-- Usa JSONB y ARRAY según diseño
-- =========================
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL,
    category_id BIGINT REFERENCES categories(id),
    attributes JSONB,
    tags TEXT[],
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_products_price
        CHECK (price >= 0),
    CONSTRAINT chk_products_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED'))
);

-- =========================
-- Tabla: inventories
-- Equivalente a inventarios
-- =========================
CREATE TABLE inventories (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT UNIQUE NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    stock INTEGER NOT NULL DEFAULT 0,
    reserved_stock INTEGER NOT NULL DEFAULT 0,
    last_update TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_inventory_stock
        CHECK (stock >= 0),
    CONSTRAINT chk_inventory_reserved
        CHECK (reserved_stock >= 0),
    CONSTRAINT chk_inventory_reserved_lte_stock
        CHECK (reserved_stock <= stock)
);

-- =========================
-- Tabla: carts
-- Entidad conceptual del diseño
-- =========================
CREATE TABLE carts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP,
    CONSTRAINT chk_carts_status
        CHECK (status IN ('ACTIVE', 'EXPIRED', 'CONVERTED', 'DELETED'))
);

-- =========================
-- Tabla: cart_items
-- Entidad conceptual del diseño
-- =========================
CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    cart_id BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    added_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_cart_items_quantity
        CHECK (quantity > 0),
    CONSTRAINT chk_cart_items_price
        CHECK (unit_price >= 0)
);

-- =========================
-- Tabla: orders
-- Equivalente a ordenes
-- Tabla particionable por created_at.
-- Nota: para particionamiento declarativo, la PK incluye created_at.
-- =========================
CREATE TABLE orders (
    id BIGSERIAL NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users(id),
    total NUMERIC(12,2) NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,
    PRIMARY KEY (id, created_at),
    CONSTRAINT chk_orders_total
        CHECK (total >= 0),
    CONSTRAINT chk_orders_status
        CHECK (status IN ('CREATED', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'REFUNDED'))
) PARTITION BY RANGE (created_at);

-- =========================
-- Tabla: order_details
-- Equivalente a detalle_orden
-- FK compuesta porque orders está particionada por created_at.
-- =========================
CREATE TABLE order_details (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    order_created_at TIMESTAMP NOT NULL,
    product_id BIGINT NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    CONSTRAINT fk_order_details_orders
        FOREIGN KEY (order_id, order_created_at)
        REFERENCES orders(id, created_at)
        ON DELETE CASCADE,
    CONSTRAINT chk_order_details_quantity
        CHECK (quantity > 0),
    CONSTRAINT chk_order_details_unit_price
        CHECK (unit_price >= 0)
);

-- =========================
-- Tabla: payments
-- Equivalente a pagos
-- Tabla particionable por payment_date.
-- =========================
CREATE TABLE payments (
    id BIGSERIAL NOT NULL,
    order_id BIGINT NOT NULL,
    order_created_at TIMESTAMP NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_status VARCHAR(30) NOT NULL,
    external_reference VARCHAR(200),
    payment_date TIMESTAMP NOT NULL DEFAULT NOW(),
    amount NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (id, payment_date),
    CONSTRAINT fk_payments_orders
        FOREIGN KEY (order_id, order_created_at)
        REFERENCES orders(id, created_at)
        ON DELETE CASCADE,
    CONSTRAINT chk_payments_amount
        CHECK (amount >= 0),
    CONSTRAINT chk_payments_status
        CHECK (payment_status IN ('PENDING', 'APPROVED', 'REJECTED', 'REFUNDED', 'CANCELLED'))
) PARTITION BY RANGE (payment_date);

-- =========================
-- Tabla: shipments
-- Equivalente a envio
-- =========================
CREATE TABLE shipments (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    order_created_at TIMESTAMP NOT NULL,
    carrier VARCHAR(100),
    tracking_number VARCHAR(150),
    shipment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    estimated_delivery_at TIMESTAMP,
    CONSTRAINT fk_shipments_orders
        FOREIGN KEY (order_id, order_created_at)
        REFERENCES orders(id, created_at)
        ON DELETE CASCADE,
    CONSTRAINT chk_shipments_status
        CHECK (shipment_status IN ('PENDING', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'RETURNED'))
);

-- =========================
-- Tabla: reviews
-- Equivalente a resenas
-- =========================
CREATE TABLE reviews (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    product_id BIGINT NOT NULL REFERENCES products(id),
    order_id BIGINT NOT NULL,
    order_created_at TIMESTAMP NOT NULL,
    rating INTEGER NOT NULL,
    title VARCHAR(200),
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_reviews_orders
        FOREIGN KEY (order_id, order_created_at)
        REFERENCES orders(id, created_at)
        ON DELETE CASCADE,
    CONSTRAINT chk_reviews_rating
        CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT uq_user_product_order_review
        UNIQUE (user_id, product_id, order_id)
);

-- =========================
-- Tabla: transaction_history
-- Historial transaccional particionable
-- =========================
CREATE TABLE transaction_history (
    id BIGSERIAL NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    entity_id BIGINT NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- =========================
-- Tabla: sync_audit
-- Auditoría de sincronización PostgreSQL -> MongoDB
-- =========================
CREATE TABLE sync_audit (
    id BIGSERIAL PRIMARY KEY,
    sync_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL DEFAULT 'PostgreSQL',
    target_system VARCHAR(50) NOT NULL DEFAULT 'MongoDB',
    status VARCHAR(30) NOT NULL,
    records_processed INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMP,
    error_message TEXT,
    CONSTRAINT chk_sync_audit_status
        CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED'))
);