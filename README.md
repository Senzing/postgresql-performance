# postgresql-performance

This repository is to document specific tweaks to PostgreSQL and the Senzing DDL that may be useful for larger installations.


## Fundamentals
A DBA needs to tune PostgreSQL for the available hardware... shared_buffers, worker memory, IO, etc.  The one "unusual" thing about Senzing is that it largerly runs in auto-commit mode which means that commit performance has a lot to do with overall performance, 10x+ so.  You can check single connection insert performance with `G2Command` and the `checkDBPerf -s 3` command.  Ideally you should get <.5ms per insert or 6000 inserts in 3 seconds.  Many systems, even cloud systems, will achieve .1-.3ms.

The primary configuration parameter to improve commit performance is to turn off disk flushes on commit with `synchronous_commit=off`.

There is more to pay attention to on your system though.  For instance, if replication is done synchronously then you end up with the same problem.  On AWS Aurora, replication to a different AZ forces synchronous commit back on.  As you are looking at the design of your database infrastructure, you will need to take these things into consideration.  To simplify things, customers will often do the initial historical loads without replication and set it up afterward when the DB performance needs tend to be much lower.


## PostgreSQL 14
This version has specific improvements to the handling of transactions and idle connections that can give substantional benefits for running OLTP applications like Senzing.  You can see if you are being impacted by the on previous versions of PostgreSQL by running `perf top` and looking for GetSnapshotData using significant CPU while the system is under load.  In my tests, this function was the largest consumer of CPU on the entire system.  This optimization is automatically enabled when you install 14.

lz4 TOAST compression may be a small win as it has significantly higher compression speeds.  In theory this should reduce latency.  It can be enabled with `default_toast_compression='lz4'` on a new system.


## Partitioning
Partitioning can be very effective for Senzing.  Autovacuum, backup, and restore are all single threaded operations per table in PostgreSQL.  By partitioning Senzing, you can achieve substantially better parallelization of these operations.


## Governor
Recommend setting the thresholds to 1.2B/1.5B to allow for more time to vacuum.  Also, the smaller difference in the values can help prevent the cost of expensive "double vacuum" where a "pause" is needed immediately after the initial vacuum as the XID is not dropped far enough.  I saw a reduction from 2-4hrs to <1hr in wait time on average by doing this.


## Auto-vacuuming
Keep the system in regular vacuum as much as possible.  The aggressive vacuum causes massive IO, making the cost 100x more expensive.  Partitioning of the hottest tables can help regular autovacuum keep up longer.


## Fillfactor
When PostgreSQL updates a record it creates a new version (a copy) of the record with the update.  If this can be done 1) without modifying an index and 2) with putting the copy in the same page as the old version, then this change does not contribute to additional vacuum workload.  In fact, the old copies can even be cleaned up during select operations.

The problem is that PostgreSQL by default fills 100% of a page in a table before splitting.  This means that there likely won't be room for this operation and some Senzing tables are updated frequently.  The negative of reducing the fillfactor is that it may increase diskspace.  You may want to experiment with this yourself but for performance runs I set the following:

```
ALTER TABLE RES_RELATE SET ( fillfactor = 50);
ALTER TABLE RES_FEAT_STAT SET ( fillfactor = 50);
ALTER TABLE RES_FEAT_EKEY SET ( fillfactor = 50);
ALTER TABLE RES_ENT SET ( fillfactor = 50);
ALTER TABLE OBS_ENT SET ( fillfactor = 50);
```
