# Actividad 2

# Documento Técnico de Implementación Optimizada

## Ecommify Platform

### PostgreSQL + MongoDB

## Autores

Daniel Porras
Oscar Clavijo
Camilo Porras

## Fecha

Junio de 2026

---

# 1. Resumen ejecutivo

El presente documento describe la implementación técnica optimizada de la plataforma **Ecommify**, una solución de comercio electrónico híbrida basada en el uso combinado de **PostgreSQL** y **MongoDB**.

La arquitectura propuesta separa los datos críticos transaccionales de los datos flexibles y analíticos. PostgreSQL se utiliza para entidades que requieren consistencia fuerte, integridad referencial y transacciones ACID, como usuarios, productos base, órdenes, pagos e inventario. MongoDB se utiliza para datos semiestructurados, catálogo extendido, reseñas, comportamiento de usuario, recomendaciones y análisis de alto volumen.

Durante la implementación se trabajó sobre ambos motores de base de datos utilizando el dataset público **Olist Brazilian E-Commerce**. En PostgreSQL se conservó el modelo relacional original mediante tablas normalizadas como `customers`, `sellers`, `products`, `orders`, `order_items`, `payments` y `reviews`. En MongoDB, el mismo dominio fue transformado a una estructura documental orientada a lectura y análisis, con colecciones como `product_catalog`, `product_reviews`, `sellers` y `user_behavior`.

Las principales optimizaciones aplicadas fueron:

* Creación del esquema relacional `ecommify` en Supabase.
* Carga del dataset Olist en tablas PostgreSQL normalizadas.
* Optimización de queries críticas en PostgreSQL con índices B-Tree.
* Evaluación de planes de ejecución con `EXPLAIN (ANALYZE, BUFFERS)`.
* Implementación de particionamiento por rango sobre `orders_partitioned`.
* Diseño de colecciones documentales flexibles en MongoDB.
* Transformación del dataset Olist al modelo documental de Ecommify.
* Creación de índices compuestos bajo la regla ESR.
* Creación de índices parciales para subconjuntos relevantes.
* Evaluación de productividad de índices con `.explain("executionStats")`.
* Optimización de aggregation pipelines.
* Diseño teórico de sharding y replica sets.
* Monitoreo mediante Atlas Metrics, Performance Advisor, `$indexStats` y métricas de ejecución.

Los resultados cuantitativos más destacados fueron:

| Optimización | Antes | Después | Mejora |
|---|---:|---:|---:|
| PostgreSQL - historial de órdenes por cliente | 15.442 ms | 9.210 ms | 40.36% |
| PostgreSQL - ventas por categoría y mes | 1902.142 ms | 395.193 ms | 79.22% |
| PostgreSQL - desempeño de vendedores por región | 424.708 ms | 397.821 ms | 6.33% |
| PostgreSQL - particionamiento órdenes 2018 | N/A | 26.825 ms | Partition pruning |
| MongoDB - índice ESR catálogo principal | 32.951 docs examinados | 1.854 docs examinados | Reducción significativa |
| MongoDB - índice productos más vendidos | 32.951 docs examinados | 2.219 docs examinados | Reducción significativa |
| MongoDB - índice parcial productos activos | 32.951 docs examinados | 120 docs examinados | Muy productivo |
| MongoDB - índice reseñas por producto | 102.172 docs examinados | 3 docs examinados | Muy productivo |
| MongoDB - pipeline analítico | 959.52 ms | 362.02 ms | 62.27% |

Estos resultados evidencian que las estrategias de indexación, validación de planes de ejecución, particionamiento y optimización de pipelines permiten reducir de manera importante el volumen de datos procesado y el tiempo promedio de ejecución.

---

# 2. Implementación PostgreSQL

## 2.1 Objetivo de PostgreSQL dentro de Ecommify

PostgreSQL se utilizó como motor relacional y transaccional dentro de la arquitectura híbrida de Ecommify. En esta implementación, PostgreSQL representa la estructura relacional original del dataset **Olist Brazilian E-Commerce**, conservando tablas normalizadas para clientes, vendedores, productos, órdenes, items de órdenes, pagos y reseñas.

A diferencia de MongoDB, donde se construyeron colecciones documentales y desnormalizadas para análisis y lectura rápida, PostgreSQL mantiene el modelo relacional con claves primarias, claves foráneas y consultas basadas en `JOIN`.

