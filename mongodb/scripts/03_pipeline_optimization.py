"""
03_pipeline_optimization.py

Ejecuta el pipeline original y el pipeline optimizado sobre product_catalog
y product_reviews, mide tiempos promedio y exporta los resultados a CSV.

Uso:
    python mongodb/scripts/03_pipeline_optimization.py

Salida:
    mongodb/results/pipeline_results.csv
"""

import csv
import os
import time
from pathlib import Path

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.server_api import ServerApi


DATABASE_NAME = "ecommify_db"
RESULTS_DIR = Path(__file__).resolve().parents[1] / "results"


def get_database():
    load_dotenv()
    uri = os.getenv("MONGODB_URI")

    if not uri:
        raise ValueError("No se encontró MONGODB_URI.")

    client = MongoClient(uri, server_api=ServerApi("1"))
    client.admin.command("ping")
    return client[DATABASE_NAME]


pipeline_original = [
    {
        "$match": {
            "status": "ACTIVE",
            "category": {"$in": ["bed_bath_table", "health_beauty", "sports_leisure"]},
            "price": {"$gte": 20, "$lte": 1000},
        }
    },
    {
        "$lookup": {
            "from": "product_reviews",
            "localField": "_id",
            "foreignField": "product_id",
            "as": "reviews",
        }
    },
    {
        "$unwind": {
            "path": "$reviews",
            "preserveNullAndEmptyArrays": True,
        }
    },
    {
        "$group": {
            "_id": {
                "category": "$category",
                "seller_region": "$seller_region",
            },
            "total_products": {"$sum": 1},
            "avg_price": {"$avg": "$price"},
            "avg_rating": {"$avg": "$ratings.average"},
            "total_units_sold": {"$sum": "$metrics.total_units_sold"},
            "total_revenue": {"$sum": "$metrics.total_revenue"},
            "review_count": {
                "$sum": {
                    "$cond": [
                        {"$ifNull": ["$reviews._id", False]},
                        1,
                        0,
                    ]
                }
            },
        }
    },
    {
        "$addFields": {
            "sales_score": {
                "$multiply": ["$avg_rating", "$total_units_sold"]
            }
        }
    },
    {
        "$project": {
            "_id": 0,
            "category": "$_id.category",
            "seller_region": "$_id.seller_region",
            "total_products": 1,
            "avg_price": {"$round": ["$avg_price", 2]},
            "avg_rating": {"$round": ["$avg_rating", 2]},
            "total_units_sold": 1,
            "total_revenue": {"$round": ["$total_revenue", 2]},
            "review_count": 1,
            "sales_score": {"$round": ["$sales_score", 2]},
        }
    },
    {"$sort": {"sales_score": -1}},
    {"$limit": 10},
]


pipeline_optimized = [
    {
        "$match": {
            "status": "ACTIVE",
            "category": {"$in": ["bed_bath_table", "health_beauty", "sports_leisure"]},
            "price": {"$gte": 20, "$lte": 1000},
        }
    },
    {
        "$project": {
            "_id": 1,
            "category": 1,
            "seller_region": 1,
            "price": 1,
            "ratings.average": 1,
            "metrics.total_units_sold": 1,
            "metrics.total_revenue": 1,
        }
    },
    {
        "$lookup": {
            "from": "product_reviews",
            "localField": "_id",
            "foreignField": "product_id",
            "as": "reviews",
        }
    },
    {
        "$addFields": {
            "review_count": {"$size": "$reviews"}
        }
    },
    {
        "$group": {
            "_id": {
                "category": "$category",
                "seller_region": "$seller_region",
            },
            "total_products": {"$sum": 1},
            "avg_price": {"$avg": "$price"},
            "avg_rating": {"$avg": "$ratings.average"},
            "total_units_sold": {"$sum": "$metrics.total_units_sold"},
            "total_revenue": {"$sum": "$metrics.total_revenue"},
            "review_count": {"$sum": "$review_count"},
        }
    },
    {
        "$addFields": {
            "sales_score": {
                "$multiply": ["$avg_rating", "$total_units_sold"]
            }
        }
    },
    {
        "$project": {
            "_id": 0,
            "category": "$_id.category",
            "seller_region": "$_id.seller_region",
            "total_products": 1,
            "avg_price": {"$round": ["$avg_price", 2]},
            "avg_rating": {"$round": ["$avg_rating", 2]},
            "total_units_sold": 1,
            "total_revenue": {"$round": ["$total_revenue", 2]},
            "review_count": 1,
            "sales_score": {"$round": ["$sales_score", 2]},
        }
    },
    {"$sort": {"sales_score": -1}},
    {"$limit": 10},
]


def measure_pipeline_time(label, collection, pipeline, iterations=5):
    times = []

    result = []

    for _ in range(iterations):
        start = time.time()
        result = list(collection.aggregate(pipeline, allowDiskUse=True))
        end = time.time()
        elapsed_ms = round((end - start) * 1000, 2)
        times.append(elapsed_ms)

    avg_time = round(sum(times) / len(times), 2)

    return {
        "pipeline": label,
        "times_ms": times,
        "avg_time_ms": avg_time,
        "nReturned": len(result),
    }


def export_results(rows):
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    output_file = RESULTS_DIR / "pipeline_results.csv"

    original_time = rows[0]["avg_time_ms"]
    for row in rows:
        if row["pipeline"] == "Pipeline original":
            row["mejora_vs_original_%"] = 0
        else:
            row["mejora_vs_original_%"] = round(
                ((original_time - row["avg_time_ms"]) / original_time) * 100,
                2,
            )

    with output_file.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "pipeline",
                "times_ms",
                "avg_time_ms",
                "nReturned",
                "mejora_vs_original_%",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Resultados exportados en: {output_file}")


def main():
    db = get_database()
    product_catalog = db["product_catalog"]

    rows = [
        measure_pipeline_time("Pipeline original", product_catalog, pipeline_original),
        measure_pipeline_time("Pipeline optimizado", product_catalog, pipeline_optimized),
    ]

    for row in rows:
        print(row)

    export_results(rows)


if __name__ == "__main__":
    main()
