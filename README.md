# Ecommify DB Optimization

## Implementación optimizada de PostgreSQL y MongoDB para Ecommify

Este repositorio contiene la implementación técnica optimizada de los sistemas de bases de datos utilizados en el caso de estudio **Ecommify**, una plataforma de comercio electrónico híbrida que combina **PostgreSQL** y **MongoDB**.

La solución utiliza PostgreSQL para el modelo relacional transaccional basado en el dataset Olist y MongoDB para el modelo documental orientado a catálogo extendido, reseñas, comportamiento de usuario y análisis de rendimiento.

El proyecto documenta:

- Scripts DDL ejecutados en Supabase.
- Estrategia de indexación en PostgreSQL y MongoDB.
- Consultas críticas optimizadas.
- Evidencias `EXPLAIN (ANALYZE, BUFFERS)` en PostgreSQL.
- Evidencias `.explain("executionStats")` en MongoDB.
- Optimización de aggregation pipelines.
- Diseño teórico de sharding y replica sets.
- Monitoreo de rendimiento.
- Limitaciones del free tier y workarounds aplicados.

---

## Integrantes

- Daniel Porras
- Oscar Clavijo
- Camilo Porras

---

## Tecnologías utilizadas

### PostgreSQL

- PostgreSQL
- Supabase
- SQL
- `EXPLAIN (ANALYZE, BUFFERS)`
- Índices B-Tree
- Particionamiento por rango

### MongoDB

- MongoDB Atlas
- PyMongo
- Google Colab
- KaggleHub
- Pandas
- Aggregation Framework
- `.explain("executionStats")`
- `$indexStats`
- MongoDB Atlas Metrics
- MongoDB Atlas Performance Advisor

---

## Dataset utilizado

Se utilizó el dataset público:

```text
olistbr/brazilian-ecommerce
```

El dataset Olist fue usado de dos formas:

| Motor | Uso del dataset |
|---|---|
| PostgreSQL | Se cargó en estructura relacional normalizada |
| MongoDB | Se transformó a estructura documental para Ecommify |

En PostgreSQL se conservaron las tablas relacionales principales: `customers`, `sellers`, `products`, `orders`, `order_items`, `payments` y `reviews`.

En MongoDB se construyeron colecciones documentales como `product_catalog`, `product_reviews`, `sellers` y `user_behavior`.

---

## Arquitectura de datos

La solución utiliza una arquitectura híbrida:

| Motor | Responsabilidad |
|---|---|
| PostgreSQL | Núcleo transaccional, integridad referencial, consultas relacionales y consistencia fuerte |
| MongoDB | Catálogo extendido, reseñas, comportamiento de usuario, métricas precalculadas y analítica |

PostgreSQL y MongoDB representan el mismo dominio de negocio, pero no tienen la misma estructura física. PostgreSQL conserva un diseño relacional normalizado, mientras que MongoDB usa un modelo documental desnormalizado y optimizado para lectura.

---

## Nueva estructura del repositorio