Las tablas implementadas fueron:

* `customers`
* `sellers`
* `products`
* `orders`
* `order_items`
* `payments`
* `reviews`

Esta decisión permite que ambos motores trabajen sobre el mismo dominio de negocio, pero con estructuras distintas según el propósito de cada tecnología: PostgreSQL para integridad relacional y MongoDB para flexibilidad documental y analítica.

---

## 2.2 Estructura del módulo PostgreSQL en el repositorio

La implementación PostgreSQL quedó organizada en la carpeta `postgresql/` del repositorio:

```text
postgresql/
├── ddl/
│   ├── 01_schema.sql
│   ├── 02_indexes.sql
│   └── 03_partitioning.sql
├── evidencias/
│   ├── reports/
├── notebooks/
│   └── metricas_optimizacion_indices.ipynb
├── queries/
│   ├── 01_queries_before_index.sql
│   └── 02_queries_after_indexes.sql
└── results/
    └── postgresql_preformance_results.csv
```

Esta estructura separa los scripts DDL, las consultas críticas, los resultados cuantitativos, las evidencias visuales y los reportes de planes de ejecución.

---

## 2.3 Scripts DDL ejecutados en Supabase

Los scripts DDL se encuentran en la carpeta:

```text
postgresql/ddl/
```

| Script | Descripción |
|---|---|
| `01_schema.sql` | Crea el esquema `ecommify` y las tablas principales del modelo relacional |
| `02_indexes.sql` | Crea los índices optimizados para las queries críticas |
| `03_partitioning.sql` | Crea la tabla particionada `orders_partitioned` por rango de fecha |

El script `01_schema.sql` creó el esquema `ecommify` y las tablas base:

```sql
CREATE SCHEMA IF NOT EXISTS ecommify;

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
```

Después de ejecutar el DDL en Supabase, se cargaron los archivos CSV del dataset Olist desde el módulo de importación de datos.

---

## 2.4 Carga de datos y conteos

Los archivos CSV se importaron en Supabase respetando el orden de dependencias entre tablas:

| Orden | Archivo CSV | Tabla destino |
|---:|---|---|
| 1 | `olist_customers_dataset.csv` | `ecommify.customers` |
| 2 | `olist_sellers_dataset.csv` | `ecommify.sellers` |
| 3 | `olist_products_dataset.csv` | `ecommify.products` |
| 4 | `olist_orders_dataset.csv` | `ecommify.orders` |
| 5 | `olist_order_items_dataset.csv` | `ecommify.order_items` |
| 6 | `olist_order_payments_dataset.csv` | `ecommify.payments` |
| 7 | `olist_order_reviews_dataset.csv` | `ecommify.reviews` |

Los conteos obtenidos después de la carga fueron:

| Tabla | Registros |
|---|---:|
| `customers` | 99.441 |
| `sellers` | 3.095 |
| `products` | 32.951 |
| `orders` | 99.441 |
| `order_items` | 112.650 |
| `payments` | 103.886 |
| `reviews` | 99.224 |

Las evidencias de creación del proyecto, ejecución del esquema, importación y conteos se encuentran en:

```text
postgresql/evidencias/01_Supabase.png
postgresql/evidencias/02_schema.png
postgresql/evidencias/03_import_data.png
postgresql/evidencias/04_conteos.png
```

---

## 2.5 Estrategia de indexación PostgreSQL

La estrategia de indexación se diseñó a partir de las queries críticas del negocio. Se priorizaron columnas utilizadas en filtros, joins, agrupamientos y ordenamientos.

Los índices implementados fueron:

```sql
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

-- Índices para reseñas negativas
CREATE INDEX IF NOT EXISTS idx_reviews_score_order
ON ecommify.reviews(review_score, order_id);

-- Índices analíticos adicionales
CREATE INDEX IF NOT EXISTS idx_order_items_price
ON ecommify.order_items(price);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
ON ecommify.payments(order_id);
```

---

## 2.6 Justificación técnica de índices PostgreSQL

