--- Historial de ordenes por cliente

SELECT customer_id, COUNT(*) AS total_orders
FROM ecommify.orders
GROUP BY customer_id
ORDER BY total_orders DESC
LIMIT 5;

--- Explain de la consulta anterior

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    SUM(oi.price + oi.freight_value) AS order_total
FROM ecommify.orders o
JOIN ecommify.order_items oi
    ON o.order_id = oi.order_id
WHERE o.customer_id = '68d03ff74911622915ef4ec24e2919a9'
GROUP BY
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp
ORDER BY o.order_purchase_timestamp DESC
LIMIT 20;


--- Ventas por categoria y mes

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    p.product_category_name,
    SUM(oi.price) AS revenue,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(*) AS total_items
FROM ecommify.orders o
JOIN ecommify.order_items oi
    ON o.order_id = oi.order_id
JOIN ecommify.products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp < '2019-01-01'
GROUP BY
    DATE_TRUNC('month', o.order_purchase_timestamp),
    p.product_category_name
ORDER BY revenue DESC
LIMIT 10;

--- Desempeño de vendedores por región

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS revenue,
    AVG(oi.price) AS avg_item_price
FROM ecommify.sellers s
JOIN ecommify.order_items oi
    ON s.seller_id = oi.seller_id
JOIN ecommify.orders o
    ON oi.order_id = o.order_id
WHERE s.seller_state = 'SP'
  AND o.order_status = 'delivered'
GROUP BY
    s.seller_state,
    s.seller_city
ORDER BY revenue DESC
LIMIT 10;

--- Productos con reseñas negativas

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.product_id,
    p.product_category_name,
    COUNT(r.review_internal_id) AS negative_reviews,
    AVG(r.review_score) AS avg_score
FROM ecommify.products p
JOIN ecommify.order_items oi
    ON p.product_id = oi.product_id
JOIN ecommify.reviews r
    ON oi.order_id = r.order_id
WHERE r.review_score <= 2
GROUP BY
    p.product_id,
    p.product_category_name
ORDER BY negative_reviews DESC
LIMIT 10;