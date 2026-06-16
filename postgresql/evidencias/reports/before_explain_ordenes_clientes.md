| QUERY PLAN                                                                                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit  (cost=3054.70..3054.71 rows=1 width=82) (actual time=15.311..15.313 rows=1 loops=1)                                                                     |
|   Buffers: shared hit=1819                                                                                                                                     |
|   ->  Sort  (cost=3054.70..3054.71 rows=1 width=82) (actual time=15.309..15.310 rows=1 loops=1)                                                                |
|         Sort Key: o.order_purchase_timestamp DESC                                                                                                              |
|         Sort Method: quicksort  Memory: 25kB                                                                                                                   |
|         Buffers: shared hit=1819                                                                                                                               |
|         ->  GroupAggregate  (cost=3054.67..3054.69 rows=1 width=82) (actual time=14.604..14.605 rows=1 loops=1)                                                |
|               Group Key: o.order_id                                                                                                                            |
|               Buffers: shared hit=1816                                                                                                                         |
|               ->  Sort  (cost=3054.67..3054.67 rows=1 width=62) (actual time=14.589..14.591 rows=1 loops=1)                                                    |
|                     Sort Key: o.order_id                                                                                                                       |
|                     Sort Method: quicksort  Memory: 25kB                                                                                                       |
|                     Buffers: shared hit=1816                                                                                                                   |
|                     ->  Nested Loop  (cost=0.42..3054.66 rows=1 width=62) (actual time=3.432..14.546 rows=1 loops=1)                                           |
|                           Buffers: shared hit=1813                                                                                                             |
|                           ->  Seq Scan on orders o  (cost=0.00..3052.01 rows=1 width=50) (actual time=0.305..11.416 rows=1 loops=1)                            |
|                                 Filter: (customer_id = '68d03ff74911622915ef4ec24e2919a9'::text)                                                               |
|                                 Rows Removed by Filter: 99440                                                                                                  |
|                                 Buffers: shared hit=1809                                                                                                       |
|                           ->  Index Scan using order_items_pkey on order_items oi  (cost=0.42..2.64 rows=1 width=45) (actual time=3.121..3.123 rows=1 loops=1) |
|                                 Index Cond: (order_id = o.order_id)                                                                                            |
|                                 Buffers: shared hit=4                                                                                                          |
| Planning:                                                                                                                                                      |
|   Buffers: shared hit=231                                                                                                                                      |
| Planning Time: 18.872 ms                                                                                                                                       |
| Execution Time: 15.442 ms                                                                                                                                      |