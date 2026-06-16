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

MongoDB fue utilizado como motor documental para almacenar información flexible, semiestructurada y de alto volumen dentro de la arquitectura híbrida de Ecommify.

Mientras PostgreSQL conserva los datos transaccionales críticos, MongoDB soporta componentes orientados a lectura, analítica y flexibilidad estructural, tales como catálogo extendido, reseñas, comportamiento de usuario, métricas comerciales y recomendaciones.

La implementación se realizó en MongoDB Atlas utilizando Google Colab y PyMongo. Como fuente de datos se utilizó el dataset Olist Brazilian E-Commerce, el cual fue transformado desde un modelo relacional hacia un modelo documental adaptado al caso Ecommify.

---

## 3.2 Colecciones creadas

Durante la implementación se crearon las siguientes colecciones principales:

| Colección         | Descripción                                                                        | Fuente de datos                                       |
| ----------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `product_catalog` | Catálogo extendido de productos con atributos flexibles, métricas y calificaciones | Productos, sellers, órdenes, items y reseñas de Olist |
| `product_reviews` | Reseñas completas asociadas a productos                                            | Reseñas y órdenes de Olist                            |
| `sellers`         | Información de vendedores y ubicación geográfica                                   | Sellers de Olist                                      |
| `user_behavior`   | Eventos simulados de navegación, carrito y compra                                  | Órdenes, clientes e items de Olist                    |
| `search_logs`     | Colección propuesta para historial de búsquedas                                    | Diseño teórico                                        |
| `recommendations` | Colección propuesta para recomendaciones generadas                                 | Diseño teórico                                        |

Las colecciones implementadas permiten representar el catálogo flexible de Ecommify, manteniendo relaciones lógicas mediante identificadores como `product_id`, `seller_id` y `userId`.

---

## 3.3 Esquema documental de `product_catalog`

La colección `product_catalog` representa el catálogo extendido de productos. Cada documento almacena información común del producto, atributos variables, métricas comerciales y datos precalculados para optimizar consultas de lectura.

Ejemplo de documento:

