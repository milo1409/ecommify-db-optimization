"""
01_load_olist_dataset.py

Carga el dataset Olist Brazilian E-Commerce, lo transforma al modelo documental
de Ecommify y crea las colecciones principales en MongoDB Atlas:

- product_catalog
- product_reviews
- sellers
- user_behavior

Uso:
    1. Definir la variable de entorno MONGODB_URI.
    2. Ejecutar:
       python mongodb/scripts/01_load_olist_dataset.py

Requisitos:
    pip install pymongo pandas kagglehub python-dotenv
"""

import math
import os
from datetime import datetime

import kagglehub
import pandas as pd
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.server_api import ServerApi


DATABASE_NAME = "ecommify_db"


def get_database():
    load_dotenv()

    uri = os.getenv("MONGODB_URI")

    if not uri:
        raise ValueError(
            "No se encontró MONGODB_URI. Defina la variable en .env o en el entorno."
        )

    client = MongoClient(uri, server_api=ServerApi("1"))
    client.admin.command("ping")

    print("Conexión exitosa a MongoDB Atlas")
    return client[DATABASE_NAME]


def safe_value(value, default=None):
    if pd.isna(value):
        return default
    if isinstance(value, float) and math.isnan(value):
        return default
    return value


def read_olist_dataset():
    path = kagglehub.dataset_download("olistbr/brazilian-ecommerce")
    print("Path to dataset files:", path)

    products_df = pd.read_csv(os.path.join(path, "olist_products_dataset.csv"))
    items_df = pd.read_csv(os.path.join(path, "olist_order_items_dataset.csv"))
    reviews_df = pd.read_csv(os.path.join(path, "olist_order_reviews_dataset.csv"))
    orders_df = pd.read_csv(os.path.join(path, "olist_orders_dataset.csv"))
    sellers_df = pd.read_csv(os.path.join(path, "olist_sellers_dataset.csv"))
    customers_df = pd.read_csv(os.path.join(path, "olist_customers_dataset.csv"))
    category_translation_df = pd.read_csv(
        os.path.join(path, "product_category_name_translation.csv")
    )

    print("products:", products_df.shape)
    print("items:", items_df.shape)
    print("reviews:", reviews_df.shape)
    print("orders:", orders_df.shape)
    print("sellers:", sellers_df.shape)
    print("customers:", customers_df.shape)
    print("categories:", category_translation_df.shape)

    return {
        "products": products_df,
        "items": items_df,
        "reviews": reviews_df,
        "orders": orders_df,
        "sellers": sellers_df,
        "customers": customers_df,
        "category_translation": category_translation_df,
    }


def build_catalog_dataframe(dataframes):
    products_df = dataframes["products"].copy()
    items_df = dataframes["items"]
    reviews_df = dataframes["reviews"]
    sellers_df = dataframes["sellers"]
    category_translation_df = dataframes["category_translation"]

    products_df = products_df.merge(
        category_translation_df,
        on="product_category_name",
        how="left",
    )

    products_df["category"] = products_df["product_category_name_english"].fillna(
        products_df["product_category_name"]
    )

    sales_metrics = items_df.groupby("product_id").agg(
        total_units_sold=("order_item_id", "count"),
        avg_price=("price", "mean"),
        min_price=("price", "min"),
        max_price=("price", "max"),
        total_revenue=("price", "sum"),
        seller_id=("seller_id", "first"),
    ).reset_index()

    reviews_items = reviews_df.merge(
        items_df[["order_id", "product_id"]],
        on="order_id",
        how="left",
    )

    review_metrics = reviews_items.groupby("product_id").agg(
        average_rating=("review_score", "mean"),
        reviews_count=("review_id", "count"),
    ).reset_index()

    catalog_df = (
        products_df
        .merge(sales_metrics, on="product_id", how="left")
        .merge(review_metrics, on="product_id", how="left")
    )

    catalog_df = catalog_df.merge(
        sellers_df[["seller_id", "seller_state", "seller_city"]],
        on="seller_id",
        how="left",
    )

    catalog_df["seller_region"] = catalog_df["seller_state"].fillna("UNKNOWN")
    catalog_df["seller_city"] = catalog_df["seller_city"].fillna("UNKNOWN")

    return catalog_df


def build_product_document(row):
    product_id = row["product_id"]

    category = safe_value(row.get("category"), "unknown")
    price = safe_value(row.get("avg_price"), 0)
    total_units_sold = safe_value(row.get("total_units_sold"), 0)
    average_rating = safe_value(row.get("average_rating"), 0)
    reviews_count = safe_value(row.get("reviews_count"), 0)
    total_revenue = safe_value(row.get("total_revenue"), 0)

    return {
        "_id": str(product_id),
        "name": f"{category} product",
        "description": (
            f"Producto de la categoría {category} importado desde "
            "el dataset Olist Brazilian E-Commerce."
        ),
        "category": str(category),
        "price": round(float(price), 2) if price else 0,
        "currency": "BRL",
        "seller_id": str(safe_value(row.get("seller_id"), "UNKNOWN")),
        "seller_region": str(safe_value(row.get("seller_region"), "UNKNOWN")),
        "seller_city": str(safe_value(row.get("seller_city"), "UNKNOWN")),
        "status": "ACTIVE" if total_units_sold and total_units_sold > 0 else "INACTIVE",
        "attributes": {
            "weight_g": safe_value(row.get("product_weight_g"), 0),
            "length_cm": safe_value(row.get("product_length_cm"), 0),
            "height_cm": safe_value(row.get("product_height_cm"), 0),
            "width_cm": safe_value(row.get("product_width_cm"), 0),
            "photos_qty": safe_value(row.get("product_photos_qty"), 0),
            "name_length": safe_value(row.get("product_name_lenght"), 0),
            "description_length": safe_value(row.get("product_description_lenght"), 0),
        },
        "tags": [
            str(category).lower(),
            "olist",
            "ecommify",
            "catalog",
        ],
        "images": [],
        "ratings": {
            "average": round(float(average_rating), 2) if average_rating else 0,
            "count": int(reviews_count) if reviews_count else 0,
        },
        "metrics": {
            "total_units_sold": int(total_units_sold) if total_units_sold else 0,
            "views_count": int(total_units_sold * 10) if total_units_sold else 0,
            "conversion_rate": 0.05,
            "total_revenue": round(float(total_revenue), 2) if total_revenue else 0,
        },
        "recent_reviews": [],
        "source": {
            "dataset": "olistbr/brazilian-ecommerce",
            "original_product_category": str(safe_value(row.get("product_category_name"), "")),
        },
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
    }


