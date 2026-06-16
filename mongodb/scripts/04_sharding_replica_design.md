# Diseño teórico de sharding y replica sets

## Contexto

El diseño de sharding y replica sets se documenta de forma teórica debido a que el ambiente utilizado corresponde a **MongoDB Atlas Free Tier**. Este entorno permite validar consultas, índices y pipelines, pero no permite implementar un sharded cluster real con múltiples shards, config servers y routers `mongos`.

---

## Shard key final para `product_catalog`

Para la colección `product_catalog` se propone la siguiente shard key compuesta:

```javascript
{
  "category": 1,
  "seller_region": 1,
  "_id": "hashed"
}
```

## Justificación de la shard key

| Campo | Justificación |
|---|---|
| `category` | Optimiza consultas frecuentes por categoría de producto |
| `seller_region` | Permite segmentación regional y análisis geográfico |
| `_id hashed` | Ayuda a distribuir documentos de forma uniforme entre shards |

La clave compuesta busca balancear eficiencia de consulta y distribución. Usar únicamente `category` podría generar hotspots en categorías populares. Usar únicamente `_id hashed` distribuiría bien los documentos, pero no favorecería consultas frecuentes por categoría o región.

---

## Configuración teórica de sharding

En un ambiente productivo, la configuración sería:

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

Estos comandos no se ejecutan en Atlas Free Tier. Se documentan como referencia arquitectónica.

---

## Simulación de distribución across shards

Para simular distribución se puede usar una función hash sobre la clave compuesta `category + seller_region + _id` y distribuir documentos sobre tres shards lógicos:

```python
import hashlib
from collections import Counter

def simulate_compound_shard(category, seller_region, product_id, num_shards=3):
    compound_key = f"{category}_{seller_region}_{product_id}"
    hash_value = int(hashlib.md5(compound_key.encode()).hexdigest(), 16)
    return f"shard_{(hash_value % num_shards) + 1}"
```

Una distribución cercana al 33% por shard indica balance adecuado para tres shards.

---

## Sharding propuesto para otras colecciones

| Colección | Shard key propuesta | Justificación |
|---|---|---|
| `product_catalog` | `{ category: 1, seller_region: 1, _id: "hashed" }` | Balance entre consultas de catálogo y distribución |
| `product_reviews` | `{ product_id: "hashed" }` | Distribuye reseñas y evita concentración en productos populares |
| `user_behavior` | `{ userId: "hashed", period: 1 }` | Distribuye usuarios y organiza eventos por periodo |
| `search_logs` | `{ created_at: 1, _id: "hashed" }` | Permite consultas temporales y distribución uniforme |
| `recommendations` | `{ user_id: "hashed" }` | Optimiza recomendaciones por usuario |

---

## Replica set propuesto

Se propone un replica set de tres nodos en distintas zonas de disponibilidad.

| Nodo | Rol | Zona | Función |
|---|---|---|---|
| `mongo-rs-01` | Primary | AZ-1 | Recibe escrituras |
| `mongo-rs-02` | Secondary | AZ-2 | Replica datos y atiende lecturas no críticas |
| `mongo-rs-03` | Secondary | AZ-3 | Replica datos y permite failover |

Esta configuración permite alta disponibilidad. Si el nodo Primary falla, los nodos Secondary pueden elegir automáticamente un nuevo Primary.

No se recomienda utilizar Arbiter porque no almacena datos. Para Ecommify es preferible contar con tres nodos completos con datos replicados.

---

## Read Preference y Write Concern

| Operación | Colección | Read Preference | Write Concern | Justificación |
|---|---|---|---|---|
| Consulta general de catálogo | `product_catalog` | `secondaryPreferred` | No aplica | Reduce carga del Primary |
| Detalle de producto | `product_catalog` | `secondaryPreferred` | No aplica | Tolera una pequeña demora |
| Creación de producto | `product_catalog` | `primary` | `majority` | Requiere durabilidad |
| Actualización de precio | `product_catalog` | `primary` | `majority` | Dato sensible para negocio |
| Actualización de métricas | `product_catalog` | `secondaryPreferred` | `w:1` | Métricas reprocesables |
| Registro de reseña | `product_reviews` | `primary` | `majority` | Información visible para usuarios |
| Consulta de reseñas | `product_reviews` | `secondaryPreferred` | No aplica | Tolera consistencia eventual |
| Evento de navegación | `user_behavior` | No aplica | `w:1` | Evento masivo y reprocesable |
| Analítica de comportamiento | `user_behavior` | `secondary` | No aplica | No requiere consistencia inmediata |
| Recomendaciones | `recommendations` | `secondary` | `w:1` | Puede recalcularse |
| Logs de búsqueda | `search_logs` | `secondary` | `w:1` | Dato analítico de alto volumen |

---

## Consistencia eventual

La consistencia eventual es aceptable para recomendaciones, navegación, logs de búsqueda y métricas aproximadas. No se recomienda para operaciones sensibles como pagos, órdenes, inventario o actualización crítica de precios.

## Mitigaciones

- Leer desde Primary en operaciones críticas.
- Usar `writeConcern: majority` en cambios importantes.
- Usar eventos idempotentes.
- Monitorear `replication lag`.
- Reprocesar métricas periódicamente.
- Mantener pagos, órdenes e inventario en PostgreSQL.