| Índice | Tabla | Justificación |
|---|---|---|
| `idx_orders_customer_purchase_date` | `orders` | Optimiza la consulta de historial de órdenes por cliente y el ordenamiento por fecha |
| `idx_order_items_order_id` | `order_items` | Optimiza el join entre órdenes e items |
| `idx_orders_status_purchase_date` | `orders` | Optimiza filtros por estado de orden y rango de fecha |
| `idx_order_items_product_order` | `order_items` | Optimiza joins entre productos, órdenes e items |
| `idx_products_category` | `products` | Apoya agrupaciones y análisis por categoría |
| `idx_sellers_state_city` | `sellers` | Optimiza filtros geográficos por estado y ciudad del vendedor |
| `idx_order_items_seller_order` | `order_items` | Optimiza joins por vendedor y orden |
| `idx_reviews_score_order` | `reviews` | Optimiza filtros por calificación de reseña y relación con órdenes |
| `idx_order_items_price` | `order_items` | Apoya análisis por precio |
| `idx_payments_order_id` | `payments` | Optimiza relación entre pagos y órdenes |

Las evidencias de índices se encuentran en:

```text
postgresql/evidencias/before_indices.png
postgresql/evidencias/crear_indices.png
postgresql/evidencias/after_indices.png
```

---

## 2.7 Queries críticas PostgreSQL optimizadas

Se evaluaron cuatro queries críticas usando `EXPLAIN (ANALYZE, BUFFERS)` antes y después de aplicar los índices.

Las consultas antes de índices se encuentran en:

```text
postgresql/queries/01_queries_before_index.sql
```

Las consultas después de índices se encuentran en:

```text
postgresql/queries/02_queries_after_indexes.sql
```

Los planes de ejecución se almacenaron en:

```text
postgresql/evidencias/reports/
```

### Query crítica 1: historial de órdenes por cliente

Esta consulta obtiene las órdenes de un cliente específico, calcula el total de la orden y ordena por fecha de compra.

```sql
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
```

### Query crítica 2: ventas por categoría y mes

Esta consulta calcula ingresos por categoría y mes para órdenes entregadas durante el año 2018.

```sql
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
```

### Query crítica 3: desempeño de vendedores por región

Esta consulta analiza ingresos, cantidad de órdenes y precio promedio para vendedores del estado `SP`.

```sql
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
```

### Query crítica 4: productos con reseñas negativas

Esta consulta identifica productos con mayor cantidad de reseñas negativas.

```sql
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
```

---

## 2.8 Evidencias cuantitativas de mejora PostgreSQL

Los resultados obtenidos con `EXPLAIN (ANALYZE, BUFFERS)` fueron:

| Query crítica | Tiempo antes | Tiempo después | Mejora |
|---|---:|---:|---:|
| Historial de órdenes por cliente | 15.442 ms | 9.210 ms | 40.36% |
| Ventas por categoría y mes | 1902.142 ms | 395.193 ms | 79.22% |
| Desempeño de vendedores por región | 424.708 ms | 397.821 ms | 6.33% |
| Productos con reseñas negativas | 912.709 ms | 2408.446 ms | -163.87% |

La consulta de historial de órdenes por cliente mejoró porque el plan pasó de realizar un `Seq Scan` sobre `orders` a utilizar el índice `idx_orders_customer_purchase_date`. En el plan optimizado también se utilizó el índice `idx_order_items_order_id` para acceder a los items de la orden.

La consulta de ventas por categoría y mes obtuvo la mejora más significativa. El tiempo de ejecución se redujo de 1902.142 ms a 395.193 ms, debido al uso del índice `idx_orders_status_purchase_date` para filtrar órdenes entregadas dentro del rango de fechas evaluado.

La consulta de desempeño de vendedores por región presentó una mejora leve. Aunque el plan optimizado utilizó `Index Only Scan` sobre `order_items`, todavía se procesó un volumen alto de registros y se mantuvieron operaciones de tipo `Hash Join` y ordenamientos externos.

La consulta de productos con reseñas negativas no presentó mejora. El tiempo aumentó de 912.709 ms a 2408.446 ms. Este resultado evidencia que el índice `idx_reviews_score_order` no fue productivo para este patrón específico, ya que el filtro `review_score <= 2` retorna un volumen considerable de registros y tiene baja selectividad.

Los resultados consolidados se almacenaron en:

```text
postgresql/results/postgresql_preformance_results.csv
```

Las gráficas de mejora se almacenaron en:

```text
postgresql/evidencias/grafica_mejora_postgresql.png
postgresql/evidencias/Grafica_Metricas_Rendimiento.png
```

---

## 2.9 Particionamiento aplicado

Se implementó particionamiento por rango sobre `order_purchase_timestamp` mediante la tabla `orders_partitioned`.