```text
ecommify-db-optimization/
├── README.md
├── .gitignore
├── integrantes.txt
│
├── docs/
│   └── documento_tecnico_implementacion.md
│
├── postgresql/
│   ├── ddl/
│   │   ├── 01_schema.sql
│   │   ├── 02_indexes.sql
│   │   └── 03_partitioning.sql
│   │
│   ├── queries/
│   │   ├── 01_queries_before_index.sql
│   │   └── 02_queries_after_indexes.sql
│   │
│   ├── results/
│   │   └── postgresql_performance_results.csv
│   │
│   ├── notebooks/
│   │   └── metricas_optimizacion_indices.ipynb
│   │
│   └── evidencias/
│       ├── 01_Supabase.png
│       ├── 02_schema.png
│       ├── 03_import_data.png
│       ├── 04_conteos.png
│       ├── before_indices.png
│       ├── crear_indices.png
│       ├── after_indices.png
│       ├── crear_particiones.png
│       ├── particiones_creadas.png
│       ├── query_particionamiento_explain.png
│       ├── grafica_mejora_postgresql.png
│       ├── Grafica_Metricas_Rendimiento.png
│       └── reports/
│           ├── before_explain_ordenes_clientes.md
│           ├── after_explain_ordenes_clientes.md
│           ├── before_explain_categoria_mes.md
│           ├── after_explain_categoria_mes.md
│           ├── before_explain_vendedores_region.md
│           ├── after_explain_vendedores_region.md
│           ├── before_explain_reseñas_negativas.md
│           ├── after_explain_reseñas_negativas.md
│           └── explain_partition_pruning.md
│
├── mongodb/
│   ├── notebooks/
│   │   └── Mongodb_ecommify_U5_Act1.ipynb
│   │
│   ├── scripts/
│   │   ├── 01_load_olist_dataset.py
│   │   ├── 02_create_indexes.py
│   │   ├── 03_pipeline_optimization.py
│   │   └── 04_sharding_replica_design.md
│   │
│   ├── results/
│   │   ├── index_productivity_results.csv
│   │   ├── pipeline_results.csv
│   │   └── index_usage_stats.csv
│   │
│   └── evidencias/
│       ├── atlas_metrics/
│       ├── performance_advisor/
│       ├── explain/
│
└── evidencias/
    ├── postgresql/
    └── mongodb/
```

---

# Setup del proyecto

## 1. Requisitos previos

Para reproducir el proyecto se requiere:

- Cuenta en Supabase.
- Proyecto PostgreSQL creado en Supabase.
- Cuenta en MongoDB Atlas.
- Cluster MongoDB Atlas M0 o superior.
- Google Colab o entorno local con Python 3.
- Acceso a KaggleHub para descargar el dataset Olist.
- Git instalado localmente.
- Navegador web para cargar CSV y capturar evidencias.

---

## 2. Clonar el repositorio

```bash
git clone https://github.com/<usuario>/ecommify-db-optimization.git
cd ecommify-db-optimization
```

---

## 3. Configurar variables de entorno

Crear un archivo `.env` local en la raíz del proyecto:

```env
MONGODB_URI=mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify
SUPABASE_DB_URL=postgresql://<usuario>:<password>@<host>:<puerto>/<database>
```

> El archivo `.env` no debe subirse al repositorio.

---

## 4. Archivo `.gitignore`

El repositorio debe incluir un archivo `.gitignore` con el siguiente contenido mínimo:

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

# Setup PostgreSQL en Supabase

## 1. Crear proyecto en Supabase

1. Ingresar a Supabase.
2. Crear un nuevo proyecto.
3. Abrir el módulo **SQL Editor**.
4. Crear y ejecutar los scripts de la carpeta:

```text
postgresql/ddl/
```

---

## 2. Ejecutar DDL del esquema

Ejecutar:

```text
postgresql/ddl/01_schema.sql
```

Este script crea el esquema `ecommify` y las tablas principales:

| Tabla | Descripción |
|---|---|
| `customers` | Clientes del dataset Olist |
| `sellers` | Vendedores |
| `products` | Productos base |
| `orders` | Órdenes |
| `order_items` | Items de cada orden |
| `payments` | Pagos |
| `reviews` | Reseñas |

---

## 3. Importar CSV del dataset Olist

Los archivos se deben importar desde Supabase en el siguiente orden:

| Orden | Archivo CSV | Tabla destino |
|---:|---|---|
| 1 | `olist_customers_dataset.csv` | `ecommify.customers` |
| 2 | `olist_sellers_dataset.csv` | `ecommify.sellers` |
| 3 | `olist_products_dataset.csv` | `ecommify.products` |
| 4 | `olist_orders_dataset.csv` | `ecommify.orders` |
| 5 | `olist_order_items_dataset.csv` | `ecommify.order_items` |
| 6 | `olist_order_payments_dataset.csv` | `ecommify.payments` |
| 7 | `olist_order_reviews_dataset.csv` | `ecommify.reviews` |

---

## 4. Validar carga de datos

Ejecutar en Supabase:

```sql
SELECT 'customers' AS table_name, COUNT(*) FROM ecommify.customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM ecommify.sellers
UNION ALL
SELECT 'products', COUNT(*) FROM ecommify.products
UNION ALL
SELECT 'orders', COUNT(*) FROM ecommify.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM ecommify.order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM ecommify.payments
UNION ALL
SELECT 'reviews', COUNT(*) FROM ecommify.reviews;
```

