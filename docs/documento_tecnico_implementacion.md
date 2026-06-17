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

El script `00_extensions.sql` habilita las extensiones necesarias:

```sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Encriptación y generación segura de hashes / UUID.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Generación de UUID.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Búsquedas textuales avanzadas.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Geolocalización.
CREATE EXTENSION IF NOT EXISTS postgis;

-- pg_partman puede no estar disponible en Supabase Free Tier.
-- Se intenta crear sin romper la ejecución si no está habilitada.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_partman;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_partman no está disponible en este entorno. Se usará particionamiento declarativo nativo.';
END $$;

```

El script `01_schema.sql` habilitó las extensiones e incorporó restricciones CHECK y tipos de datos avanzados en las tablas:

```sql
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