def insert_product_catalog(db, catalog_df):
    collection = db["product_catalog"]
    collection.delete_many({})

    product_documents = [
        build_product_document(row)
        for _, row in catalog_df.iterrows()
    ]

    if product_documents:
        collection.insert_many(product_documents)

    print("Total productos insertados en product_catalog:", collection.count_documents({}))


def insert_product_reviews(db, dataframes):
    items_df = dataframes["items"]
    reviews_df = dataframes["reviews"]

    reviews_enriched = reviews_df.merge(
        items_df[["order_id", "product_id"]],
        on="order_id",
        how="left",
    )

    reviews_enriched = reviews_enriched.dropna(subset=["product_id"])
    reviews_enriched = reviews_enriched.drop_duplicates(
        subset=["review_id", "product_id"]
    )

    collection = db["product_reviews"]
    collection.delete_many({})

    review_documents = []

    for _, row in reviews_enriched.iterrows():
        review_documents.append({
            "_id": f"{row['review_id']}_{row['product_id']}",
            "review_id": str(row["review_id"]),
            "product_id": str(row["product_id"]),
            "order_id": str(row["order_id"]),
            "rating": int(row["review_score"]),
            "comment": (
                str(row["review_comment_message"])
                if pd.notna(row["review_comment_message"])
                else ""
            ),
            "title": (
                str(row["review_comment_title"])
                if pd.notna(row["review_comment_title"])
                else ""
            ),
            "verified_purchase": True,
            "created_at": (
                pd.to_datetime(row["review_creation_date"]).to_pydatetime()
                if pd.notna(row["review_creation_date"])
                else datetime.now()
            ),
            "answer_timestamp": (
                pd.to_datetime(row["review_answer_timestamp"]).to_pydatetime()
                if pd.notna(row["review_answer_timestamp"])
                else None
            ),
            "source": {
                "dataset": "olistbr/brazilian-ecommerce",
            },
        })

    batch_size = 5000
    for i in range(0, len(review_documents), batch_size):
        collection.insert_many(review_documents[i:i + batch_size])

    print("Total reseñas insertadas en product_reviews:", collection.count_documents({}))


def insert_sellers(db, sellers_df):
    collection = db["sellers"]
    collection.delete_many({})

    seller_documents = []

    for _, row in sellers_df.iterrows():
        seller_documents.append({
            "_id": str(row["seller_id"]),
            "seller_id": str(row["seller_id"]),
            "city": str(row["seller_city"]),
            "region": str(row["seller_state"]),
            "country": "BR",
            "active": True,
            "source": {
                "dataset": "olistbr/brazilian-ecommerce",
            },
            "created_at": datetime.now(),
            "updated_at": datetime.now(),
        })

    if seller_documents:
        collection.insert_many(seller_documents)

    print("Total sellers insertados:", collection.count_documents({}))


def insert_user_behavior(db, dataframes):
    items_df = dataframes["items"]
    orders_df = dataframes["orders"]

    order_items_customers = items_df.merge(
        orders_df[["order_id", "customer_id", "order_purchase_timestamp"]],
        on="order_id",
        how="left",
    )

    collection = db["user_behavior"]
    collection.delete_many({})

    behavior_documents = []

    for _, row in order_items_customers.iterrows():
        customer_id = str(row["customer_id"])
        product_id = str(row["product_id"])
        timestamp = (
            pd.to_datetime(row["order_purchase_timestamp"]).to_pydatetime()
            if pd.notna(row["order_purchase_timestamp"])
            else datetime.now()
        )

        behavior_documents.append({
            "userId": customer_id,
            "period": timestamp.strftime("%Y-%m"),
            "events": [
                {
                    "type": "VIEW_PRODUCT",
                    "productId": product_id,
                    "timestamp": timestamp,
                },
                {
                    "type": "ADD_TO_CART",
                    "productId": product_id,
                    "timestamp": timestamp,
                },
                {
                    "type": "PURCHASE",
                    "productId": product_id,
                    "timestamp": timestamp,
                },
            ],
            "source": {
                "dataset": "olistbr/brazilian-ecommerce",
                "order_id": str(row["order_id"]),
            },
            "created_at": datetime.now(),
        })

    batch_size = 5000
    for i in range(0, len(behavior_documents), batch_size):
        collection.insert_many(behavior_documents[i:i + batch_size])

    print("Total documentos insertados en user_behavior:", collection.count_documents({}))


def main():
    db = get_database()
    dataframes = read_olist_dataset()

    catalog_df = build_catalog_dataframe(dataframes)

    insert_product_catalog(db, catalog_df)
    insert_product_reviews(db, dataframes)
    insert_sellers(db, dataframes["sellers"])
    insert_user_behavior(db, dataframes)

    print("Carga completa de colecciones MongoDB Ecommify")


if __name__ == "__main__":
    main()