El script se encuentra en:

```text
postgresql/ddl/03_partitioning.sql
```

El particionamiento se creó con particiones por año:

```sql
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
```

La consulta filtrada para el año 2018 utilizó un `Index Only Scan` sobre la partición `orders_2018`, evidenciando `partition pruning`. El tiempo de ejecución fue de 26.825 ms.

Las evidencias se encuentran en:

```text
postgresql/evidencias/crear_particiones.png
postgresql/evidencias/particiones_creadas.png
postgresql/evidencias/query_particionamiento_explain.png
postgresql/evidencias/reports/explain_partition_pruning.md
```

---

## 2.10 Evidencias PostgreSQL

| Evidencia | Archivo | Descripción |
|---|---|---|
| Proyecto Supabase | `postgresql/evidencias/01_Supabase.png` | Evidencia del proyecto creado en Supabase |
| DDL ejecutado | `postgresql/evidencias/02_schema.png` | Creación del esquema `ecommify` y tablas base |
| Carga de datos | `postgresql/evidencias/03_import_data.png` | Importación de archivos CSV del dataset Olist |
| Conteo de registros | `postgresql/evidencias/04_conteos.png` | Validación de registros cargados por tabla |
| Índices antes de optimizar | `postgresql/evidencias/before_indices.png` | Estado inicial con índices primarios |
| Script de índices | `postgresql/evidencias/crear_indices.png` | Ejecución de índices optimizados |
| Índices después de optimizar | `postgresql/evidencias/after_indices.png` | Índices creados para consultas críticas |
| Particionamiento | `postgresql/evidencias/crear_particiones.png` | Creación de tabla particionada por fecha |
| Particiones creadas | `postgresql/evidencias/particiones_creadas.png` | Evidencia de particiones por año |
| Partition pruning | `postgresql/evidencias/query_particionamiento_explain.png` | Consulta filtrada por año usando partición 2018 |
| EXPLAIN antes - órdenes por cliente | `postgresql/evidencias/reports/before_explain_ordenes_clientes.md` | Plan antes de aplicar índice |
| EXPLAIN después - órdenes por cliente | `postgresql/evidencias/reports/after_explain_ordenes_clientes.md` | Plan después usando índices |
| EXPLAIN antes - ventas por categoría y mes | `postgresql/evidencias/reports/before_explain_categoria_mes.md` | Plan antes de aplicar índices |
| EXPLAIN después - ventas por categoría y mes | `postgresql/evidencias/reports/after_explain_categoria_mes.md` | Plan después usando índice por estado y fecha |
| EXPLAIN antes - vendedores por región | `postgresql/evidencias/reports/before_explain_vendedores_region.md` | Plan antes de aplicar índices |
| EXPLAIN después - vendedores por región | `postgresql/evidencias/reports/after_explain_vendedores_region.md` | Plan después usando índice en `order_items` |
| EXPLAIN antes - reseñas negativas | `postgresql/evidencias/reports/before_explain_reseñas_negativas.md` | Plan antes de aplicar índice |
| EXPLAIN después - reseñas negativas | `postgresql/evidencias/reports/after_explain_reseñas_negativas.md` | Plan después con índice no productivo |
| Gráfica de mejora | `postgresql/evidencias/grafica_mejora_postgresql.png` | Comparación porcentual de mejora por consulta |
| Gráfica de métricas | `postgresql/evidencias/Grafica_Metricas_Rendimiento.png` | Comparación visual de métricas de rendimiento |

---

## 2.11 Interpretación final PostgreSQL

La implementación PostgreSQL permitió demostrar que los índices pueden mejorar de forma significativa el rendimiento cuando están alineados con los filtros y patrones reales de consulta. La consulta de ventas por categoría y mes fue la más beneficiada, con una mejora de 79.22%.

También se evidenció que no todos los índices son productivos. La consulta de productos con reseñas negativas empeoró después de aplicar el índice, lo cual demuestra la importancia de validar cada optimización con `EXPLAIN (ANALYZE, BUFFERS)`.

El particionamiento por fecha permitió evidenciar `partition pruning`, ya que PostgreSQL accedió únicamente a la partición correspondiente al año consultado.

En conclusión, la optimización en PostgreSQL debe basarse en evidencia cuantitativa y no únicamente en la creación de índices. Los planes de ejecución permitieron identificar mejoras claras, mejoras limitadas y casos donde el índice no fue conveniente.