Conteos esperados:

| Tabla | Registros |
|---|---:|
| `customers` | 99.441 |
| `sellers` | 3.095 |
| `products` | 32.951 |
| `orders` | 99.441 |
| `order_items` | 112.650 |
| `payments` | 103.886 |
| `reviews` | 99.224 |

---

## 5. Ejecutar queries críticas antes de índices

Ejecutar:

```text
postgresql/queries/01_queries_before_index.sql
```

Guardar los planes de ejecución en:

```text
postgresql/evidencias/reports/
```

---

## 6. Crear índices PostgreSQL

Ejecutar:

```text
postgresql/ddl/02_indexes.sql
```

Índices principales:

| Índice | Tabla | Objetivo |
|---|---|---|
| `idx_orders_customer_purchase_date` | `orders` | Historial de órdenes por cliente |
| `idx_order_items_order_id` | `order_items` | Join entre órdenes e items |
| `idx_orders_status_purchase_date` | `orders` | Filtro por estado y fecha |
| `idx_order_items_product_order` | `order_items` | Join productos, órdenes e items |
| `idx_products_category` | `products` | Agrupación por categoría |
| `idx_sellers_state_city` | `sellers` | Segmentación geográfica |
| `idx_order_items_seller_order` | `order_items` | Join por vendedor |
| `idx_reviews_score_order` | `reviews` | Reseñas por calificación y orden |

---

## 7. Ejecutar queries críticas después de índices

Ejecutar:

```text
postgresql/queries/02_queries_after_indexes.sql
```

Comparar los resultados con los planes previos usando:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

---

## 8. Ejecutar particionamiento

Ejecutar:

```text
postgresql/ddl/03_partitioning.sql
```

Este script crea la tabla `orders_partitioned` particionada por rango de fecha sobre `order_purchase_timestamp`.

Validar particionamiento con la evidencia:

```text
postgresql/evidencias/reports/explain_partition_pruning.md
```

---

## 9. Resultados PostgreSQL

| Query crítica | Tiempo antes | Tiempo después | Mejora |
|---|---:|---:|---:|
| Historial de órdenes por cliente | 15.442 ms | 9.210 ms | 40.36% |
| Ventas por categoría y mes | 1902.142 ms | 395.193 ms | 79.22% |
| Desempeño vendedores por región | 424.708 ms | 397.821 ms | 6.33% |
| Productos con reseñas negativas | 912.709 ms | 2408.446 ms | -163.87% |
| Órdenes particionadas por año | N/A | 26.825 ms | N/A |

La consulta de productos con reseñas negativas se conserva como evidencia porque demuestra que no todos los índices son productivos. El índice asociado presentó baja selectividad y aumentó el costo de ejecución.

---

# Setup MongoDB en Atlas y Google Colab

## 1. Crear cluster MongoDB Atlas

1. Ingresar a MongoDB Atlas.
2. Crear un proyecto llamado `Ecommify`.
3. Crear un cluster gratuito M0.
4. Crear un usuario desde **Database Access**.
5. Configurar acceso desde **Network Access**.
6. Copiar el connection string desde **Connect > Drivers > Python**.

Ejemplo:

```text
mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify
```

---

## 2. Abrir notebook

Abrir el notebook:

```text
mongodb/notebooks/Mongodb_ecommify_U5_Act1.ipynb
```

---

## 3. Instalar dependencias

En Google Colab:

```python
!pip install pymongo pandas kagglehub python-dotenv
!pip install "pymongo[srv]"
```

---

## 4. Conectar a MongoDB

```python
from pymongo import MongoClient
from pymongo.server_api import ServerApi
import os

uri = os.getenv("MONGODB_URI")

client = MongoClient(uri, server_api=ServerApi("1"))
client.admin.command("ping")

db = client["ecommify_db"]

product_catalog = db["product_catalog"]
product_reviews = db["product_reviews"]
sellers = db["sellers"]
user_behavior = db["user_behavior"]
```

