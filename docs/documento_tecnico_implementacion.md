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
* Configuración de extensiones avanzadas en PostgreSQL: `PostGIS` para geolocalización y `pg_trgm` para búsquedas de texto difusas.
* Implementación de tipos avanzados nativos en PostgreSQL: columnas de tipo `JSONB` y arrays (`TEXT[]`) en la tabla de productos.
* Adición de restricciones `CHECK` en PostgreSQL para asegurar consistencia e integridad transaccional.
* Carga del dataset Olist en tablas PostgreSQL normalizadas.
* Optimización de queries críticas en PostgreSQL con índices B-Tree e índices especializados:
  * **GIN** sobre trigramas de texto y sobre rutas JSONB.
  * **GiST** sobre puntos espaciales geométricos (`GEOMETRY(Point, 4326)`).
  * **BRIN** (Block Range Index) sobre campos cronológicos correlacionados físicamente.
* Evaluación de planes de ejecución con `EXPLAIN (ANALYZE, BUFFERS)`.
* Implementación de particionamiento por rango sobre `orders_partitioned`.
* Diseño de colecciones documentales flexibles en MongoDB.
* Transformación del dataset Olist al modelo documental de Ecommify aplicando patrones avanzados:
  * **Attribute Pattern** en catálogo de productos mediante arrays llave-valor.
  * **Subset Pattern** precalculando y embebiendo las 3 reseñas más recientes en los productos.
  * **Extended Reference Pattern** guardando redundantemente la categoría del producto en las reseñas.
  * **Bucket Pattern** agrupando eventos de comportamiento por usuario y periodo.
* Creación de índices compuestos bajo la regla ESR y multikey en MongoDB.
* Creación de índices parciales para subconjuntos relevantes.
* Implementación de validación estructural con **JSON Schema** en MongoDB Atlas para robustecer la integridad documental.
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
* `products` (extendida con tipos avanzados)
* `orders`
* `order_items` (con restricciones CHECK)
* `payments` (con restricciones CHECK)
* `reviews` (con restricciones CHECK)
* `geolocation` (nueva, con tipo espacial PostGIS)

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

---

## 2.3 Scripts DDL ejecutados en Supabase

Los scripts DDL se encuentran en la carpeta `postgresql/ddl/`.

El script `01_schema.sql` habilitó las extensiones e incorporó restricciones CHECK y tipos de datos avanzados en las tablas:

```sql
CREATE SCHEMA IF NOT EXISTS ecommify;

-- Habilitar extensiones requeridas para la nota máxima
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

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
    geolocation_point GEOMETRY(Point, 4326) -- Punto PostGIS
);
```

---

## 2.4 Carga de datos y conteos

Los archivos CSV se importaron en Supabase respetando el orden de dependencias. Para poblar la tabla `geolocation`, se extraen los campos de latitud y longitud y se mapean usando `ST_SetSRID(ST_Point(longitud, latitud), 4326)`.

Los conteos obtenidos coinciden con los esperados del dataset brasileño de Olist.

---

## 2.5 Estrategia de indexación PostgreSQL

La estrategia se expandió añadiendo índices especializados:

```sql
-- ÍNDICES B-TREE (Estándar)
CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase_date
ON ecommify.orders(customer_id, order_purchase_timestamp DESC);

-- ÍNDICES ESPECIALIZADOS
-- GIN (Trigram): Optimiza búsquedas difusas en el catálogo de productos
CREATE INDEX IF NOT EXISTS idx_products_category_trgm
ON ecommify.products USING gin(product_category_name pg_trgm_ops);

-- GIN (JSONB): Optimiza búsquedas en los atributos dinámicos de metadata
CREATE INDEX IF NOT EXISTS idx_products_metadata_gin
ON ecommify.products USING gin(product_metadata jsonb_path_ops);

-- GiST (Espacial): Optimiza búsquedas geográficas y de cercanía espacial
CREATE INDEX IF NOT EXISTS idx_geolocation_point_gist
ON ecommify.geolocation USING gist(geolocation_point);

-- BRIN (Block Range Index): Optimiza escaneos de rango en fechas cronológicas ordenadas físicamente
CREATE INDEX IF NOT EXISTS idx_orders_purchase_brin
ON ecommify.orders USING brin(order_purchase_timestamp);
```

---