---


# 3. Implementación MongoDB

## 3.1 Objetivo de MongoDB dentro de Ecommify

MongoDB se utiliza para administrar información flexible, semiestructurada y de alto volumen. En Ecommify, MongoDB soporta:

* Catálogo extendido de productos.
* Reseñas completas.
* Vendedores.
* Comportamiento de usuario.
* Recomendaciones.
* Logs de búsqueda.

Para esta implementación se utilizó el dataset Olist Brazilian E-Commerce, descargado con `kagglehub`, y transformado a la estructura documental definida para Ecommify.

---

## 3.2 Colecciones creadas

| Colección         | Descripción                              |
| ----------------- | ---------------------------------------- |
| `product_catalog` | Catálogo extendido de productos          |
| `product_reviews` | Reseñas completas asociadas a productos  |
| `sellers`         | Información de vendedores                |
| `user_behavior`   | Eventos simulados de navegación y compra |
| `search_logs`     | Colección propuesta para búsquedas       |
| `recommendations` | Colección propuesta para recomendaciones |

---

## 3.3 Esquema documental `product_catalog`

Ejemplo de documento:

```json
{
  "_id": "product_id",
  "name": "category product",
  "description": "Producto importado desde Olist",
  "category": "bed_bath_table",
  "price": 120.5,
  "currency": "BRL",
  "seller_id": "seller_id",
  "seller_region": "SP",
  "seller_city": "sao paulo",
  "status": "ACTIVE",
  "attributes": {
    "weight_g": 500,
    "length_cm": 20,
    "height_cm": 10,
    "width_cm": 15,
    "photos_qty": 2
  },
  "tags": [
    "bed_bath_table",
    "olist",
    "ecommify",
    "catalog"
  ],
  "ratings": {
    "average": 4.5,
    "count": 10
  },
  "metrics": {
    "total_units_sold": 5,
    "views_count": 50,
    "conversion_rate": 0.05,
    "total_revenue": 600.0
  },
  "source": {
    "dataset": "olistbr/brazilian-ecommerce"
  }
}
```

---

## 3.4 Índices implementados en MongoDB

| Colección         | Índice                                           | Tipo          | Objetivo                                                          |
| ----------------- | ------------------------------------------------ | ------------- | ----------------------------------------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Compuesto ESR | Optimizar catálogo por categoría, región, estado, rating y precio |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Compuesto ESR | Optimizar ranking de productos más vendidos                       |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Parcial       | Optimizar productos activos con reseñas suficientes               |
| `product_catalog` | `idx_pc_text_name_description_tags`              | Texto         | Habilitar búsqueda full-text                                      |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Simple        | Optimizar reseñas por producto y `$lookup`                        |
| `product_reviews` | `idx_pr_rating_created_at`                       | Compuesto     | Optimizar análisis de reseñas negativas recientes                 |
| `user_behavior`   | `idx_ub_user_period`                             | Compuesto     | Optimizar eventos por usuario y periodo                           |
| `user_behavior`   | `idx_ub_event_type_period`                       | Multikey      | Optimizar eventos por tipo                                        |
| `sellers`         | `idx_sellers_region_city`                        | Compuesto     | Optimizar análisis geográfico                                     |

---

## 3.5 Evidencias cuantitativas de índices MongoDB

| Colección         | Índice evaluado                                  | Consulta                                                | Docs antes | Docs después | Tiempo antes | Tiempo después | Resultado                           |
| ----------------- | ------------------------------------------------ | ------------------------------------------------------- | ---------: | -----------: | -----------: | -------------: | ----------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Catálogo por categoría, región, estado, rating y precio |     32.951 |        1.854 |        30 ms |           6 ms | Productivo                          |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Productos activos más vendidos                          |     32.951 |        2.219 |        30 ms |           7 ms | Productivo                          |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Productos activos con reseñas suficientes               |     32.951 |          120 |        27 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `product_id_1`                                   | Reseñas por producto                                    |    102.172 |            3 |        97 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `idx_pr_rating_created_at`                       | Reseñas negativas recientes                             |    102.172 |       15.275 |        78 ms |          74 ms | Productivo en documentos examinados |
| `user_behavior`   | `idx_ub_event_type_period`                       | Eventos PURCHASE                                        |    112.650 |      112.650 |       176 ms |         190 ms | Baja productividad                  |
| `sellers`         | `idx_sellers_region_city`                        | Vendedores por región y ciudad                          |      1.849 |           41 |         2 ms |           1 ms | Muy productivo                      |

