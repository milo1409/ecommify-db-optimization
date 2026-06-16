# Ecommify DB Optimization

## Implementación optimizada de PostgreSQL y MongoDB para Ecommify

Este repositorio contiene la implementación técnica optimizada de los sistemas de bases de datos utilizados en el caso de estudio **Ecommify**, una plataforma de comercio electrónico híbrida que combina **PostgreSQL** para operaciones transaccionales críticas y **MongoDB** para catálogo flexible, reseñas, comportamiento de usuario y analítica.

El objetivo principal del proyecto es demostrar decisiones arquitectónicas justificadas y evidencias cuantitativas de mejora de rendimiento mediante:

* Diseño e implementación de esquemas relacionales en PostgreSQL.
* Diseño e implementación de colecciones documentales en MongoDB.
* Creación de índices optimizados.
* Evaluación de consultas críticas.
* Optimización de aggregation pipelines.
* Diseño teórico de sharding y replica sets.
* Monitoreo de rendimiento en MongoDB Atlas.
* Documentación de resultados antes y después de optimizar.

---

## Integrantes

* Daniel Porras
* Oscar Clavijo
* Camilo Porras

---

## Tecnologías utilizadas

### PostgreSQL

* PostgreSQL
* Supabase
* SQL
* EXPLAIN ANALYZE
* Índices B-Tree
* Índices GIN
* Particionamiento por rango

### MongoDB

* MongoDB Atlas
* MongoDB NoSQL
* PyMongo
* Google Colab
* KaggleHub
* Pandas
* Aggregation Framework
* `.explain("executionStats")`
* `$indexStats`
* Performance Advisor

---

## Dataset utilizado

Para la implementación de MongoDB se utilizó el dataset público:

```text
olistbr/brazilian-ecommerce
```

El dataset fue descargado desde Kaggle mediante `kagglehub`:

```python
import kagglehub

path = kagglehub.dataset_download("olistbr/brazilian-ecommerce")

print("Path to dataset files:", path)
```

Aunque el dataset original tiene estructura relacional basada en archivos CSV, fue transformado al modelo documental definido para Ecommify.

---

## Arquitectura de datos

La solución utiliza una arquitectura híbrida:

| Motor      | Uso principal                                                                  |
| ---------- | ------------------------------------------------------------------------------ |
| PostgreSQL | Usuarios, órdenes, pagos, inventario y datos transaccionales                   |
| MongoDB    | Catálogo extendido, reseñas, vendedores, comportamiento de usuario y analítica |

PostgreSQL conserva la consistencia fuerte para operaciones críticas del negocio, mientras que MongoDB permite flexibilidad estructural y escalabilidad para datos semiestructurados y analíticos.

---

## Estructura del repositorio

```text
ecommify-db-optimization/
├── README.md
├── postgresql/
│   ├── ddl/
│   │   ├── 01_schema.sql
│   │   ├── 02_indexes.sql
│   │   └── 03_partitioning.sql
│   ├── queries/
│   │   ├── critical_queries.sql
│   │   └── explain_analyze_results.md
│   └── evidencias/
│       ├── explain_before/
│       ├── explain_after/
│       └── charts/
├── mongodb/
│   ├── notebooks/
│   │   └── Mongodb_ecommify_optimization.ipynb
│   ├── scripts/
│   │   ├── 01_load_olist_dataset.py
│   │   ├── 02_create_indexes.py
│   │   ├── 03_pipeline_optimization.py
│   │   └── 04_sharding_replica_design.md
│   ├── results/
│   │   ├── index_productivity_results.csv
│   │   ├── pipeline_results.csv
│   │   └── index_usage_stats.csv
│   └── evidencias/
│       ├── atlas_metrics/
│       ├── performance_advisor/
│       ├── explain/
│       └── pipeline/
├── docs/
│   └── documento_tecnico_implementacion.md
└── evidencias/
    ├── mongodb/
    └── postgresql/
```

---

## Configuración del entorno

## 1. Requisitos previos

Para ejecutar el proyecto se requiere:

* Cuenta en MongoDB Atlas.
* Cluster MongoDB Atlas, preferiblemente M0 para pruebas académicas.
* Cuenta en Supabase.
* Proyecto PostgreSQL en Supabase.
* Google Colab o entorno local con Python 3.
* Acceso a internet para descargar el dataset desde Kaggle.

---

## 2. Configuración de MongoDB Atlas

### 2.1 Crear cluster

1. Ingresar a MongoDB Atlas.
2. Crear un proyecto llamado `Ecommify`.
3. Crear un cluster gratuito M0.
4. Crear un usuario de base de datos desde **Database Access**.
5. Configurar acceso de red desde **Network Access**.
6. Obtener el connection string desde **Connect > Drivers > Python**.

Ejemplo de connection string:

```text
mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify
```

> No se deben subir credenciales reales al repositorio.

---

## 3. Variables de entorno

Se recomienda usar variables de entorno para proteger las credenciales.

Crear un archivo `.env` local:

```env
MONGODB_URI=mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify
SUPABASE_DB_URL=postgresql://<usuario>:<password>@<host>:<puerto>/<database>
```

El archivo `.env` debe estar incluido en `.gitignore`.

---

## 4. Archivo `.gitignore`

Se recomienda incluir:

```gitignore
.env
*.env
__pycache__/
.ipynb_checkpoints/
*.pyc
.DS_Store
*.log
```

---

## 5. Instalación de dependencias

En Google Colab o entorno local:

```python
!pip install pymongo pandas kagglehub python-dotenv
```

Si se requiere soporte SRV para MongoDB:

```python
!pip install "pymongo[srv]"
```

---

## 6. Conexión a MongoDB desde Python

```python
from pymongo import MongoClient
from pymongo.server_api import ServerApi
import os

uri = os.getenv("MONGODB_URI")

client = MongoClient(uri, server_api=ServerApi("1"))

try:
    client.admin.command("ping")
    print("Conexión exitosa a MongoDB Atlas")
except Exception as e:
    print(e)

db = client["ecommify_db"]
```

En Google Colab también puede definirse la variable directamente durante pruebas académicas:

```python
uri = "mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify"
client = MongoClient(uri, server_api=ServerApi("1"))
db = client["ecommify_db"]
```

---

# Implementación MongoDB

## Colecciones creadas

| Colección         | Descripción                              |
| ----------------- | ---------------------------------------- |
| `product_catalog` | Catálogo extendido de productos          |
| `product_reviews` | Reseñas completas asociadas a productos  |
| `sellers`         | Información de vendedores                |
| `user_behavior`   | Eventos simulados de navegación y compra |
| `search_logs`     | Colección propuesta para búsquedas       |
| `recommendations` | Colección propuesta para recomendaciones |

---

## Carga del dataset Olist

```python
import kagglehub
import os
import pandas as pd

path = kagglehub.dataset_download("olistbr/brazilian-ecommerce")

products_df = pd.read_csv(os.path.join(path, "olist_products_dataset.csv"))
items_df = pd.read_csv(os.path.join(path, "olist_order_items_dataset.csv"))
reviews_df = pd.read_csv(os.path.join(path, "olist_order_reviews_dataset.csv"))
orders_df = pd.read_csv(os.path.join(path, "olist_orders_dataset.csv"))
sellers_df = pd.read_csv(os.path.join(path, "olist_sellers_dataset.csv"))
customers_df = pd.read_csv(os.path.join(path, "olist_customers_dataset.csv"))
category_translation_df = pd.read_csv(os.path.join(path, "product_category_name_translation.csv"))
```

---

## Transformación al modelo Ecommify

El dataset original fue transformado al modelo documental de Ecommify.

### `product_catalog`

Se construye a partir de:

* `olist_products_dataset.csv`
* `olist_order_items_dataset.csv`
* `olist_order_reviews_dataset.csv`
* `olist_sellers_dataset.csv`
* `product_category_name_translation.csv`

Ejemplo de documento:

```json
{
  "_id": "product_id",
  "name": "bed_bath_table product",
  "description": "Producto importado desde Olist",
  "category": "bed_bath_table",
  "price": 120.50,
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

### `product_reviews`

Se construye a partir de reseñas y productos asociados por `order_id`.

Relación lógica:

```text
product_reviews.product_id -> product_catalog._id
```

### `user_behavior`

Como el dataset no contiene navegación explícita, se simulan eventos a partir de órdenes reales:

* `VIEW_PRODUCT`
* `ADD_TO_CART`
* `PURCHASE`

---

## Índices implementados en MongoDB

| Colección         | Índice                                           | Tipo               | Objetivo                                            |
| ----------------- | ------------------------------------------------ | ------------------ | --------------------------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Compuesto ESR      | Optimizar consulta principal del catálogo           |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Compuesto ESR      | Optimizar ranking de productos más vendidos         |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Parcial            | Optimizar productos activos con reseñas suficientes |
| `product_catalog` | `idx_pc_text_name_description_tags`              | Texto              | Habilitar búsqueda full-text                        |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Simple             | Optimizar reseñas por producto y `$lookup`          |
| `product_reviews` | `idx_pr_rating_created_at`                       | Compuesto          | Optimizar reseñas negativas recientes               |
| `user_behavior`   | `idx_ub_user_period`                             | Compuesto          | Optimizar comportamiento por usuario y periodo      |
| `user_behavior`   | `idx_ub_event_type_period`                       | Multikey compuesto | Optimizar análisis por tipo de evento               |
| `sellers`         | `idx_sellers_region_city`                        | Compuesto          | Optimizar análisis geográfico                       |

---

## Creación de índices principales

```python
product_catalog.create_index(
    [
        ("category", 1),
        ("seller_region", 1),
        ("status", 1),
        ("ratings.average", -1),
        ("price", 1)
    ],
    name="idx_pc_esr_category_region_status_rating_price"
)

product_catalog.create_index(
    [
        ("status", 1),
        ("category", 1),
        ("metrics.total_units_sold", -1),
        ("price", 1)
    ],
    name="idx_pc_esr_status_category_units_price"
)

product_catalog.create_index(
    [
        ("category", 1),
        ("seller_region", 1),
        ("ratings.average", -1),
        ("price", 1)
    ],
    partialFilterExpression={
        "status": "ACTIVE",
        "ratings.count": {
            "$gte": 10
        }
    },
    name="idx_pc_partial_active_rating_price"
)

product_catalog.create_index(
    [
        ("name", "text"),
        ("description", "text"),
        ("tags", "text")
    ],
    name="idx_pc_text_name_description_tags"
)

