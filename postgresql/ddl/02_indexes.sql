-- Consulta de indices:

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'ecommify'
ORDER BY tablename, indexname;


-- Índices para historial de órdenes por cliente
CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase_date
ON ecommify.orders(customer_id, order_purchase_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
ON ecommify.order_items(order_id);

-- Índices para ventas por categoría y mes
CREATE INDEX IF NOT EXISTS idx_orders_status_purchase_date
ON ecommify.orders(order_status, order_purchase_timestamp);

CREATE INDEX IF NOT EXISTS idx_order_items_product_order
ON ecommify.order_items(product_id, order_id);

CREATE INDEX IF NOT EXISTS idx_products_category
ON ecommify.products(product_category_name);

-- Índices para desempeño de vendedores por región
CREATE INDEX IF NOT EXISTS idx_sellers_state_city
ON ecommify.sellers(seller_state, seller_city);

CREATE INDEX IF NOT EXISTS idx_order_items_seller_order
ON ecommify.order_items(seller_id, order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_seller_order_price
ON ecommify.order_items(seller_id, order_id, price);

-- Índices para reseñas negativas
CREATE INDEX IF NOT EXISTS idx_reviews_score_order
ON ecommify.reviews(review_score, order_id);

-- Índices analíticos adicionales
CREATE INDEX IF NOT EXISTS idx_order_items_price
ON ecommify.order_items(price);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
ON ecommify.payments(order_id);