---

## 3.6 Interpretación de resultados MongoDB

La evaluación con `.explain("executionStats")` permitió identificar qué índices fueron realmente productivos.

En `product_catalog`, los índices ESR redujeron de forma importante los documentos examinados. El índice principal del catálogo pasó de 32.951 documentos examinados a 1.854, reduciendo el tiempo de ejecución de 30 ms a 6 ms. El índice parcial fue el más eficiente, al reducir de 32.951 documentos examinados a solo 120.

En `product_reviews`, el índice por `product_id` fue altamente productivo porque redujo una consulta de 102.172 documentos examinados a solo 3 documentos. Este índice es fundamental para consultas de reseñas por producto y para operaciones `$lookup`.

En `user_behavior`, el índice sobre `events.type` no mostró mejora para eventos `PURCHASE`, debido a que este evento aparece en una proporción muy alta de documentos. Esto evidencia que no todo índice es productivo si el campo tiene baja selectividad.

En `sellers`, el índice compuesto por región y ciudad fue eficiente, reduciendo los documentos examinados de 1.849 a 41.

---

## 3.7 Aggregation pipeline optimizado

Se desarrolló un pipeline analítico sobre `product_catalog` y `product_reviews` para evaluar desempeño comercial por categoría y región.

El pipeline incluye:

* `$match`
* `$lookup`
* `$unwind`, en versión original
* `$group`
* `$addFields`
* `$project`
* `$sort`
* `$limit`

La versión optimizada aplicó:

* `$match` temprano.
* `$project` temprano.
* Uso de índices.
* Reemplazo de `$unwind` por `$size` para conteo de reseñas.
* `allowDiskUse=True`.

Resultados:

| Pipeline            | Tiempo promedio | Documentos retornados | Mejora |
| ------------------- | --------------: | --------------------: | -----: |
| Pipeline original   |       959.52 ms |                    10 |     0% |
| Pipeline optimizado |       362.02 ms |                    10 | 62.27% |

La optimización redujo el tiempo promedio de ejecución en 62.27%, principalmente por la reducción de documentos intermedios y la proyección temprana de campos.

---

## 3.8 Diseño teórico de sharding y replica sets

Para `product_catalog` se propone la siguiente shard key:

```javascript
{
  "category": 1,
  "seller_region": 1,
  "_id": "hashed"
}
```

Justificación:

* `category` optimiza consultas frecuentes del catálogo.
* `seller_region` permite segmentación geográfica.
* `_id hashed` mejora distribución entre shards.

Comandos teóricos:

```javascript
sh.enableSharding("ecommify_db")

db.product_catalog.createIndex({
  "category": 1,
  "seller_region": 1,
  "_id": "hashed"
})

sh.shardCollection(
  "ecommify_db.product_catalog",
  {
    "category": 1,
    "seller_region": 1,
    "_id": "hashed"
  }
)
```

Debido a las limitaciones del Free Tier, estos comandos no fueron ejecutados; se documentan como diseño teórico.

Replica set propuesto:

| Nodo          | Rol       | Zona | Función                          |
| ------------- | --------- | ---- | -------------------------------- |
| `mongo-rs-01` | Primary   | AZ-1 | Recibe escrituras                |
| `mongo-rs-02` | Secondary | AZ-2 | Replica datos y atiende lecturas |
| `mongo-rs-03` | Secondary | AZ-3 | Replica datos y permite failover |

---

## 3.9 Estrategias Read/Write Concern

| Operación                | Colección         | Read Preference      | Write Concern | Justificación                      |
| ------------------------ | ----------------- | -------------------- | ------------- | ---------------------------------- |
| Consulta catálogo        | `product_catalog` | `secondaryPreferred` | No aplica     | Reduce carga del Primary           |
| Crear producto           | `product_catalog` | `primary`            | `majority`    | Requiere durabilidad               |
| Actualizar precio        | `product_catalog` | `primary`            | `majority`    | Dato sensible                      |
| Registrar reseña         | `product_reviews` | `primary`            | `majority`    | Visible para usuarios              |
| Consultar reseñas        | `product_reviews` | `secondaryPreferred` | No aplica     | Tolera consistencia eventual       |
| Registrar navegación     | `user_behavior`   | No aplica            | `w:1`         | Evento masivo                      |
| Analítica comportamiento | `user_behavior`   | `secondary`          | No aplica     | No requiere consistencia inmediata |
| Recomendaciones          | `recommendations` | `secondary`          | `w:1`         | Reprocesable                       |

