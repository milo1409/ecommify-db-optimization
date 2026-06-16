| QUERY PLAN                                                                                                                                                |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit  (cost=18273.01..18273.04 rows=10 width=86) (actual time=423.647..423.655 rows=10 loops=1)                                                          |
|   Buffers: shared hit=4147, temp read=1288 written=1291                                                                                                   |
|   ->  Sort  (cost=18273.01..18274.52 rows=605 width=86) (actual time=423.646..423.652 rows=10 loops=1)                                                    |
|         Sort Key: (sum(oi.price)) DESC                                                                                                                    |
|         Sort Method: top-N heapsort  Memory: 26kB                                                                                                         |
|         Buffers: shared hit=4147, temp read=1288 written=1291                                                                                             |
|         ->  GroupAggregate  (cost=17598.51..18259.94 rows=605 width=86) (actual time=364.341..423.521 rows=251 loops=1)                                   |
|               Group Key: s.seller_city                                                                                                                    |
|               Buffers: shared hit=4144, temp read=1288 written=1291                                                                                       |
|               ->  Sort  (cost=17598.51..17761.60 rows=65235 width=53) (actual time=364.322..400.387 rows=78604 loops=1)                                   |
|                     Sort Key: s.seller_city, o.order_id                                                                                                   |
|                     Sort Method: external merge  Disk: 4904kB                                                                                             |
|                     Buffers: shared hit=4144, temp read=1288 written=1291                                                                                 |
|                     ->  Hash Join  (cost=5105.70..11073.98 rows=65235 width=53) (actual time=44.697..157.794 rows=78604 loops=1)                          |
|                           Hash Cond: (oi.order_id = o.order_id)                                                                                           |
|                           Buffers: shared hit=4141, temp read=675 written=675                                                                             |
|                           ->  Hash Join  (cost=94.80..3816.41 rows=67299 width=53) (actual time=1.045..52.240 rows=80342 loops=1)                         |
|                                 Hash Cond: (oi.seller_id = s.seller_id)                                                                                   |
|                                 Buffers: shared hit=2332                                                                                                  |
|                                 ->  Seq Scan on order_items oi  (cost=0.00..3425.50 rows=112650 width=72) (actual time=0.019..11.917 rows=112650 loops=1) |
|                                       Buffers: shared hit=2299                                                                                            |
|                                 ->  Hash  (cost=71.69..71.69 rows=1849 width=47) (actual time=1.013..1.014 rows=1849 loops=1)                             |
|                                       Buckets: 2048  Batches: 1  Memory Usage: 159kB                                                                      |
|                                       Buffers: shared hit=33                                                                                              |
|                                       ->  Seq Scan on sellers s  (cost=0.00..71.69 rows=1849 width=47) (actual time=0.011..0.525 rows=1849 loops=1)       |
|                                             Filter: (seller_state = 'SP'::text)                                                                           |
|                                             Rows Removed by Filter: 1246                                                                                  |
|                                             Buffers: shared hit=33                                                                                        |
|                           ->  Hash  (cost=3052.01..3052.01 rows=96391 width=33) (actual time=43.403..43.403 rows=96478 loops=1)                           |
|                                 Buckets: 65536  Batches: 2  Memory Usage: 3569kB                                                                          |
|                                 Buffers: shared hit=1809, temp written=312                                                                                |
|                                 ->  Seq Scan on orders o  (cost=0.00..3052.01 rows=96391 width=33) (actual time=0.016..19.031 rows=96478 loops=1)         |
|                                       Filter: (order_status = 'delivered'::text)                                                                          |
|                                       Rows Removed by Filter: 2963                                                                                        |
|                                       Buffers: shared hit=1809                                                                                            |
| Planning:                                                                                                                                                 |
|   Buffers: shared hit=258                                                                                                                                 |
| Planning Time: 1.310 ms                                                                                                                                   |
| Execution Time: 424.708 ms                                                                                                                                |