En Colab también puede configurarse temporalmente:

```python
uri = "mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?appName=Ecommify"
```

---

## 5. Descargar dataset Olist

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

## 6. Crear colecciones MongoDB

Colecciones creadas:

| Colección | Descripción |
|---|---|
| `product_catalog` | Catálogo extendido de productos |
| `product_reviews` | Reseñas completas asociadas a productos |
| `sellers` | Información de vendedores |
| `user_behavior` | Eventos simulados de navegación y compra |
| `search_logs` | Colección propuesta para búsquedas |
| `recommendations` | Colección propuesta para recomendaciones |

---

## 7. Crear índices MongoDB

Los índices principales son:

| Colección | Índice | Tipo | Objetivo |
|---|---|---|---|
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | Compuesto ESR | Optimizar catálogo por categoría, región, estado, rating y precio |
| `product_catalog` | `idx_pc_esr_status_category_units_price` | Compuesto ESR | Optimizar ranking de productos más vendidos |
| `product_catalog` | `idx_pc_partial_active_rating_price` | Parcial | Optimizar productos activos con reseñas suficientes |
| `product_catalog` | `idx_pc_text_name_description_tags` | Texto | Búsqueda full-text |
| `product_reviews` | `product_id_1` / `idx_pr_product_id` | Simple | Reseñas por producto y `$lookup` |
| `product_reviews` | `idx_pr_rating_created_at` | Compuesto | Reseñas negativas recientes |
| `user_behavior` | `idx_ub_user_period` | Compuesto | Eventos por usuario y periodo |
| `user_behavior` | `idx_ub_event_type_period` | Multikey | Eventos por tipo |
| `sellers` | `idx_sellers_region_city` | Compuesto | Análisis geográfico |

---

## 8. Evaluar índices con `.explain()`

Las métricas evaluadas fueron:

| Métrica | Descripción |
|---|---|
| `nReturned` | Documentos retornados |
| `totalDocsExamined` | Documentos examinados |
| `totalKeysExamined` | Claves examinadas |
| `executionTimeMillis` | Tiempo de ejecución |
| `docsPerReturned` | Documentos examinados por resultado |

Resultados principales:

| Colección | Índice evaluado | Docs antes | Docs después | Tiempo antes | Tiempo después | Resultado |
|---|---|---:|---:|---:|---:|---|
| `product_catalog` | `idx_pc_esr_category_region_status_rating_price` | 32.951 | 1.854 | 30 ms | 6 ms | Productivo |
| `product_catalog` | `idx_pc_esr_status_category_units_price` | 32.951 | 2.219 | 30 ms | 7 ms | Productivo |
| `product_catalog` | `idx_pc_partial_active_rating_price` | 32.951 | 120 | 27 ms | 1 ms | Muy productivo |
| `product_reviews` | `product_id_1` / `idx_pr_product_id` | 102.172 | 3 | 97 ms | 1 ms | Muy productivo |
| `product_reviews` | `idx_pr_rating_created_at` | 102.172 | 15.275 | 78 ms | 74 ms | Productivo en documentos examinados |
| `user_behavior` | `idx_ub_event_type_period` | 112.650 | 112.650 | 176 ms | 190 ms | Baja productividad |
| `sellers` | `idx_sellers_region_city` | 1.849 | 41 | 2 ms | 1 ms | Muy productivo |

---

## 9. Ejecutar aggregation pipeline

El pipeline optimizado incluye:

- `$match`
- `$lookup`
- `$group`
- `$addFields`
- `$project`
- `$sort`
- `$limit`

Resultados:

| Pipeline | Tiempo promedio | Documentos retornados | Mejora |
|---|---:|---:|---:|
| Pipeline original | 959.52 ms | 10 | 0% |
| Pipeline optimizado | 362.02 ms | 10 | 62.27% |

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

Esta shard key balancea consultas frecuentes por categoría y región con distribución uniforme mediante `_id hashed`.

---

## Replica set propuesto

