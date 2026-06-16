"""
02_create_indexes.py

Crea índices de optimización en las colecciones MongoDB de Ecommify.

Uso:
    python mongodb/scripts/02_create_indexes.py

Requisitos:
    - MONGODB_URI configurado.
    - Colecciones cargadas previamente con 01_load_olist_dataset.py.
"""

import os

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.server_api import ServerApi


DATABASE_NAME = "ecommify_db"


def get_database():
    load_dotenv()
    uri = os.getenv("MONGODB_URI")

    if not uri:
        raise ValueError("No se encontró MONGODB_URI.")

    client = MongoClient(uri, server_api=ServerApi("1"))
    client.admin.command("ping")
    return client[DATABASE_NAME]


def create_index_if_not_exists(collection, keys, name, **kwargs):
    existing_names = [idx["name"] for idx in collection.list_indexes()]

    if name in existing_names:
        print(f"El índice ya existe: {collection.name}.{name}")
        return name

    created = collection.create_index(keys, name=name, **kwargs)
    print(f"Índice creado: {collection.name}.{created}")
    return created


def main():
    db = get_database()

    product_catalog = db["product_catalog"]
    product_reviews = db["product_reviews"]
    user_behavior = db["user_behavior"]
    sellers = db["sellers"]

    # product_catalog: índices ESR y parcial
    create_index_if_not_exists(
        product_catalog,
        [
            ("category", 1),
            ("seller_region", 1),
            ("status", 1),
            ("ratings.average", -1),
            ("price", 1),
        ],
        "idx_pc_esr_category_region_status_rating_price",
    )

    create_index_if_not_exists(
        product_catalog,
        [
            ("status", 1),
            ("category", 1),
            ("metrics.total_units_sold", -1),
            ("price", 1),
        ],
        "idx_pc_esr_status_category_units_price",
    )

    create_index_if_not_exists(
        product_catalog,
        [
            ("category", 1),
            ("seller_region", 1),
            ("ratings.average", -1),
            ("price", 1),
        ],
        "idx_pc_partial_active_rating_price",
        partialFilterExpression={
            "status": "ACTIVE",
            "ratings.count": {"$gte": 10},
        },
    )

    create_index_if_not_exists(
        product_catalog,
        [
            ("name", "text"),
            ("description", "text"),
            ("tags", "text"),
        ],
        "idx_pc_text_name_description_tags",
    )

    # product_reviews
    create_index_if_not_exists(
        product_reviews,
        [("product_id", 1)],
        "idx_pr_product_id",
    )

    create_index_if_not_exists(
        product_reviews,
        [
            ("product_id", 1),
            ("rating", -1),
        ],
        "idx_pr_partial_verified_product_rating",
        partialFilterExpression={"verified_purchase": True},
    )

    create_index_if_not_exists(
        product_reviews,
        [
            ("rating", 1),
            ("created_at", -1),
        ],
        "idx_pr_rating_created_at",
    )

    # user_behavior
    create_index_if_not_exists(
        user_behavior,
        [
            ("userId", 1),
            ("period", 1),
        ],
        "idx_ub_user_period",
    )

    create_index_if_not_exists(
        user_behavior,
        [
            ("events.type", 1),
            ("period", 1),
        ],
        "idx_ub_event_type_period",
    )

    create_index_if_not_exists(
        user_behavior,
        [
            ("period", 1),
            ("userId", 1),
        ],
        "idx_ub_partial_purchase_period_user",
        partialFilterExpression={"events.type": "PURCHASE"},
    )

    # sellers
    create_index_if_not_exists(
        sellers,
        [("region", 1)],
        "idx_sellers_region",
    )

    create_index_if_not_exists(
        sellers,
        [
            ("region", 1),
            ("city", 1),
        ],
        "idx_sellers_region_city",
    )

    # Índices de apoyo para aggregation pipeline
    create_index_if_not_exists(
        product_catalog,
        [
            ("status", 1),
            ("category", 1),
            ("seller_region", 1),
            ("price", 1),
        ],
        "idx_pipeline_match_catalog",
    )

    print("Creación de índices finalizada")


if __name__ == "__main__":
    main()
