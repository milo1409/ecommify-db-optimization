| QUERY PLAN                                                                                                                                          |
| --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit  (cost=9268.52..9268.55 rows=10 width=88) (actual time=911.953..911.960 rows=10 loops=1)                                                      |
|   Buffers: shared hit=4655                                                                                                                          |
|   ->  Sort  (cost=9268.52..9310.18 rows=16664 width=88) (actual time=911.952..911.956 rows=10 loops=1)                                              |
|         Sort Key: (count(r.review_internal_id)) DESC                                                                                                |
|         Sort Method: top-N heapsort  Memory: 26kB                                                                                                   |
|         Buffers: shared hit=4655                                                                                                                    |
|         ->  HashAggregate  (cost=8700.12..8908.42 rows=16664 width=88) (actual time=905.611..910.013 rows=9042 loops=1)                             |
|               Group Key: p.product_id                                                                                                               |
|               Batches: 1  Memory Usage: 2321kB                                                                                                      |
|               Buffers: shared hit=4652                                                                                                              |
|               ->  Hash Join  (cost=4516.81..8575.14 rows=16664 width=60) (actual time=843.666..895.607 rows=18109 loops=1)                          |
|                     Hash Cond: (oi.product_id = p.product_id)                                                                                       |
|                     Buffers: shared hit=4652                                                                                                        |
|                     ->  Hash Join  (cost=3338.41..7352.99 rows=16664 width=45) (actual time=831.140..873.748 rows=18109 loops=1)                    |
|                           Hash Cond: (oi.order_id = r.order_id)                                                                                     |
|                           Buffers: shared hit=4215                                                                                                  |
|                           ->  Seq Scan on order_items oi  (cost=0.00..3425.50 rows=112650 width=66) (actual time=0.018..11.430 rows=112650 loops=1) |
|                                 Buffers: shared hit=2299                                                                                            |
|                           ->  Hash  (cost=3156.30..3156.30 rows=14569 width=45) (actual time=831.048..831.049 rows=14575 loops=1)                   |
|                                 Buckets: 16384  Batches: 1  Memory Usage: 1224kB                                                                    |
|                                 Buffers: shared hit=1916                                                                                            |
|                                 ->  Seq Scan on reviews r  (cost=0.00..3156.30 rows=14569 width=45) (actual time=2.463..824.450 rows=14575 loops=1) |
|                                       Filter: (review_score <= 2)                                                                                   |
|                                       Rows Removed by Filter: 84649                                                                                 |
|                                       Buffers: shared hit=1916                                                                                      |
|                     ->  Hash  (cost=766.51..766.51 rows=32951 width=48) (actual time=12.248..12.249 rows=32951 loops=1)                             |
|                           Buckets: 65536  Batches: 1  Memory Usage: 3108kB                                                                          |
|                           Buffers: shared hit=437                                                                                                   |
|                           ->  Seq Scan on products p  (cost=0.00..766.51 rows=32951 width=48) (actual time=0.018..4.294 rows=32951 loops=1)         |
|                                 Buffers: shared hit=437                                                                                             |
| Planning:                                                                                                                                           |
|   Buffers: shared hit=255                                                                                                                           |
| Planning Time: 3.698 ms                                                                                                                             |
| Execution Time: 912.709 ms                                                                                                                          |