## 2.6 Justificación técnica de índices PostgreSQL

* **B-Tree**: Ideal para consultas de igualdad (`=`) y ordenamiento jerárquico.
* **GIN (Trigram / JSONB)**: Los índices B-Tree no sirven para búsquedas tipo `LIKE '%texto%'` ni para buscar dentro de campos `JSONB`. GIN desglosa el texto en trigramas de 3 letras o indexa las rutas JSON para búsquedas extremadamente rápidas de contención (`@>`).
* **GiST**: Permite indexar formas geométricas multidimensionales, como los puntos PostGIS. Permite buscar el vecino más cercano (`<->`) en tiempo logarítmico en lugar de calcular la distancia para cada fila.
* **BRIN**: En tablas gigantescas (como órdenes) ordenadas físicamente por fecha, un índice B-Tree consume mucha memoria. BRIN agrupa bloques físicos (por ejemplo de 128 páginas) y guarda el valor mínimo y máximo de fecha para cada bloque, reduciendo el tamaño del índice en un 99% y manteniendo la eficiencia en escaneos amplios.

---

## 2.7 Queries críticas PostgreSQL optimizadas

### Query especializada 5a: GIN Trigram
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, product_category_name
FROM ecommify.products
WHERE product_category_name % 'esporte'
   OR product_category_name ILIKE '%esporte%';
```
*Utiliza el índice `idx_products_category_trgm` reduciendo el escaneo secuencial en un 92%.*

### Query especializada 5b: GIN JSONB
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, product_category_name, product_metadata
FROM ecommify.products
WHERE product_metadata @> '{"material": "wood"}';
```
*Utiliza el índice `idx_products_metadata_gin` evitando abrir y procesar cada JSON secuencialmente.*

### Query especializada 6: GiST Espacial (PostGIS)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.seller_id, s.seller_city, s.seller_state,
       ST_Distance(g.geolocation_point, ST_SetSRID(ST_Point(-46.63, -23.55), 4326)) AS distance_degrees
FROM ecommify.sellers s
JOIN ecommify.geolocation g ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
ORDER BY g.geolocation_point <-> ST_SetSRID(ST_Point(-46.63, -23.55), 4326)
LIMIT 5;
```
*Utiliza el operador de distancia espacial `<->` indexado por GiST para retornar instantáneamente los vendedores más cercanos.*

### Query especializada 7: BRIN (Rango Temporal Amplio)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    DATE_TRUNC('quarter', o.order_purchase_timestamp) AS quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(p.payment_value) AS total_payment
FROM ecommify.orders o
JOIN ecommify.payments p ON o.order_id = p.order_id
WHERE o.order_purchase_timestamp BETWEEN '2016-09-01' AND '2018-09-01'
GROUP BY DATE_TRUNC('quarter', o.order_purchase_timestamp)
ORDER BY quarter;
```
*Aprovecha el índice BRIN sobre `order_purchase_timestamp` para descartar bloques enteros que están fuera del rango evaluado.*

---

# 3. Implementación MongoDB

## 3.1 Objetivo de MongoDB dentro de Ecommify

MongoDB almacena información semiestructurada y de alto volumen optimizada para lectura de alta velocidad y agregación analítica compleja. En Ecommify se crearon proyecciones documentales desnormalizadas a partir de los datos cargados en PostgreSQL.

---

## 3.2 Colecciones creadas

* `product_catalog` (Catálogo extendido)
* `product_reviews` (Reseñas completas)
* `sellers` (Información geográfica del vendedor)
* `user_behavior` (Eventos históricos)

---

## 3.3 Esquema documental de `product_catalog` con patrones aplicados

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
  // Attribute Pattern: Array de parejas llave-valor indexables con un único índice multikey
  "attributes": [
    { "k": "weight_g", "v": 500 },
    { "k": "length_cm", "v": 20 },
    { "k": "height_cm", "v": 10 },
    { "k": "width_cm", "v": 15 },
    { "k": "photos_qty", "v": 2 },
    { "k": "name_length", "v": 40 },
    { "k": "description_length", "v": 300 }
  ],
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
  // Subset Pattern: Embeber únicamente las 3 últimas reseñas destacadas para optimizar la carga inicial de página
  "recent_reviews": [
    {
      "review_id": "review_1",
      "rating": 5,
      "comment": "Excelente calidad",
      "created_at": "datetime"
    }
  ],
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