---

# 4. Evidencias cuantitativas de mejoras de rendimiento

## 4.1 Evidencias MongoDB

Las métricas principales utilizadas fueron:

* `nReturned`
* `totalDocsExamined`
* `totalKeysExamined`
* `executionTimeMillis`
* `docsPerReturned`
* tiempo promedio de pipeline

Los resultados demuestran que las optimizaciones redujeron documentos examinados y mejoraron tiempos de ejecución en consultas críticas.

## 4.2 Evidencias PostgreSQL

En PostgreSQL se utilizaron métricas obtenidas mediante `EXPLAIN (ANALYZE, BUFFERS)`. Las métricas principales fueron:

* Tiempo de ejecución.
* Tipo de scan utilizado.
* Uso de índices.
* Buffers utilizados.
* Filas procesadas.
* Cambios en el plan de ejecución antes y después de aplicar índices.

Los resultados consolidados fueron:

| Query crítica | Tiempo antes | Tiempo después | Mejora | Interpretación |
|---|---:|---:|---:|---|
| Historial de órdenes por cliente | 15.442 ms | 9.210 ms | 40.36% | Mejora por uso de índice sobre `customer_id` y fecha |
| Ventas por categoría y mes | 1902.142 ms | 395.193 ms | 79.22% | Mejora significativa por índice sobre estado y fecha de orden |
| Desempeño de vendedores por región | 424.708 ms | 397.821 ms | 6.33% | Mejora leve por uso de índice en `order_items` |
| Productos con reseñas negativas | 912.709 ms | 2408.446 ms | -163.87% | Índice no productivo por baja selectividad |
| Órdenes particionadas por año | N/A | 26.825 ms | N/A | Evidencia de partition pruning sobre `orders_2018` |

La consulta de ventas por categoría y mes presentó la mejora más representativa, reduciendo su tiempo de ejecución de 1902.142 ms a 395.193 ms. Este resultado se explica por el uso del índice `idx_orders_status_purchase_date`, el cual permite filtrar de forma más eficiente las órdenes entregadas dentro del rango de fechas analizado.

La consulta de historial de órdenes por cliente también mejoró, pasando de 15.442 ms a 9.210 ms. El plan optimizado utilizó el índice `idx_orders_customer_purchase_date` sobre la tabla `orders` y el índice `idx_order_items_order_id` sobre `order_items`.

La consulta de desempeño de vendedores por región tuvo una mejora leve. Aunque el plan optimizado utilizó `Index Only Scan` sobre `order_items`, la consulta continuó procesando un volumen alto de registros y mantuvo operaciones de tipo `Hash Join`.

La consulta de productos con reseñas negativas no mejoró. El índice `idx_reviews_score_order` produjo un tiempo mayor que el plan original. Esto evidencia que el filtro `review_score <= 2` tiene baja selectividad y retorna un volumen considerable de registros, por lo cual el índice no fue conveniente para ese patrón de consulta.

El particionamiento por rango permitió validar `partition pruning`. La consulta sobre órdenes del año 2018 utilizó un `Index Only Scan` sobre la partición `orders_2018`, con un tiempo de ejecución de 26.825 ms.

Los resultados de PostgreSQL se encuentran en:

```text
postgresql/results/postgresql_preformance_results.csv
```

Las evidencias se encuentran en:

```text
postgresql/evidencias/
postgresql/evidencias/reports/
```


---

# 5. Sincronización entre PostgreSQL y MongoDB

La arquitectura de Ecommify propone una sincronización basada en eventos de dominio.

## 5.1 Flujo de producto

1. Producto base se registra en PostgreSQL.
2. Se emite evento `PRODUCT_CREATED`.
3. El servicio de catálogo consume el evento.
4. MongoDB actualiza `product_catalog`.
5. El producto queda disponible para consultas flexibles.

## 5.2 Flujo de orden

1. Usuario crea orden.
2. PostgreSQL almacena la transacción.
3. Se emite evento `ORDER_CREATED`.
4. MongoDB actualiza métricas de producto y comportamiento.
5. El motor analítico actualiza recomendaciones.