product_reviews.create_index(
    [
        ("product_id", 1)
    ],
    name="idx_pr_product_id"
)
```

---

## Evaluación de productividad de índices

La productividad de índices se evaluó usando:

```python
cursor.explain()
```

Métricas analizadas:

| Métrica               | Descripción                                   |
| --------------------- | --------------------------------------------- |
| `nReturned`           | Documentos retornados                         |
| `totalDocsExamined`   | Documentos examinados                         |
| `totalKeysExamined`   | Claves de índice examinadas                   |
| `executionTimeMillis` | Tiempo de ejecución                           |
| `docsPerReturned`     | Documentos examinados por documento retornado |

---

## Resultados de productividad de índices

| Colección         | Índice evaluado                                  | Consulta evaluada                                       | Docs examinados antes | Docs examinados después | Tiempo antes | Tiempo después | Resultado                           |
| ----------------- | ------------------------------------------------ | ------------------------------------------------------- | --------------------: | ----------------------: | -----------: | -------------: | ----------------------------------- |
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Catálogo por categoría, región, estado, rating y precio |                32.951 |                   1.854 |        30 ms |           6 ms | Productivo                          |
| `product_catalog` | `idx_pc_esr_status_category_units_price`         | Productos activos más vendidos por categoría y precio   |                32.951 |                   2.219 |        30 ms |           7 ms | Productivo                          |
| `product_catalog` | `idx_pc_partial_active_rating_price`             | Productos activos con reseñas suficientes               |                32.951 |                     120 |        27 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `product_id_1` / `idx_pr_product_id`             | Reseñas por producto                                    |               102.172 |                       3 |        97 ms |           1 ms | Muy productivo                      |
| `product_reviews` | `idx_pr_rating_created_at`                       | Reseñas negativas recientes                             |               102.172 |                  15.275 |        78 ms |          74 ms | Productivo en documentos examinados |
| `user_behavior`   | `idx_ub_event_type_period`                       | Eventos `PURCHASE`                                      |               112.650 |                 112.650 |       176 ms |         190 ms | Baja productividad                  |
| `sellers`         | `idx_sellers_region_city`                        | Vendedores por región y ciudad                          |                 1.849 |                      41 |         2 ms |           1 ms | Muy productivo                      |

---

## Interpretación de índices

Los índices compuestos basados en la regla ESR fueron efectivos para consultas con filtros de igualdad, ordenamiento y rangos. En `product_catalog`, los índices redujeron significativamente los documentos examinados.

El índice parcial `idx_pc_partial_active_rating_price` fue el más eficiente, reduciendo los documentos examinados de 32.951 a 120.

El índice por `product_id` en `product_reviews` fue fundamental para consultas por producto y para optimizar operaciones `$lookup`.

El índice sobre `events.type` en `user_behavior` mostró baja productividad porque el evento `PURCHASE` aparece en una proporción alta de documentos, lo cual reduce la selectividad.

---

## Optimización del aggregation pipeline

Se desarrolló un pipeline complejo sobre `product_catalog` y `product_reviews` para analizar desempeño comercial por categoría y región del vendedor.

Stages utilizados:

| Stage        | Uso                                              |
| ------------ | ------------------------------------------------ |
| `$match`     | Filtrar productos activos por categoría y precio |
| `$lookup`    | Relacionar productos con reseñas                 |
| `$unwind`    | Procesar reseñas en la versión original          |
| `$group`     | Agrupar por categoría y región                   |
| `$addFields` | Calcular `sales_score`                           |
| `$project`   | Reducir campos de salida                         |
| `$sort`      | Ordenar por desempeño                            |
| `$limit`     | Limitar resultados                               |

---

## Técnicas de optimización aplicadas

* `$match` como primer stage.
* Uso de índices de apoyo.
* `$project` temprano.
* Reducción de documentos intermedios.
* Reemplazo de `$unwind` por `$size` en la versión optimizada.
* Uso de `allowDiskUse=True`.

---

## Resultados del pipeline

| Pipeline            | Tiempo promedio | Documentos retornados | Mejora vs original |
| ------------------- | --------------: | --------------------: | -----------------: |
| Pipeline original   |       959.52 ms |                    10 |                 0% |
| Pipeline optimizado |       362.02 ms |                    10 |             62.27% |

El pipeline optimizado redujo el tiempo promedio de ejecución en **62.27%**.

---

# Diseño teórico de sharding y replica sets

## Shard key final

Para `product_catalog` se propone:

```javascript
{
  "category": 1,
  "seller_region": 1,
  "_id": "hashed"
}
```

Justificación:

* `category`: optimiza consultas frecuentes por categoría.
* `seller_region`: permite análisis geográfico y segmentación regional.
* `_id hashed`: ayuda a distribuir documentos de forma uniforme.

---

## Comandos teóricos de sharding

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

Estos comandos no se ejecutan en MongoDB Atlas Free Tier. Se documentan como diseño teórico para un ambiente productivo.

---

## Replica set propuesto

| Nodo          | Rol       | Zona | Función                                      |
| ------------- | --------- | ---- | -------------------------------------------- |
| `mongo-rs-01` | Primary   | AZ-1 | Recibe escrituras                            |
| `mongo-rs-02` | Secondary | AZ-2 | Replica datos y atiende lecturas no críticas |
| `mongo-rs-03` | Secondary | AZ-3 | Replica datos y permite failover             |

---

## Read Preference y Write Concern

| Operación                 | Colección         | Read Preference      | Write Concern | Justificación                      |
| ------------------------- | ----------------- | -------------------- | ------------- | ---------------------------------- |
| Consulta general catálogo | `product_catalog` | `secondaryPreferred` | No aplica     | Reduce carga del Primary           |
| Crear producto            | `product_catalog` | `primary`            | `majority`    | Requiere durabilidad               |
| Actualizar precio         | `product_catalog` | `primary`            | `majority`    | Dato sensible                      |
| Registrar reseña          | `product_reviews` | `primary`            | `majority`    | Visible para usuarios              |
| Consultar reseñas         | `product_reviews` | `secondaryPreferred` | No aplica     | Tolera consistencia eventual       |
| Registrar navegación      | `user_behavior`   | No aplica            | `w:1`         | Evento masivo reprocesable         |
| Analítica comportamiento  | `user_behavior`   | `secondary`          | No aplica     | No requiere consistencia inmediata |
| Recomendaciones           | `recommendations` | `secondary`          | `w:1`         | Puede recalcularse                 |

---

# Monitoreo de rendimiento

El monitoreo se realizó mediante:

* MongoDB Atlas Metrics.
* MongoDB Atlas Performance Advisor.
* Query Profiler / Query Insights.
* `.explain("executionStats")`.
* `$indexStats`.

---

## Métricas monitoreadas

| Métrica             | Fuente                   | Uso                                         |
| ------------------- | ------------------------ | ------------------------------------------- |
| Queries por segundo | MongoDB Atlas Metrics    | Medir carga                                 |
| Latencia            | Atlas Metrics / Profiler | Detectar consultas lentas                   |
| Query Targeting     | Atlas Metrics            | Evaluar documentos escaneados vs retornados |
| Index Usage         | `$indexStats`            | Validar uso de índices                      |
| Docs Examined       | `.explain()`             | Medir eficiencia                            |
| Keys Examined       | `.explain()`             | Validar uso de índices                      |
| Execution Time      | `.explain()`             | Comparar rendimiento                        |
| Connections         | Atlas Metrics            | Evaluar concurrencia                        |
| CPU / Disk IOPS     | Atlas Metrics            | Detectar saturación                         |

---

# Implementación PostgreSQL

## Configuración en Supabase

1. Crear una cuenta en Supabase.
2. Crear un nuevo proyecto.
3. Abrir el SQL Editor.
4. Ejecutar los scripts ubicados en:

```text
postgresql/ddl/
```

5. Ejecutar queries críticas ubicadas en:

```text
postgresql/queries/
```

6. Capturar evidencias de `EXPLAIN ANALYZE`.

---

## Scripts DDL principales

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

CREATE TABLE ordenes (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT REFERENCES usuarios(id),
    total NUMERIC(12,2) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    metadata JSONB
);
```