```json
{
  "_id": "product_id",
  "name": "bed_bath_table product",
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
    "photos_qty": 2,
    "name_length": 40,
    "description_length": 300
  },
  "tags": [
    "bed_bath_table",
    "olist",
    "ecommify",
    "catalog"
  ],
  "images": [],
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
  "recent_reviews": [],
  "source": {
    "dataset": "olistbr/brazilian-ecommerce"
  },
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### Justificación del diseño

El diseño de `product_catalog` combina datos embebidos y datos referenciados.

Se embeben campos consultados frecuentemente, como:

* `attributes`
* `tags`
* `ratings`
* `metrics`
* `seller_region`
* `seller_city`

Se referencian entidades de alto crecimiento, como reseñas completas y eventos de comportamiento, mediante colecciones separadas como `product_reviews` y `user_behavior`.

Este enfoque permite mejorar el rendimiento de lectura sin generar documentos excesivamente grandes.

---

## 3.4 Esquema documental de `product_reviews`

La colección `product_reviews` almacena las reseñas completas de productos. Se relaciona con `product_catalog` mediante el campo `product_id`.

Ejemplo de documento:

```json
{
  "_id": "review_id_product_id",
  "review_id": "review_id",
  "product_id": "product_id",
  "order_id": "order_id",
  "rating": 5,
  "comment_title": "Buen producto",
  "comment_message": "El producto cumple con lo esperado",
  "verified_purchase": true,
  "created_at": "datetime"
}
```

### Justificación

Las reseñas pueden crecer de forma considerable para productos populares. Por esta razón, no se almacenan todas dentro de `product_catalog`. En su lugar, se utiliza una colección separada con índice sobre `product_id`, permitiendo consultar reseñas completas cuando sea necesario.

---

## 3.5 Esquema documental de `sellers`

La colección `sellers` almacena información de vendedores.

Ejemplo de documento:

```json
{
  "_id": "seller_id",
  "seller_id": "seller_id",
  "city": "sao paulo",
  "region": "SP",
  "country": "BR"
}
```

Esta colección permite realizar análisis geográficos y segmentación de vendedores por región y ciudad.

---

## 3.6 Esquema documental de `user_behavior`

La colección `user_behavior` almacena eventos de comportamiento agrupados por usuario y periodo. Esta estructura aplica el Bucket Pattern, ya que agrupa eventos históricos para reducir el crecimiento descontrolado de documentos individuales.

Ejemplo de documento:

```json
{
  "_id": "user_period",
  "userId": "customer_id",
  "period": "2018-05",
  "events": [
    {
      "type": "VIEW_PRODUCT",
      "productId": "product_id",
      "timestamp": "datetime"
    },
    {
      "type": "ADD_TO_CART",
      "productId": "product_id",
      "timestamp": "datetime"
    },
    {
      "type": "PURCHASE",
      "productId": "product_id",
      "timestamp": "datetime"
    }
  ]
}
```

### Justificación

El comportamiento de usuario tiene alto volumen y crecimiento continuo. Agrupar eventos por usuario y periodo permite manejar mejor la escritura y facilita análisis por ventanas temporales.

---

## 3.7 Patrones de modelado aplicados

| Patrón                | Aplicación en Ecommify                                                                  | Justificación                                                       |
| --------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Computed Pattern      | `ratings.average`, `ratings.count`, `metrics.total_units_sold`, `metrics.total_revenue` | Evita recalcular métricas en cada consulta                          |
| Subset Pattern        | `recent_reviews` dentro de `product_catalog`                                            | Permite mostrar reseñas destacadas sin traer todo el historial      |
| Approximation Pattern | `views_count`, `conversion_rate`                                                        | Reduce escrituras frecuentes sobre métricas de alta actividad       |
| Polymorphic Pattern   | `attributes` variable por categoría                                                     | Permite productos con estructuras diferentes en una misma colección |
| Bucket Pattern        | `user_behavior` agrupado por usuario y periodo                                          | Organiza eventos históricos de alto volumen                         |

---

## 3.8 Índices implementados con justificación

La estrategia de indexación se diseñó a partir de los patrones de consulta del catálogo, reseñas, comportamiento de usuario y análisis geográfico.

| Colección         | Índice                                           | Tipo               | Justificación                                                                               |
| ----------------- | ------------------------------------------------ | ------------------ | ------------------------------------------------------------------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Compuesto ESR      | Optimiza consultas por categoría, región, estado, ordenamiento por rating y rango de precio |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Compuesto ESR      | Optimiza ranking de productos activos más vendidos                                          |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Parcial            | Reduce el índice a productos activos con suficientes reseñas                                |
| `product_catalog` | `idx_pc_text_name_description_tags`              | Texto              | Permite búsqueda full-text por nombre, descripción y etiquetas                              |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Simple             | Optimiza consulta de reseñas por producto y operaciones `$lookup`                           |
| `product_reviews` | `idx_pr_partial_verified_product_rating`         | Parcial            | Optimiza reseñas verificadas por producto y calificación                                    |
| `product_reviews` | `idx_pr_rating_created_at`                       | Compuesto          | Optimiza análisis de reseñas negativas recientes                                            |
| `user_behavior`   | `idx_ub_user_period`                             | Compuesto          | Optimiza consultas de comportamiento por usuario y periodo                                  |
| `user_behavior`   | `idx_ub_event_type_period`                       | Multikey compuesto | Permite analizar eventos por tipo y periodo                                                 |
| `sellers`         | `idx_sellers_region`                             | Simple             | Optimiza filtros por región                                                                 |
| `sellers`         | `idx_sellers_region_city`                        | Compuesto          | Optimiza análisis jerárquico por región y ciudad                                            |

---

## 3.9 Evidencias de mejora con `.explain("executionStats")`

La evaluación de índices se realizó con `.explain("executionStats")`, comparando las métricas principales antes y después de aplicar índices.

Las métricas utilizadas fueron:

| Métrica               | Descripción                                       |
| --------------------- | ------------------------------------------------- |
| `nReturned`           | Cantidad de documentos retornados                 |
| `totalDocsExamined`   | Cantidad de documentos examinados                 |
| `totalKeysExamined`   | Cantidad de claves de índice examinadas           |
| `executionTimeMillis` | Tiempo de ejecución en milisegundos               |
| `docsPerReturned`     | Relación entre documentos examinados y retornados |

### Resultados principales

| Colección         | Índice evaluado                                  | Consulta evaluada                                       | Docs examinados antes | Docs examinados después | Tiempo antes | Tiempo después | Resultado                           |
| ----------------- | ------------------------------------------------ | ------------------------------------------------------- | --------------------: | ----------------------: | -----------: | -------------: | ----------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Catálogo por categoría, región, estado, rating y precio |                32.951 |                   1.854 |        30 ms |           6 ms | Productivo                          |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Productos activos más vendidos por categoría y precio   |                32.951 |                   2.219 |        30 ms |           7 ms | Productivo                          |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Productos activos con reseñas suficientes               |                32.951 |                     120 |        27 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Reseñas por producto                                    |               102.172 |                       3 |        97 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `idx_pr_rating_created_at`                       | Reseñas negativas recientes                             |               102.172 |                  15.275 |        78 ms |          74 ms | Productivo en documentos examinados |
| `user_behavior`   | `idx_ub_event_type_period`                       | Eventos `PURCHASE`                                      |               112.650 |                 112.650 |       176 ms |         190 ms | Baja productividad                  |
| `sellers`         | `idx_sellers_region_city`                        | Vendedores por región y ciudad                          |                 1.849 |                      41 |         2 ms |           1 ms | Muy productivo                      |

### Interpretación

Los índices más productivos fueron los asociados a consultas selectivas.

En `product_catalog`, el índice ESR principal redujo los documentos examinados de 32.951 a 1.854, disminuyendo el tiempo de 30 ms a 6 ms. El índice parcial fue aún más eficiente, al reducir los documentos examinados de 32.951 a 120.

En `product_reviews`, el índice por `product_id` fue fundamental. La consulta pasó de examinar 102.172 documentos a solo 3, reduciendo el tiempo de 97 ms a 1 ms.

En `user_behavior`, el índice sobre `events.type` no presentó mejora porque el evento `PURCHASE` aparece en una proporción muy alta de documentos. Esto evidencia que la selectividad del campo es determinante para que un índice sea productivo.

En `sellers`, el índice compuesto por región y ciudad redujo los documentos examinados de 1.849 a 41.

---

## 3.10 Aggregation pipeline optimizado

Se desarrolló un pipeline complejo sobre `product_catalog` y `product_reviews` para analizar el desempeño comercial de productos agrupados por categoría y región del vendedor.

El pipeline cumple con la complejidad mínima requerida, ya que incluye más de cinco stages y utiliza filtrado, relación entre colecciones, agrupación, transformación, proyección y ordenamiento.

### Stages utilizados

| Stage        | Uso                                                                     |
| ------------ | ----------------------------------------------------------------------- |
| `$match`     | Filtra productos activos por categoría y rango de precio                |
| `$lookup`    | Relaciona `product_catalog` con `product_reviews` mediante `product_id` |
| `$unwind`    | Utilizado en la versión original para procesar reseñas individualmente  |
| `$group`     | Agrupa por categoría y región del vendedor                              |
| `$addFields` | Calcula el indicador `sales_score`                                      |
| `$project`   | Reduce y transforma los campos de salida                                |
| `$sort`      | Ordena los resultados por `sales_score`                                 |
| `$limit`     | Limita la salida a los 10 mejores resultados                            |

### Técnicas de optimización aplicadas

Las optimizaciones aplicadas fueron:

1. Ubicación de `$match` al inicio del pipeline.
2. Uso de índices sobre campos filtrados y relacionados.
3. Proyección temprana mediante `$project`.
4. Reemplazo de `$unwind` por `$size` para contar reseñas sin multiplicar documentos.
5. Configuración de `allowDiskUse=True`.

### Resultado de la medición

| Pipeline            | Tiempo promedio | Documentos retornados | Mejora vs original |
| ------------------- | --------------: | --------------------: | -----------------: |
| Pipeline original   |       959.52 ms |                    10 |                 0% |
| Pipeline optimizado |       362.02 ms |                    10 |             62.27% |

### Interpretación

El pipeline optimizado redujo el tiempo promedio de ejecución de 959.52 ms a 362.02 ms, obteniendo una mejora de 62.27%.

La mejora se explica por la reducción del volumen de datos procesado en etapas intermedias. Al aplicar `$project` inmediatamente después de `$match`, el pipeline conserva únicamente los campos necesarios. Además, el uso de `$size` sobre el arreglo `reviews` evita la multiplicación de documentos generada por `$unwind`.

---

## 3.11 Diseño teórico de sharding

El diseño de sharding se documenta de forma teórica debido a que el ambiente utilizado corresponde a MongoDB Atlas Free Tier. Este entorno permite validar consultas, índices y pipelines, pero no permite implementar un sharded cluster real.

### Shard key final para `product_catalog`

Para la colección `product_catalog` se propone la siguiente shard key compuesta:

```javascript
{
  "category": 1,
  "seller_region": 1,
  "_id": "hashed"
}
```

### Justificación

| Campo           | Justificación                                                  |
| --------------- | -------------------------------------------------------------- |
| `category`      | Optimiza consultas frecuentes por categoría de producto        |
| `seller_region` | Permite segmentación y análisis regional                       |
| `_id hashed`    | Mejora la distribución uniforme entre shards y reduce hotspots |

Esta shard key busca balancear eficiencia de consulta y distribución de datos. Usar únicamente `category` podría generar concentración en categorías populares. Usar únicamente `_id hashed` distribuiría bien los documentos, pero no favorecería consultas frecuentes del catálogo. Por esta razón se selecciona una clave compuesta.

### Configuración teórica

En un ambiente productivo, la configuración se realizaría así:

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

Estos comandos no se ejecutaron en el cluster gratuito. Se documentan como referencia para una arquitectura productiva.

### Sharding propuesto para otras colecciones

| Colección         | Shard key propuesta                                | Justificación                                                   |
| ----------------- | -------------------------------------------------- | --------------------------------------------------------------- |
| `product_catalog` | `{ category: 1, seller_region: 1, _id: "hashed" }` | Balance entre consultas de catálogo y distribución              |
| `product_reviews` | `{ product_id: "hashed" }`                         | Distribuye reseñas y evita concentración en productos populares |
| `user_behavior`   | `{ userId: "hashed", period: 1 }`                  | Distribuye usuarios y organiza eventos por periodo              |
| `search_logs`     | `{ created_at: 1, _id: "hashed" }`                 | Permite consultas temporales y distribución uniforme            |
| `recommendations` | `{ user_id: "hashed" }`                            | Optimiza recomendaciones por usuario                            |

---

## 3.12 Diseño teórico de replica sets

Se propone un replica set de tres nodos distribuidos en diferentes zonas de disponibilidad.

| Nodo          | Rol       | Zona | Función                                      |
| ------------- | --------- | ---- | -------------------------------------------- |
| `mongo-rs-01` | Primary   | AZ-1 | Recibe escrituras                            |
| `mongo-rs-02` | Secondary | AZ-2 | Replica datos y atiende lecturas no críticas |
| `mongo-rs-03` | Secondary | AZ-3 | Replica datos y permite failover             |

Esta configuración permite alta disponibilidad. Si el nodo Primary falla, los nodos Secondary pueden elegir automáticamente un nuevo Primary.

No se recomienda utilizar Arbiter para esta arquitectura, ya que un Arbiter participa en elecciones pero no almacena datos. Para Ecommify es preferible contar con tres nodos completos con datos replicados.

---

## 3.13 Read Preference y Write Concern

Las estrategias de lectura y escritura se diferencian según la criticidad de cada operación.

| Operación                    | Colección         | Read Preference      | Write Concern | Justificación                      |
| ---------------------------- | ----------------- | -------------------- | ------------- | ---------------------------------- |
| Consulta general de catálogo | `product_catalog` | `secondaryPreferred` | No aplica     | Reduce carga del Primary           |
| Detalle de producto          | `product_catalog` | `secondaryPreferred` | No aplica     | Tolera una pequeña demora          |
| Creación de producto         | `product_catalog` | `primary`            | `majority`    | Requiere durabilidad               |
| Actualización de precio      | `product_catalog` | `primary`            | `majority`    | Dato sensible para negocio         |
| Actualización de métricas    | `product_catalog` | `secondaryPreferred` | `w:1`         | Métricas reprocesables             |
| Registro de reseña           | `product_reviews` | `primary`            | `majority`    | Información visible para usuarios  |
| Consulta de reseñas          | `product_reviews` | `secondaryPreferred` | No aplica     | Tolera consistencia eventual       |
| Evento de navegación         | `user_behavior`   | No aplica            | `w:1`         | Evento masivo y reprocesable       |
| Analítica de comportamiento  | `user_behavior`   | `secondary`          | No aplica     | No requiere consistencia inmediata |
| Recomendaciones              | `recommendations` | `secondary`          | `w:1`         | Puede recalcularse                 |
| Logs de búsqueda             | `search_logs`     | `secondary`          | `w:1`         | Dato analítico de alto volumen     |

---

## 3.14 Evidencias y archivos del repositorio

Las evidencias de MongoDB se encuentran asociadas al README y al notebook de optimización.

| Evidencia                         | Ubicación sugerida                                 |
| --------------------------------- | -------------------------------------------------- |
| Notebook documentado              | `mongodb/notebooks/Mongodb_ecommify_U5_Act1.ipynb` |
| README técnico MongoDB            | `mongodb/README.md` o `README.md`                  |
| Resultados de índices             | `mongodb/results/index_productivity_results.csv`   |
| Resultados de pipeline            | `mongodb/results/pipeline_results.csv`             |
| Capturas de `.explain()`          | `mongodb/evidencias/explain/`                      |
| Capturas de pipeline              | `mongodb/evidencias/pipeline/`                     |
| Evidencias de Atlas Metrics       | `mongodb/evidencias/atlas_metrics/`                |
| Evidencias de Performance Advisor | `mongodb/evidencias/performance_advisor/`          |

---

## 3.15 Conclusión de la implementación MongoDB

La implementación MongoDB permitió construir un modelo documental flexible y optimizado para el catálogo extendido de Ecommify.

Los índices compuestos ESR, índices parciales e índices de relación redujeron de forma significativa los documentos examinados en consultas críticas. El índice por `product_id` en `product_reviews` fue uno de los más importantes, ya que permitió optimizar consultas de reseñas por producto y operaciones `$lookup`.

El pipeline analítico optimizado redujo el tiempo promedio de ejecución en 62.27%, demostrando la importancia del orden de stages, la proyección temprana y la reducción de documentos intermedios.

También se evidenció que no todos los índices son productivos. El índice sobre `events.type` en `user_behavior` presentó baja productividad debido a la baja selectividad del evento `PURCHASE`.

Finalmente, el diseño teórico de sharding y replica sets proporciona una base para escalar la solución hacia un ambiente productivo, considerando distribución de datos, alta disponibilidad, consistencia eventual y separación de operaciones críticas y analíticas.


# 4. Evidencias cuantitativas de mejoras de rendimiento

Esta sección consolida las evidencias cuantitativas obtenidas durante la optimización de PostgreSQL y MongoDB. El objetivo es comparar el comportamiento antes y después de aplicar índices, optimización de consultas, optimización de pipelines y particionamiento.

---

## 4.1 Evidencias cuantitativas PostgreSQL

En PostgreSQL se evaluaron consultas críticas mediante `EXPLAIN (ANALYZE, BUFFERS)`. Las métricas principales analizadas fueron:

| Métrica           | Descripción                                  |
| ----------------- | -------------------------------------------- |
| `Execution Time`  | Tiempo total de ejecución de la consulta     |
| `Planning Time`   | Tiempo requerido para planificar la consulta |
| `Seq Scan`        | Escaneo secuencial de tabla                  |
| `Index Scan`      | Acceso mediante índice                       |
| `Index Only Scan` | Acceso usando únicamente el índice           |
| `Hash Join`       | Estrategia de join utilizada por PostgreSQL  |
| `Buffers`         | Bloques leídos o encontrados en memoria      |

Las consultas evaluadas fueron:

1. Historial de órdenes por cliente.
2. Ventas por categoría y mes.
3. Desempeño de vendedores por región.
4. Productos con reseñas negativas.
5. Consulta sobre tabla particionada por año.

---

## 4.2 Tabla comparativa PostgreSQL

| Query crítica                    | Tiempo antes | Tiempo después |   Mejora | Plan antes                                                | Plan después                                             | Interpretación                                             |
| -------------------------------- | -----------: | -------------: | -------: | --------------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------- |
| Historial de órdenes por cliente |    15.442 ms |       9.210 ms |   40.36% | `Seq Scan` sobre `orders` + `Index Scan` en `order_items` | `Index Scan` en `orders` + `Index Scan` en `order_items` | Mejora por uso de índice sobre `customer_id` y fecha       |
| Ventas por categoría y mes       |  1902.142 ms |     395.193 ms |   79.22% | `Parallel Seq Scan` + `Hash Join`                         | `Index Scan` sobre `orders` + `Hash Join`                | Mejora significativa por filtro indexado de estado y fecha |
| Desempeño vendedores por región  |   424.708 ms |     397.821 ms |    6.33% | `Seq Scan` + `Hash Join`                                  | `Index Only Scan` en `order_items` + `Hash Join`         | Mejora leve porque aún se procesan muchos registros        |
| Productos con reseñas negativas  |   912.709 ms |    2408.446 ms | -163.87% | `Seq Scan` + `Hash Join`                                  | `Index Scan` + `Index Only Scan`                         | El índice no fue productivo por baja selectividad          |
| Órdenes particionadas por año    |          N/A |      26.825 ms |      N/A | N/A                                                       | `Index Only Scan` sobre partición `orders_2018`          | Evidencia de `partition pruning`                           |

---

## 4.3 Interpretación PostgreSQL

La consulta de historial de órdenes por cliente presentó una mejora del **40.36%**, pasando de **15.442 ms** a **9.210 ms**. Esta mejora se obtuvo porque PostgreSQL dejó de realizar un escaneo secuencial sobre la tabla `orders` y utilizó el índice `idx_orders_customer_purchase_date`.

La consulta de ventas por categoría y mes presentó la mejora más significativa, con una reducción de **1902.142 ms** a **395.193 ms**, equivalente a una mejora de **79.22%**. Esta optimización se logró por el uso del índice `idx_orders_status_purchase_date`, que permite filtrar órdenes entregadas dentro de un rango de fechas.

La consulta de desempeño de vendedores por región mostró una mejora menor, pasando de **424.708 ms** a **397.821 ms**, equivalente a **6.33%**. Aunque el plan optimizado utilizó `Index Only Scan`, la consulta todavía procesa un volumen alto de registros y mantiene operaciones costosas como `Hash Join` y ordenamientos externos.

La consulta de productos con reseñas negativas no presentó mejora. El tiempo aumentó de **912.709 ms** a **2408.446 ms**. Este resultado evidencia que el índice `idx_reviews_score_order` no fue productivo para este patrón específico, debido a que el filtro `review_score <= 2` retorna una cantidad considerable de registros. Esto demuestra que un índice no siempre mejora el rendimiento si el campo tiene baja selectividad.

El particionamiento por fecha permitió evidenciar `partition pruning`. La consulta sobre el año 2018 utilizó un `Index Only Scan` sobre la partición `orders_2018`, con un tiempo de ejecución de **26.825 ms**. Esto demuestra que PostgreSQL puede reducir el volumen de datos evaluado cuando la condición de filtro coincide con la clave de particionamiento.

---

## 4.4 Gráficas de mejora PostgreSQL

Las gráficas de mejora se almacenaron en la carpeta de evidencias del repositorio:

```text
postgresql/evidencias/grafica_mejora_postgresql.png
postgresql/evidencias/Grafica_Metricas_Rendimiento.png
```

Estas gráficas permiten visualizar la diferencia porcentual de rendimiento entre las consultas ejecutadas antes y después de aplicar índices.

La gráfica de mejora muestra que las mayores optimizaciones se obtuvieron en:

* Ventas por categoría y mes: **79.22%**
* Historial de órdenes por cliente: **40.36%**
* Desempeño de vendedores por región: **6.33%**

También se evidencia un caso negativo:

* Productos con reseñas negativas: **-163.87%**

Este resultado negativo se conserva dentro del análisis porque representa una conclusión técnica relevante: la creación de índices debe validarse con planes de ejecución reales y no asumirse como una mejora automática.

---

## 4.5 Evidencias cuantitativas MongoDB

En MongoDB se evaluaron consultas críticas mediante `.explain("executionStats")`. Las métricas principales utilizadas fueron:

| Métrica               | Descripción                                                  |
| --------------------- | ------------------------------------------------------------ |
| `nReturned`           | Documentos retornados por la consulta                        |
| `totalDocsExamined`   | Documentos examinados por MongoDB                            |
| `totalKeysExamined`   | Claves de índice examinadas                                  |
| `executionTimeMillis` | Tiempo de ejecución en milisegundos                          |
| `docsPerReturned`     | Relación entre documentos examinados y documentos retornados |
| `keysPerReturned`     | Relación entre claves examinadas y documentos retornados     |

La métrica `docsPerReturned` se utilizó como indicador de eficiencia. Un valor cercano a **1** indica que MongoDB examina aproximadamente un documento por cada documento retornado, lo cual representa una consulta eficiente.

---

## 4.6 Tabla comparativa MongoDB

| Colección         | Índice evaluado                                  | Consulta evaluada                                       | Docs antes | Docs después | Tiempo antes | Tiempo después | Efficiency ratio antes | Efficiency ratio después | Resultado                           |
| ----------------- | ------------------------------------------------ | ------------------------------------------------------- | ---------: | -----------: | -----------: | -------------: | ---------------------: | -----------------------: | ----------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Catálogo por categoría, región, estado, rating y precio |     32.951 |        1.854 |        30 ms |           6 ms |                  17.77 |                     1.00 | Productivo                          |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Productos activos más vendidos                          |     32.951 |        2.219 |        30 ms |           7 ms |                  14.85 |                     1.00 | Productivo                          |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Productos activos con reseñas suficientes               |     32.951 |          120 |        27 ms |           1 ms |                 274.59 |                     1.00 | Muy productivo                      |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Reseñas por producto                                    |    102.172 |            3 |        97 ms |           1 ms |               34057.33 |                     1.00 | Muy productivo                      |
| `product_reviews` | `idx_pr_rating_created_at`                       | Reseñas negativas recientes                             |    102.172 |       15.275 |        78 ms |          74 ms |                   6.69 |                     1.00 | Productivo en documentos examinados |
| `user_behavior`   | `idx_ub_event_type_period`                       | Eventos `PURCHASE`                                      |    112.650 |      112.650 |       176 ms |         190 ms |                   1.00 |                     1.00 | Baja productividad                  |
| `sellers`         | `idx_sellers_region_city`                        | Vendedores por región y ciudad                          |      1.849 |           41 |         2 ms |           1 ms |                  45.10 |                     1.00 | Muy productivo                      |

---

## 4.7 Interpretación MongoDB

En `product_catalog`, los índices compuestos basados en la regla ESR demostraron mejoras claras. El índice `idx_pc_esr_category_region_status_rating_price` redujo los documentos examinados de **32.951** a **1.854** y el tiempo de ejecución de **30 ms** a **6 ms**.

El índice `idx_pc_esr_status_category_units_price` también fue productivo, reduciendo documentos examinados de **32.951** a **2.219** y el tiempo de **30 ms** a **7 ms**.

El índice parcial `idx_pc_partial_active_rating_price` fue uno de los más eficientes. Redujo los documentos examinados de **32.951** a **120**, con una mejora de tiempo de **27 ms** a **1 ms**. Además, el `docsPerReturned` pasó de **274.59** a **1.00**, lo que evidencia una consulta altamente eficiente.

En `product_reviews`, el índice por `product_id` fue fundamental. La consulta de reseñas por producto pasó de examinar **102.172** documentos a solo **3**, reduciendo el tiempo de **97 ms** a **1 ms**. El efficiency ratio pasó de **34057.33** a **1.00**, evidenciando una mejora crítica para consultas por producto y operaciones `$lookup`.

El índice `idx_pr_rating_created_at` redujo los documentos examinados de **102.172** a **15.275**. Aunque el tiempo solo cambió de **78 ms** a **74 ms**, la consulta dejó de realizar un escaneo completo de colección y se volvió más eficiente en términos de documentos examinados.

En `user_behavior`, el índice `idx_ub_event_type_period` no presentó mejora significativa. La consulta de eventos `PURCHASE` retornó una proporción muy alta de la colección, por lo cual el índice tuvo baja selectividad. El tiempo incluso aumentó de **176 ms** a **190 ms**. Esto demuestra que no todo índice mejora el rendimiento si el valor filtrado es demasiado frecuente.

En `sellers`, el índice `idx_sellers_region_city` fue productivo, reduciendo los documentos examinados de **1.849** a **41** y el tiempo de **2 ms** a **1 ms**.

---

## 4.8 Aggregation pipeline MongoDB

También se midió el rendimiento del pipeline analítico original y del pipeline optimizado.

| Pipeline            | Tiempo promedio | Documentos retornados | Mejora vs original |
| ------------------- | --------------: | --------------------: | -----------------: |
| Pipeline original   |       959.52 ms |                    10 |                 0% |
| Pipeline optimizado |       362.02 ms |                    10 |             62.27% |

El pipeline optimizado redujo el tiempo promedio de ejecución de **959.52 ms** a **362.02 ms**, logrando una mejora de **62.27%**.

Esta mejora se obtuvo mediante:

* `$match` al inicio del pipeline.
* Uso de índices sobre campos filtrados.
* `$project` temprano para reducir campos innecesarios.
* Reemplazo de `$unwind` por `$size` para contar reseñas sin multiplicar documentos.
* Uso de `allowDiskUse=True`.

El resultado evidencia que la optimización de pipelines no depende únicamente de índices, sino también del orden de los stages y de la reducción temprana de documentos intermedios.

---

# 5. Sincronización entre PostgreSQL y MongoDB

La arquitectura de Ecommify utiliza PostgreSQL y MongoDB con responsabilidades diferentes. PostgreSQL administra el núcleo transaccional y MongoDB almacena datos flexibles, analíticos y optimizados para lectura.

La sincronización entre sistemas se plantea mediante eventos de dominio y procesamiento asíncrono.

---

## 5.1 Flujos de datos entre PostgreSQL y MongoDB

### Flujo 1: Creación o actualización de producto

1. El producto base se registra o actualiza en PostgreSQL.
2. PostgreSQL conserva la información transaccional y normalizada.
3. Se genera un evento de dominio, por ejemplo `PRODUCT_CREATED` o `PRODUCT_UPDATED`.
4. Un proceso de sincronización consume el evento.
5. MongoDB actualiza la colección `product_catalog`.
6. El producto queda disponible para consultas rápidas del catálogo extendido.

### Flujo 2: Creación de orden

1. La orden se registra en PostgreSQL.
2. Se almacenan los datos en `orders`, `order_items` y `payments`.
3. Se genera el evento `ORDER_CREATED`.
4. Un proceso asíncrono actualiza métricas en MongoDB.
5. En `product_catalog.metrics` se actualizan campos como `total_units_sold` y `total_revenue`.
6. En `user_behavior` se registran eventos como `VIEW_PRODUCT`, `ADD_TO_CART` y `PURCHASE`.

### Flujo 3: Registro de reseña

1. La reseña se registra inicialmente asociada a una orden.
2. Se genera un evento `REVIEW_CREATED`.
3. MongoDB actualiza la colección `product_reviews`.
4. Se recalculan métricas en `product_catalog.ratings`, como `average` y `count`.
5. El catálogo extendido refleja la calificación agregada del producto.

### Flujo 4: Analítica y recomendaciones

1. MongoDB almacena eventos de comportamiento en `user_behavior`.
2. Los datos se procesan de forma analítica.
3. Se generan recomendaciones personalizadas.
4. Las recomendaciones se almacenan en la colección `recommendations`.
5. El frontend puede consultar recomendaciones sin afectar el núcleo transaccional de PostgreSQL.

---

## 5.2 Estrategia de consistencia implementada

La estrategia de consistencia utilizada es híbrida:

| Tipo de dato              | Sistema principal | Estrategia de consistencia       |
| ------------------------- | ----------------- | -------------------------------- |
| Órdenes                   | PostgreSQL        | Consistencia fuerte              |
| Pagos                     | PostgreSQL        | Consistencia fuerte              |
| Inventario                | PostgreSQL        | Consistencia fuerte              |
| Productos base            | PostgreSQL        | Consistencia fuerte              |
| Catálogo extendido        | MongoDB           | Consistencia eventual            |
| Reseñas agregadas         | MongoDB           | Consistencia eventual controlada |
| Comportamiento de usuario | MongoDB           | Consistencia eventual            |
| Recomendaciones           | MongoDB           | Consistencia eventual            |

PostgreSQL es la fuente de verdad para las operaciones críticas. MongoDB funciona como una proyección documental optimizada para lectura, análisis y flexibilidad.

---

## 5.3 Justificación de consistencia

Las operaciones de pagos, órdenes e inventario requieren consistencia fuerte porque afectan directamente el estado financiero y operativo del negocio. Por esta razón se mantienen en PostgreSQL.

Las métricas de catálogo, reseñas agregadas, eventos de comportamiento y recomendaciones pueden tolerar pequeñas demoras de sincronización. Por esta razón se almacenan en MongoDB bajo un modelo de consistencia eventual.

Esta separación permite mejorar el rendimiento de lectura y análisis sin comprometer la confiabilidad del núcleo transaccional.

---

## 5.4 Mecanismos de mitigación

Para reducir riesgos asociados a la consistencia eventual se proponen los siguientes mecanismos:

| Riesgo                        | Mitigación                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------- |
| Evento duplicado              | Procesamiento idempotente usando identificadores únicos                         |
| Evento perdido                | Cola persistente de eventos y reintentos automáticos                            |
| Retraso de sincronización     | Monitoreo de lag y procesamiento asíncrono                                      |
| Métrica desactualizada        | Reprocesamiento periódico de métricas                                           |
| Lectura crítica inconsistente | Leer desde PostgreSQL o desde Primary cuando se requiera consistencia inmediata |
| Fallo parcial del proceso     | Registro de errores y reprocesamiento por lote                                  |

---

# 6. Lecciones aprendidas

## 6.1 Obstáculos encontrados y soluciones aplicadas

| Obstáculo                                                          | Impacto                                                                               | Solución aplicada                                                                                                         |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| El dataset Olist tiene estructura relacional                       | Fue necesario adaptarlo al modelo documental de MongoDB                               | Se transformaron datos relacionales en colecciones como `product_catalog`, `product_reviews`, `sellers` y `user_behavior` |
| Diferencia entre modelo relacional y documental                    | No era adecuado copiar la misma estructura de PostgreSQL en MongoDB                   | Se mantuvo PostgreSQL normalizado y MongoDB desnormalizado para lectura                                                   |
| Duplicados al insertar reseñas                                     | Se generaron errores por `_id` repetidos                                              | Se eliminó duplicidad usando `review_id + product_id`                                                                     |
| Índices existentes con nombres automáticos                         | Algunos índices ya existían con nombres como `product_id_1`                           | Se reutilizó el nombre real del índice con `hint()`                                                                       |
| Sintaxis de Mongo Shell en Google Colab                            | Comandos como `createIndex()` fallaron en PyMongo                                     | Se usó `create_index()` en Python                                                                                         |
| Free Tier de MongoDB no permite sharding real                      | No fue posible ejecutar `sh.enableSharding()` ni `sh.shardCollection()`               | Se documentó el diseño teórico y se simuló distribución across shards                                                     |
| Algunos índices no fueron productivos                              | Se evidenció que índices con baja selectividad pueden empeorar o no mejorar consultas | Se validó cada índice con `.explain("executionStats")`                                                                    |
| En PostgreSQL un índice no mejoró la consulta de reseñas negativas | La consulta empeoró por baja selectividad del filtro `review_score <= 2`              | Se documentó como evidencia de índice no productivo                                                                       |
| Supabase Free Tier tiene recursos limitados                        | Las pruebas no representan una carga productiva real                                  | Se usó `EXPLAIN ANALYZE`, capturas y comparación antes/después                                                            |
| Métricas avanzadas limitadas en Atlas Free Tier                    | No todas las métricas de monitoreo estaban disponibles                                | Se complementó con `.explain()`, `$indexStats` y medición manual de tiempos                                               |

---

## 6.2 Limitaciones del free tier

Durante el desarrollo se utilizaron servicios gratuitos de MongoDB Atlas y Supabase. Estos entornos permitieron validar la implementación académica, pero presentan limitaciones frente a un ambiente productivo.

### MongoDB Atlas Free Tier

| Limitación                                   | Workaround implementado                                   |
| -------------------------------------------- | --------------------------------------------------------- |
| No permite sharding real                     | Diseño teórico de shard keys y simulación de distribución |
| No permite configurar replica sets avanzados | Documentación de topología teórica de tres nodos          |
| Métricas avanzadas limitadas                 | Uso de `.explain("executionStats")` y `$indexStats`       |
| Capacidad reducida de cómputo                | Pruebas con dataset académico y medición controlada       |
| No representa alta concurrencia real         | Análisis basado en consultas críticas y pipelines         |

### Supabase Free Tier

| Limitación                                    | Workaround implementado                              |
| --------------------------------------------- | ---------------------------------------------------- |
| Recursos de CPU y memoria limitados           | Pruebas con `EXPLAIN (ANALYZE, BUFFERS)`             |
| Sin configuración avanzada de infraestructura | Evaluación lógica de índices y particionamiento      |
| Rendimiento variable por entorno compartido   | Comparación relativa antes/después                   |
| Carga masiva limitada desde interfaz          | Importación controlada de CSV                        |
| Sin arquitectura multi-nodo real              | Documentación de decisiones arquitectónicas teóricas |

---

## 6.3 Aprendizajes principales

La actividad permitió identificar que la optimización de bases de datos debe basarse en evidencia cuantitativa y no únicamente en la creación de índices.

En PostgreSQL, los índices mejoraron consultas cuando estaban alineados con filtros selectivos y patrones reales de acceso. Sin embargo, también se evidenció que un índice puede no ser productivo si el filtro retorna una proporción alta de registros.

En MongoDB, los índices ESR y parciales fueron altamente efectivos para consultas del catálogo, mientras que los índices sobre campos de baja selectividad tuvieron impacto limitado.

La optimización de pipelines demostró que el orden de los stages, la proyección temprana y la reducción de documentos intermedios pueden generar mejoras importantes incluso sin cambiar la lógica funcional del análisis.

Finalmente, la separación entre PostgreSQL y MongoDB permitió comprender la importancia de asignar responsabilidades diferentes a cada motor: PostgreSQL como fuente transaccional de verdad y MongoDB como modelo documental flexible para lectura, analítica y escalabilidad.

---

# 7. Conclusiones

La implementación optimizada de Ecommify demuestra la utilidad de una arquitectura híbrida basada en PostgreSQL y MongoDB.

PostgreSQL permitió representar el núcleo transaccional del negocio mediante un modelo relacional normalizado, adecuado para clientes, vendedores, productos, órdenes, pagos y reseñas. MongoDB permitió construir un modelo documental flexible para catálogo extendido, reseñas completas, comportamiento de usuario, métricas comerciales y análisis.

Las optimizaciones realizadas en PostgreSQL mostraron mejoras relevantes en consultas críticas. La consulta de ventas por categoría y mes obtuvo una mejora de **79.22%**, mientras que el historial de órdenes por cliente mejoró en **40.36%**. También se evidenció que no todos los índices son beneficiosos, como ocurrió con la consulta de productos con reseñas negativas.

En MongoDB, los índices compuestos ESR, índices parciales y el índice por `product_id` redujeron significativamente los documentos examinados. El índice parcial de productos activos redujo documentos examinados de **32.951** a **120**, y el índice de reseñas por producto redujo documentos examinados de **102.172** a **3**.

El pipeline analítico optimizado redujo el tiempo promedio de ejecución de **959.52 ms** a **362.02 ms**, logrando una mejora de **62.27%**.

El diseño teórico de sharding y replica sets permite proyectar la solución hacia un ambiente productivo con mayor escalabilidad, disponibilidad y tolerancia a fallos. La estrategia de sincronización basada en eventos permite mantener desacoplados PostgreSQL y MongoDB, asignando a cada motor la responsabilidad que mejor se ajusta a sus fortalezas.

Finalmente, la actividad permitió concluir que la optimización debe estar basada en mediciones reales. Herramientas como `EXPLAIN (ANALYZE, BUFFERS)`, `.explain("executionStats")`, `$indexStats` y la comparación de tiempos antes/después son fundamentales para validar decisiones técnicas de indexación, modelado y arquitectura.