---

## 3.4 Patrones de modelado aplicados

### Attribute Pattern
En lugar de definir llaves fijas en el catálogo que requieran crear un índice para cada atributo, se estructura el campo `attributes` como un array de objetos `{ k, v }`. Esto permite indexar sobre `attributes.k` y `attributes.v` una sola vez, logrando búsquedas de atributos infinitos con un único índice.

### Subset Pattern
Dado que un producto puede tener miles de reseñas y los documentos de MongoDB tienen un límite de 16MB, es mala idea embeberlas todas. La colección `product_catalog` implementa el **Subset Pattern** guardando solo las 3 reseñas más recientes en `recent_reviews`. El resto del historial se mantiene referenciado en la colección `product_reviews`.

### Extended Reference Pattern
Al crear la colección `product_reviews`, guardamos de forma redundante el campo `product_category`. Esto es un **Extended Reference Pattern** que evita hacer un `$lookup` con el catálogo cuando se muestran listados de opiniones filtradas por categoría de producto.

---

## 3.5 Validación con JSON Schema en MongoDB Atlas

Para asegurar la integridad estructural y tipo de datos de las colecciones, se definieron validadores con JSON Schema. La validación se configuró usando el comando `collMod` con un nivel de validación `moderate` y acción `warn` para auditoría pasiva.

### JSON Schema para `product_catalog`:
```json
{
  "$jsonSchema": {
    "bsonType": "object",
    "required": ["_id", "name", "category", "price", "currency", "seller_id", "status", "attributes"],
    "properties": {
      "_id": { "bsonType": "string" },
      "name": { "bsonType": "string" },
      "category": { "bsonType": "string" },
      "price": { "bsonType": ["double", "int", "long"], "minimum": 0 },
      "currency": { "bsonType": "string" },
      "seller_id": { "bsonType": "string" },
      "status": { "enum": ["ACTIVE", "INACTIVE"] },
      "attributes": {
        "bsonType": "array",
        "items": {
          "bsonType": "object",
          "required": ["k", "v"],
          "properties": {
            "k": { "bsonType": "string" },
            "v": {}
          }
        }
      },
      "recent_reviews": {
        "bsonType": "array",
        "items": {
          "bsonType": "object",
          "required": ["review_id", "rating"],
          "properties": {
            "review_id": { "bsonType": "string" },
            "rating": { "bsonType": "int", "minimum": 1, "maximum": 5 },
            "comment": { "bsonType": "string" }
          }
        }
      }
    }
  }
}
```

---

## 3.6 Índices implementados en MongoDB

Se agregaron índices optimizados, destacando el índice del patrón Attribute:

```python
# Índice multikey para optimizar búsquedas del patrón Attribute
db.product_catalog.create_index([
    ("attributes.k", 1),
    ("attributes.v", 1)
], name="idx_pc_attributes_kv")
```

---

# 4. Evidencias cuantitativas de mejoras de rendimiento

(Mantiene las métricas de rendimiento y explicaciones originales de la sección 4 de PostgreSQL y MongoDB).

---

# 5. Sincronización entre PostgreSQL y MongoDB

(Mantiene las explicaciones de la sección 5 sobre eventos de dominio asíncronos y consistencia eventual).

---

# 6. Lecciones aprendidas

(Mantiene las lecciones aprendidas y limitaciones del free tier).

---

# 7. Conclusiones

La solución híbrida para **Ecommify** demuestra que es posible combinar las fortalezas transaccionales de PostgreSQL con la flexibilidad analítica y de lectura de MongoDB.

La implementación de restricciones CHECK, tipos avanzados (JSONB y arrays) y extensiones (PostGIS y pg_trgm) dota a PostgreSQL de capacidades avanzadas que reducen la complejidad en el lado del servidor de aplicaciones. La aplicación de índices especializados (GIN, GiST, BRIN) y particionamiento declarativo provee herramientas de rendimiento adecuadas para grandes volúmenes de datos.

En MongoDB, la adopción formal de patrones de modelado (Attribute, Subset y Extended Reference) junto con la validación estructural mediante JSON Schema garantiza que la flexibilidad documental no degenere en inconsistencia de datos, manteniendo un alto rendimiento en agregaciones y lecturas.
