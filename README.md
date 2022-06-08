# postgresql-performance

This repository is to document specific tweaks to PostgreSQL and the Senzing DDL that may be useful for larger installations.


## PostgreSQL 14
This version has specific improvements to the handling of transactions and idle connections that can give substantional benefits for running OLTP applications like Senzing.  You can see if you are being impacted by the on previous versions of PostgreSQL by running `perf top` and looking for GetSnapshotData using significant CPU while the system is under load.  In my tests, this function was the largest consumer of CPU on the entire system.  This optimization is automatically enabled when you install 14.

lz4 TOAST compression may be a small win as it has significantly higher compression speeds.  In theory this should reduce latency.  It can be enabled with default_toast_compression='lz4' on a new system.


## Partitioning
Partitioning can be very effective for Senzing.  Autovacuum, backup, and restore are all single threaded operations per table in PostgreSQL.  By partitioning Senzing, you can achieve substantially better parallelization of these operations.


## Governor
Recommend setting the thresholds to 1.2B/1.5B to allow for more time to vacuum.  Also, the smaller difference in the values can help prevent the cost of expensive "double vacuum" where a "pause" is needed immediately after the initial vacuum as the XID is not dropped far enough.  I saw a reduction from 2-4hrs to <1hr in wait time on average by doing this.


## Auto-vacuuming
Keep the system in regular vacuum as much as possible.  The aggressive vacuum causes massive IO, making the cost 100x more expensive.  Partitioning of the hottest tables can help regular autovacuum keep up longer.


