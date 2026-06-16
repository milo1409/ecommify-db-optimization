| QUERY PLAN                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit  (cost=5.33..5.33 rows=1 width=82) (actual time=9.074..9.076 rows=1 loops=1)                                                                                        |
|   Buffers: shared hit=10 read=4                                                                                                                                           |
|   ->  Sort  (cost=5.33..5.33 rows=1 width=82) (actual time=9.072..9.073 rows=1 loops=1)                                                                                   |
|         Sort Key: o.order_purchase_timestamp DESC                                                                                                                         |
|         Sort Method: quicksort  Memory: 25kB                                                                                                                              |
|         Buffers: shared hit=10 read=4                                                                                                                                     |
|         ->  GroupAggregate  (cost=5.29..5.32 rows=1 width=82) (actual time=9.045..9.046 rows=1 loops=1)                                                                   |
|               Group Key: o.order_id                                                                                                                                       |
|               Buffers: shared hit=7 read=4                                                                                                                                |
|               ->  Sort  (cost=5.29..5.29 rows=1 width=62) (actual time=9.033..9.034 rows=1 loops=1)                                                                       |
|                     Sort Key: o.order_id                                                                                                                                  |
|                     Sort Method: quicksort  Memory: 25kB                                                                                                                  |
|                     Buffers: shared hit=7 read=4                                                                                                                          |
|                     ->  Nested Loop  (cost=0.83..5.28 rows=1 width=62) (actual time=8.411..8.415 rows=1 loops=1)                                                          |
|                           Buffers: shared hit=4 read=4                                                                                                                    |
|                           ->  Index Scan using idx_orders_customer_purchase_date on orders o  (cost=0.42..2.64 rows=1 width=50) (actual time=5.494..5.495 rows=1 loops=1) |
|                                 Index Cond: (customer_id = '68d03ff74911622915ef4ec24e2919a9'::text)                                                                      |
|                                 Buffers: shared hit=1 read=3                                                                                                              |
|                           ->  Index Scan using idx_order_items_order_id on order_items oi  (cost=0.42..2.64 rows=1 width=45) (actual time=2.907..2.909 rows=1 loops=1)    |
|                                 Index Cond: (order_id = o.order_id)                                                                                                       |
|                                 Buffers: shared hit=3 read=1                                                                                                              |
| Planning:                                                                                                                                                                 |
|   Buffers: shared hit=325 read=11                                                                                                                                         |
| Planning Time: 42.242 ms                                                                                                                                                  |
| Execution Time: 9.210 ms                                                                                                                                                  |