---

## Índices PostgreSQL propuestos

```sql
CREATE INDEX idx_usuarios_email
ON usuarios(email);

CREATE INDEX idx_ordenes_usuario_fecha
ON ordenes(usuario_id, fecha_creacion DESC);

CREATE INDEX idx_ordenes_estado_fecha
ON ordenes(estado, fecha_creacion DESC);

CREATE INDEX idx_productos_atributos_gin
ON productos USING GIN (atributos);

CREATE INDEX idx_productos_tags_gin
ON productos USING GIN (tags);
```

---

# Sincronización entre PostgreSQL y MongoDB

La sincronización entre sistemas se plantea mediante eventos de dominio.

## Flujo de producto

1. Producto base se crea en PostgreSQL.
2. Se emite evento `PRODUCT_CREATED`.
3. MongoDB actualiza `product_catalog`.
4. El producto queda disponible para consultas flexibles.

## Flujo de orden

1. Orden se registra en PostgreSQL.
2. Se emite evento `ORDER_CREATED`.
3. MongoDB actualiza métricas de catálogo.
4. `user_behavior` registra eventos derivados.
5. El módulo analítico actualiza recomendaciones.

---

# Lecciones aprendidas

## Obstáculos encontrados

| Obstáculo                                  | Solución                                    |
| ------------------------------------------ | ------------------------------------------- |
| Dataset Olist relacional                   | Transformación a modelo documental          |
| Duplicados en reseñas                      | Eliminación por `review_id + product_id`    |
| Índices existentes con nombres automáticos | Reutilización del índice real con `hint()`  |
| Uso de sintaxis Mongo Shell en Colab       | Conversión a PyMongo                        |
| Free Tier sin sharding real                | Diseño teórico y simulación de distribución |
| Índices con baja selectividad              | Evaluación con `.explain()`                 |

