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

Durante la implementación se trabajó especialmente sobre el módulo MongoDB, utilizando el dataset público **Olist Brazilian E-Commerce**, el cual fue transformado a la estructura documental definida para Ecommify. A partir de este dataset se construyeron colecciones como `product_catalog`, `product_reviews`, `sellers` y `user_behavior`.

Las principales optimizaciones aplicadas fueron:

* Diseño de colecciones documentales flexibles en MongoDB.
* Transformación del dataset Olist al modelo documental de Ecommify.
* Creación de índices compuestos bajo la regla ESR.
* Creación de índices parciales para subconjuntos relevantes.
* Implementación de índices de texto para búsqueda full-text.
* Evaluación de productividad de índices con `.explain("executionStats")`.
* Optimización de aggregation pipelines.
* Diseño teórico de sharding y replica sets.
* Monitoreo mediante Atlas Metrics, Performance Advisor, `$indexStats` y métricas de ejecución.

Los resultados cuantitativos más destacados fueron:

| Optimización                     |                   Antes |               Después |                  Mejora |
| -------------------------------- | ----------------------: | --------------------: | ----------------------: |
| Índice ESR catálogo principal    |  32.951 docs examinados | 1.854 docs examinados | Reducción significativa |
| Índice productos más vendidos    |  32.951 docs examinados | 2.219 docs examinados | Reducción significativa |
| Índice parcial productos activos |  32.951 docs examinados |   120 docs examinados |          Muy productivo |
| Índice reseñas por producto      | 102.172 docs examinados |     3 docs examinados |          Muy productivo |
| Pipeline analítico               |               959.52 ms |             362.02 ms |                  62.27% |

Estos resultados evidencian que las estrategias de indexación y optimización de pipelines permiten reducir de manera importante el volumen de documentos examinados y el tiempo promedio de ejecución.

---

# 2. Implementación PostgreSQL

## 2.1 Objetivo de PostgreSQL dentro de Ecommify

PostgreSQL se utiliza para administrar la información crítica y transaccional de Ecommify. Este motor es adecuado para operaciones que requieren integridad referencial, consistencia fuerte y soporte ACID.

Las entidades principales administradas en PostgreSQL son:

* Usuarios.
* Direcciones.
* Productos base.
* Inventarios.
* Órdenes.
* Detalles de órdenes.
* Pagos.

Esta decisión arquitectónica se alinea con el diseño híbrido de Ecommify, donde PostgreSQL cubre el núcleo transaccional y MongoDB soporta el catálogo extendido y los módulos analíticos.

---

## 2.2 Scripts DDL ejecutados en Supabase

Los scripts DDL base para PostgreSQL son los siguientes:

```sql
CREATE TABLE usuarios (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    telefono VARCHAR(20),
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    estado VARCHAR(20)
);

CREATE TABLE direcciones (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT REFERENCES usuarios(id),
    ciudad VARCHAR(100) NOT NULL,
    pais VARCHAR(100) NOT NULL,
    direccion TEXT NOT NULL,
    codigo_postal VARCHAR(20)
);

CREATE TABLE productos (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(12,2) NOT NULL,
    categoria_id BIGINT,
    atributos JSONB,
    tags TEXT[],
    fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE inventarios (
    id BIGSERIAL PRIMARY KEY,
    producto_id BIGINT REFERENCES productos(id),
    stock INTEGER CHECK (stock >= 0),
    stock_reservado INTEGER DEFAULT 0,
    ultima_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ordenes (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT REFERENCES usuarios(id),
    total NUMERIC(12,2) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    metadata JSONB
);

CREATE TABLE detalle_orden (
    id BIGSERIAL PRIMARY KEY,
    orden_id BIGINT REFERENCES ordenes(id),
    producto_id BIGINT REFERENCES productos(id),
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL
);

CREATE TABLE pagos (
    id BIGSERIAL PRIMARY KEY,
    orden_id BIGINT UNIQUE REFERENCES ordenes(id),
    metodo_pago VARCHAR(50) NOT NULL,
    estado_pago VARCHAR(30) NOT NULL,
    referencia_externa VARCHAR(200),
    fecha_pago TIMESTAMP
);
```

---

## 2.3 Estrategia de indexación PostgreSQL

La estrategia de indexación en PostgreSQL se enfoca en optimizar las consultas críticas de negocio: búsqueda de usuarios, consulta de órdenes por usuario, consulta de pagos por orden, análisis de productos e inventario.

```sql
CREATE INDEX idx_usuarios_email
ON usuarios(email);

CREATE INDEX idx_ordenes_usuario_fecha
ON ordenes(usuario_id, fecha_creacion DESC);

CREATE INDEX idx_ordenes_estado_fecha
ON ordenes(estado, fecha_creacion DESC);

CREATE INDEX idx_detalle_orden_orden
ON detalle_orden(orden_id);

CREATE INDEX idx_detalle_orden_producto
ON detalle_orden(producto_id);

CREATE INDEX idx_pagos_estado
ON pagos(estado_pago);

CREATE INDEX idx_inventarios_producto
ON inventarios(producto_id);

CREATE INDEX idx_productos_precio
ON productos(precio);

CREATE INDEX idx_productos_atributos_gin
ON productos USING GIN (atributos);

CREATE INDEX idx_productos_tags_gin
ON productos USING GIN (tags);
```