| Nodo | Rol | Zona | Función |
|---|---|---|---|
| `mongo-rs-01` | Primary | AZ-1 | Recibe escrituras |
| `mongo-rs-02` | Secondary | AZ-2 | Replica datos y atiende lecturas |
| `mongo-rs-03` | Secondary | AZ-3 | Replica datos y permite failover |

---

# Evidencias del repositorio

## Evidencias PostgreSQL

| Evidencia | Ruta |
|---|---|
| Proyecto Supabase | `postgresql/evidencias/01_Supabase.png` |
| DDL ejecutado | `postgresql/evidencias/02_schema.png` |
| Carga de datos | `postgresql/evidencias/03_import_data.png` |
| Conteo de registros | `postgresql/evidencias/04_conteos.png` |
| Índices antes | `postgresql/evidencias/before_indices.png` |
| Creación de índices | `postgresql/evidencias/crear_indices.png` |
| Índices después | `postgresql/evidencias/after_indices.png` |
| Particionamiento | `postgresql/evidencias/crear_particiones.png` |
| Partition pruning | `postgresql/evidencias/query_particionamiento_explain.png` |
| Reportes EXPLAIN | `postgresql/evidencias/reports/` |
| Gráficas | `postgresql/evidencias/grafica_mejora_postgresql.png` |

## Evidencias MongoDB

| Evidencia | Ruta |
|---|---|
| Notebook documentado | `mongodb/notebooks/Mongodb_ecommify_U5_Act1.ipynb` |
| Resultados de índices | `mongodb/results/index_productivity_results.csv` |
| Resultados de pipeline | `mongodb/results/pipeline_results.csv` |
| Evidencias explain | `mongodb/evidencias/explain/` |
| Evidencias pipeline | `mongodb/evidencias/pipeline/` |
| Atlas Metrics | `mongodb/evidencias/atlas_metrics/` |
| Performance Advisor | `mongodb/evidencias/performance_advisor/` |

---

# Sincronización PostgreSQL - MongoDB

La sincronización entre sistemas se plantea mediante eventos de dominio:

| Evento | Origen | Destino | Resultado |
|---|---|---|---|
| `PRODUCT_CREATED` | PostgreSQL | MongoDB | Actualiza `product_catalog` |
| `PRODUCT_UPDATED` | PostgreSQL | MongoDB | Actualiza catálogo extendido |
| `ORDER_CREATED` | PostgreSQL | MongoDB | Actualiza métricas y comportamiento |
| `REVIEW_CREATED` | PostgreSQL / servicio de reseñas | MongoDB | Actualiza `product_reviews` y ratings |

PostgreSQL es la fuente de verdad para órdenes, pagos e inventario. MongoDB funciona como proyección documental para lectura, análisis y recomendaciones.

---

# Limitaciones del free tier

| Plataforma | Limitación | Workaround |
|---|---|---|
| MongoDB Atlas M0 | No permite sharding real | Diseño teórico y simulación |
| MongoDB Atlas M0 | Métricas avanzadas limitadas | Uso de `.explain()` y `$indexStats` |
| MongoDB Atlas M0 | Recursos limitados | Dataset académico y mediciones controladas |
| Supabase Free Tier | Recursos compartidos | Comparación antes/después |
| Supabase Free Tier | Sin arquitectura multi-nodo | Diseño teórico documentado |

---

# Conclusiones

La implementación optimizada de Ecommify evidencia que PostgreSQL y MongoDB cumplen roles complementarios dentro de una arquitectura híbrida.

PostgreSQL permitió representar el núcleo transaccional mediante tablas relacionales normalizadas y consultas optimizadas con índices, `EXPLAIN ANALYZE` y particionamiento.

MongoDB permitió construir un modelo documental flexible para catálogo extendido, reseñas, comportamiento de usuario y analítica. Los índices ESR, parciales y de relación redujeron significativamente los documentos examinados. El pipeline optimizado redujo el tiempo promedio de ejecución en **62.27%**.

La evaluación demostró que no todos los índices son productivos. La selectividad del campo y el patrón de consulta son factores determinantes para decidir si un índice aporta valor.

Finalmente, el diseño teórico de sharding, replica sets y sincronización por eventos permite proyectar la solución hacia un ambiente productivo escalable, resiliente y consistente.