---

## Limitaciones del Free Tier

MongoDB Atlas Free Tier permitió validar:

* Conexión.
* Carga de datos.
* Índices.
* Consultas.
* Pipelines.
* Métricas básicas.

Limitaciones:

* No permite sharding real.
* No permite configuración avanzada de replica sets.
* Tiene monitoreo limitado.
* No representa carga real de producción.
* Algunas métricas avanzadas pueden no estar disponibles.

Workarounds:

* Simulación de distribución across shards.
* Diseño teórico de sharding.
* Uso de `.explain("executionStats")`.
* Uso de `$indexStats`.
* Medición de tiempos desde notebook.

---

# Ejecución del proyecto

## MongoDB

1. Abrir el notebook:

```text
mongodb/notebooks/Mongodb_ecommify_optimization.ipynb
```

2. Instalar dependencias:

```python
!pip install pymongo pandas kagglehub
```

3. Configurar conexión a MongoDB Atlas.

4. Descargar dataset Olist.

5. Ejecutar carga de datos.

6. Crear colecciones:

```text
product_catalog
product_reviews
sellers
user_behavior
```

7. Crear índices.

8. Ejecutar consultas con `.explain()`.

9. Ejecutar pipeline original y optimizado.

10. Revisar métricas y resultados.

---

## PostgreSQL

1. Crear proyecto en Supabase.
2. Ejecutar scripts DDL:

```text
postgresql/ddl/01_schema.sql
```

3. Ejecutar índices:

```text
postgresql/ddl/02_indexes.sql
```

4. Ejecutar queries críticas:

```text
postgresql/queries/critical_queries.sql
```

5. Capturar resultados de `EXPLAIN ANALYZE`.

---

# Evidencias esperadas

## MongoDB

| Evidencia                      | Carpeta sugerida                          |
| ------------------------------ | ----------------------------------------- |
| Carga de dataset               | `mongodb/evidencias/load_dataset/`        |
| Índices creados                | `mongodb/evidencias/indexes/`             |
| Explain antes/después          | `mongodb/evidencias/explain/`             |
| Pipeline original y optimizado | `mongodb/evidencias/pipeline/`            |
| Atlas Metrics                  | `mongodb/evidencias/atlas_metrics/`       |
| Performance Advisor            | `mongodb/evidencias/performance_advisor/` |

## Evidencias PostgreSQL

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

# Conclusiones

La implementación optimizada de Ecommify evidencia que una arquitectura híbrida permite aprovechar las fortalezas de PostgreSQL y MongoDB.

PostgreSQL se mantiene como motor transaccional para operaciones críticas, mientras que MongoDB permite flexibilidad y rendimiento para catálogo extendido, reseñas, comportamiento y analítica.

Los resultados obtenidos en MongoDB muestran mejoras cuantitativas importantes. Los índices compuestos ESR, índices parciales y el índice por `product_id` redujeron de forma significativa los documentos examinados. El pipeline optimizado redujo el tiempo promedio de ejecución de 959.52 ms a 362.02 ms, con una mejora de 62.27%.

La evaluación también demostró que no todos los índices son productivos. La selectividad del campo y el patrón real de consulta son factores determinantes para decidir si un índice aporta valor.

Finalmente, el diseño teórico de sharding y replica sets permite proyectar la solución hacia una arquitectura escalable y tolerante a fallos en un ambiente productivo.

---

# Referencias

* MongoDB Manual. Indexes.
* MongoDB Manual. Aggregation Pipeline Optimization.
* MongoDB Manual. Sharding.
* MongoDB Manual. Replica Sets.
* MongoDB Atlas Performance Advisor.
* PostgreSQL Documentation. Indexes.
* PostgreSQL Documentation. EXPLAIN.
* Supabase Documentation.
* Olist Brazilian E-Commerce Dataset.