## 2.4 Justificación técnica de índices PostgreSQL

| Índice                        | Justificación                                                |
| ----------------------------- | ------------------------------------------------------------ |
| `idx_usuarios_email`          | Optimiza autenticación y búsqueda de usuario por correo      |
| `idx_ordenes_usuario_fecha`   | Optimiza historial de órdenes por usuario                    |
| `idx_ordenes_estado_fecha`    | Permite filtrar órdenes por estado y fecha                   |
| `idx_detalle_orden_orden`     | Mejora consulta de detalles asociados a una orden            |
| `idx_detalle_orden_producto`  | Permite analizar ventas por producto                         |
| `idx_pagos_estado`            | Optimiza monitoreo de pagos pendientes o fallidos            |
| `idx_inventarios_producto`    | Optimiza consulta de stock por producto                      |
| `idx_productos_atributos_gin` | Permite consultas eficientes sobre atributos dinámicos JSONB |
| `idx_productos_tags_gin`      | Optimiza búsquedas por etiquetas                             |

---

## 2.5 Particionamiento aplicado

Para las tablas de mayor crecimiento se propone particionamiento por rango temporal.

Tablas candidatas:

* `ordenes`
* `pagos`
* `historial_transacciones`, si se implementa posteriormente.

Ejemplo de particionamiento para órdenes:

```sql
CREATE TABLE ordenes_particionadas (
    id BIGSERIAL,
    usuario_id BIGINT,
    total NUMERIC(12,2) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL,
    metadata JSONB,
    PRIMARY KEY (id, fecha_creacion)
) PARTITION BY RANGE (fecha_creacion);

CREATE TABLE ordenes_2026_06
PARTITION OF ordenes_particionadas
FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

El particionamiento permite reducir el volumen de datos escaneado en consultas históricas y facilita políticas de archivado.

---

## 2.6 Queries críticas PostgreSQL optimizadas

### Consulta 1: historial de órdenes por usuario

```sql
EXPLAIN ANALYZE
SELECT id, total, estado, fecha_creacion
FROM ordenes
WHERE usuario_id = 1001
ORDER BY fecha_creacion DESC
LIMIT 20;
```

Índice asociado:

```sql
CREATE INDEX idx_ordenes_usuario_fecha
ON ordenes(usuario_id, fecha_creacion DESC);
```

### Consulta 2: órdenes pendientes por fecha

```sql
EXPLAIN ANALYZE
SELECT id, usuario_id, total, estado, fecha_creacion
FROM ordenes
WHERE estado = 'PENDIENTE'
ORDER BY fecha_creacion DESC;
```

Índice asociado:

```sql
CREATE INDEX idx_ordenes_estado_fecha
ON ordenes(estado, fecha_creacion DESC);
```

### Consulta 3: consulta de inventario por producto

```sql
EXPLAIN ANALYZE
SELECT producto_id, stock, stock_reservado
FROM inventarios
WHERE producto_id = 1001;
```

Índice asociado:

```sql
CREATE INDEX idx_inventarios_producto
ON inventarios(producto_id);
```

---

## 2.7 Evidencias PostgreSQL pendientes de completar

Para completar esta sección en el repositorio se deben agregar las siguientes evidencias:

| Evidencia                             | Archivo sugerido                                      |
| ------------------------------------- | ----------------------------------------------------- |
| Captura de tablas creadas en Supabase | `evidencias/postgresql/tablas_supabase.png`           |
| Captura de índices creados            | `evidencias/postgresql/indices_supabase.png`          |
| EXPLAIN ANALYZE antes de índices      | `evidencias/postgresql/explain_before.png`            |
| EXPLAIN ANALYZE después de índices    | `evidencias/postgresql/explain_after.png`             |
| Gráfica de mejora de tiempos          | `evidencias/postgresql/grafica_mejora_postgresql.png` |

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

La sección PostgreSQL debe completarse con resultados reales de Supabase:

| Query                         |     Antes |   Después |    Mejora |
| ----------------------------- | --------: | --------: | --------: |
| Historial órdenes por usuario | Pendiente | Pendiente | Pendiente |
| Órdenes por estado            | Pendiente | Pendiente | Pendiente |
| Inventario por producto       | Pendiente | Pendiente | Pendiente |

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

PostgreSQL permite mantener integridad y consistencia fuerte en las operaciones críticas del negocio, como usuarios, órdenes, pagos e inventario. MongoDB aporta flexibilidad y escalabilidad para catálogo extendido, reseñas, comportamiento de usuario y analítica.

Las optimizaciones realizadas en MongoDB mostraron mejoras cuantitativas significativas. Los índices ESR, parciales y de relación redujeron de forma importante los documentos examinados. El pipeline analítico optimizado redujo el tiempo promedio de ejecución en 62.27%.

La evaluación también permitió identificar que no todos los índices son útiles. La productividad depende de la selectividad del campo y del patrón real de consulta.

Finalmente, el diseño teórico de sharding y replica sets proporciona una base para escalar la solución en un ambiente productivo, mientras que la sincronización basada en eventos permite mantener desacoplados los sistemas PostgreSQL y MongoDB.