## 5.3 Estrategia de consistencia

La consistencia fuerte se mantiene en PostgreSQL para operaciones críticas. MongoDB trabaja con consistencia eventual para catálogo extendido, analítica y recomendaciones.

Para mitigar inconsistencias:

* Eventos idempotentes.
* Reprocesamiento asíncrono.
* Lecturas desde Primary en cambios críticos del catálogo.
* Write Concern `majority` en operaciones visibles al usuario.
* Monitoreo de replication lag.

---

# 6. Lecciones aprendidas

## 6.1 Obstáculos encontrados

Durante la implementación se identificaron los siguientes obstáculos:

1. El dataset Olist tiene una estructura relacional y fue necesario transformarlo al modelo documental de Ecommify.
2. Al insertar reseñas se presentaron duplicados de `_id`, solucionados con limpieza por `review_id + product_id`.
3. Algunos índices ya existían con nombres automáticos, por ejemplo `product_id_1`, lo que generó conflictos al intentar crearlos con otro nombre.
4. En Google Colab se intentaron ejecutar comandos de Mongo Shell como `createIndex()` y fue necesario ajustarlos a PyMongo con `create_index()`.
5. El cluster gratuito M0 no permite ejecutar sharding real.
6. Algunos índices no fueron productivos por baja selectividad, como el caso de `events.type = PURCHASE`.

## 6.2 Soluciones aplicadas

| Obstáculo                       | Solución                                                |
| ------------------------------- | ------------------------------------------------------- |
| Dataset relacional              | Transformación a colecciones documentales               |
| Duplicados en reseñas           | Eliminación de duplicados antes de insertar             |
| Conflicto de índices existentes | Reutilización del nombre real del índice                |
| Sintaxis Mongo Shell en Colab   | Conversión a PyMongo                                    |
| Limitaciones Free Tier          | Documentación teórica de sharding                       |
| Índices poco selectivos         | Evaluación con `.explain()` y análisis de productividad |

## 6.3 Limitaciones del Free Tier

MongoDB Atlas Free Tier permitió validar conexión, carga de datos, índices, consultas y pipelines. Sin embargo, presentó limitaciones para:

* Sharding real.
* Configuración avanzada de replica sets.
* Métricas avanzadas de monitoreo.
* Pruebas de carga a gran escala.
* Simulación real de arquitectura multi-AZ productiva.

Como workaround se implementaron:

* Simulación de distribución across shards.
* Diseño teórico de sharding.
* Evaluación con `.explain("executionStats")`.
* Uso de `$indexStats`.
* Medición de tiempos desde notebook.

---

# 7. Conclusiones

La implementación optimizada de Ecommify demuestra la utilidad de una arquitectura híbrida basada en PostgreSQL y MongoDB.

PostgreSQL permite mantener integridad y consistencia fuerte en las operaciones críticas del negocio, como clientes, órdenes, pagos, productos, vendedores, items de orden y reseñas. MongoDB aporta flexibilidad y escalabilidad para catálogo extendido, reseñas enriquecidas, comportamiento de usuario y analítica.

Las optimizaciones realizadas en PostgreSQL mostraron mejoras cuantitativas importantes en consultas críticas. La consulta de ventas por categoría y mes redujo su tiempo de ejecución de 1902.142 ms a 395.193 ms, equivalente a una mejora de 79.22%. La consulta de historial de órdenes por cliente mejoró 40.36%. Además, el particionamiento por rango permitió evidenciar `partition pruning` sobre la partición `orders_2018`.

Las optimizaciones realizadas en MongoDB también mostraron mejoras significativas. Los índices ESR, parciales y de relación redujeron de forma importante los documentos examinados. El pipeline analítico optimizado redujo el tiempo promedio de ejecución en 62.27%.

La evaluación permitió identificar que no todos los índices son útiles. En PostgreSQL, el índice sobre reseñas negativas no fue productivo para el patrón evaluado. En MongoDB, el índice sobre `events.type` presentó baja productividad para eventos `PURCHASE`. En ambos casos, la productividad dependió de la selectividad del campo y del patrón real de consulta.

Finalmente, el diseño teórico de sharding y replica sets proporciona una base para escalar la solución en un ambiente productivo, mientras que la sincronización basada en eventos permite mantener desacoplados los sistemas PostgreSQL y MongoDB.
