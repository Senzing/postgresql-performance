# postgresql-performance

This repository is to document specific tweaks to PostgreSQL and the Senzing DDL that may be useful for larger installations.  Definitely add your own comments/experiences as GitHub issues in this repository.

If you haven't already taken a look at the general performance document, please do: https://github.com/Senzing/performance-general/blob/main/README.md


## Fundamentals
A DBA needs to tune PostgreSQL for the available hardware... shared_buffers, worker memory, IO, etc.  The one "unusual" thing about Senzing is that it largely runs in auto-commit mode, which means that commit performance has a lot to do with overall performance, 10x+ so.  You can check single connection insert performance with `G2Command` and the `checkDBPerf -s 3` command.  Ideally, you should get <.5ms per insert or 6000 inserts in 3 seconds.  Many systems, even cloud systems, will achieve .1-.3ms.

You can also use psql to the PostgreSQL database from the same environment you are running the Senzing API to check network performance.  Use `\timing` to enable timings and `select 1;` to check the roundtrip performance.  Since this does not leverage the Senzing schema or the database IO subsystem, if this is slow it is pure networking/connection overhead.

The primary configuration parameter to improve commit performance is to turn off disk flushes on commit with `synchronous_commit=off`.

There is more to pay attention to on your system though.  For instance, if replication is done synchronously then you end up with the same problem.  On AWS Aurora, replication to a different AZ forces synchronous commit back on.  As you are looking at the design of your database infrastructure, you will need to take these things into consideration.  To simplify things, customers will often do the initial historical loads without replication and set it up afterward when the DB performance needs tend to be much lower.


## PostgreSQL 14
This version has specific improvements to the handling of transactions and idle connections that can give substantial benefits for running OLTP applications like Senzing.  You can see if you are being impacted by the on previous versions of PostgreSQL by running `perf top` and looking for GetSnapshotData using significant CPU while the system is under load.  In my tests, this function was the largest consumer of CPU on the entire system.  This optimization is automatically enabled when you install 14.

lz4 TOAST compression may be a small win as it has significantly higher compression speeds.  In theory, this should reduce latency.  It can be enabled with `default_toast_compression='lz4'` on a new system.


## PostgreSQL 16
First, I wouldn't move here yet.  I have been eager to try it as it allows you to do an explain on generic query plans which is precisely what the PostgreSQL optimizer typically uses for Senzing's prepared statements.  That particular feature was immediately valuable.

The problem is they made a pretty enormous change to vacuum/autovacuum.  Previously, maintenance processes had access to all of the shared_buffers to do their work, but in v16, they added a limiting parameter that defaults to 256kB and maxes out at 16GB.  When PostgreSQL is under heavy autovacuum load, the autovacuum processes end up VERY throttled on write.  I suspect that it is evicting pages from the shared_buffers and waiting on a substantially increased write workload.  I get why they did this and it prevents artificially "flushing" the shared_buffers as the maintenance processes do full table scans... but in Senzing's incredibly random workload, there is a good chance those pages get used within seconds and get evicted normally.  So this is an entirely unnecessary write workload.

I'm not sure how to tune around this particular one yet.


## Recommended Senzing Configuration changes
Normally, I don't change the Senzing default configuration unless I want to add data sources, features, keys (e.g., NAMEADDR_KEY), etc.  Starting with Senzing 3.8.0, I do recommend that people with large datasets make one change to NOT have NAME_KEYs create a redo.  Prior to 3.8, new configurations have this disabled by default.  The reason was simple: Senzing doesn't make decisions solely on name, and the majority of NAME_KEYs end up generic, so you generic 25-50x the amount of redo during processing.

So why did this change?  NAME_KEYs are actually based on only NAME or NAME in combination with other things (DOB, POSTAL_CODE, ADDR_CITY, LAST4_ID, etc).  Except in the NAME+DOB situation, we didn't make resolution or relationship decisions based on any of those combinations so it was nearly impossible anything might be sitting around based on a now generic value.  In fact, in the entire history of Senzing, I'm only aware of one instance where a customer noticed such a decision on NAME+DOB.

What changed is that in 3.5 we started building relationships on close unique names to find more connections on smaller datasets where unique names are common.  We also have some people experimenting with resolving on some very loose/questionable criteria.  This caused [now] generic name-based decisions to be more common and in 3.8 a new configuration defaults to having redo enabled.

Why turn it off on large systems?  Simply put the negative far outweighs the questionable benefit.  With large data, 1) you probably aren't configuring loose decision making and 2) the velocity/volume of data easily quickly takes care of things like relationships on now generic names... so would you likely never see it, anything you did see would be something like a name only possible match (weak) that is now generic.

The change is simple.  Run G2ConfigTool.py and execute:
```
setGenericThreshold {"plan": "INGEST", "feature": "all", "behavior": "NAME", "candidateCap": 10, "scoringCap":-1, "sendToRedo": "No"}
save
```

## Well JIT!
![image](https://github.com/Senzing/postgresql-performance/assets/24964308/a1f8a41d-5863-4d8f-a4a0-29bc38689964)

So I got an error "53200FATAL: fatal llvm error: Unable to allocate section memory!" from PostgreSQL 14 at about 710M records into a test.  No problem, the consumers began to restart and the load hardly skipped a beat.  In that same minute, I googled the error and found that is the JIT compiler that is enabled by default using that memory.  My understanding is the JIT compiles reused SQL statements into binary code to more effectively execute.  It can be set off in the postgresql.conf with `jit=off` and `select pg_reload_conf()` can be used in psql to live reload that setting.  Immediately, performance went from a steady-state of about 870/s to 1500/s.

Not believing this could be true, I turned it back on and immediately it dropped back down.  Then turned it off again and the performance went back up.

From a database system behavior, the CPU for the select processes dropped dramatically while performance nearly doubled.  I'm still not sure why, but the test results are clear.

## pg_stat_statements
This is really nice if you want to monitor what SQL statements the system is really spending time on and why.  Google how to enable it on your system.  I like to watch this SQL statement which consolidates types of Senzing SQL statements into one per row:

```
watch -n 10 psql -p 5432 -U postgres -w -h 127.0.0.1 g2 -c "\"select count(*), sum(calls) as calls, cast(sum(total_exec_time) as bigint) as total_exec_time, sum(rows) as rows, cast(sum(blk_read_time) as bigint) as blk_read_time, cast(sum(blk_write_time) as bigint) blk_write_time, sum(shared_blks_dirtied) as shared_blks_dirtied, sum(local_blks_dirtied) as local_blks_dirtied, sum(wal_records) as wal_records, cast(sum(io_time) as bigint) as io_time, trimmed_query from ( select  (case when strpos(query,'2') >0 then left(query,strpos(query,'2')) else query end ) as trimmed_query, blk_read_time+blk_write_time as io_time,* from pg_stat_statements) group by trimmed_query order by io_time desc;"\"
```

## BufferMapping and waits
There are nice wait queries that I like to run during loads to see what the database is waiting on.

```
watch psql -U postgres -w -h 127.0.0.1 g2 -c "\"select extract('epoch' from now()-xact_start) as duration, wait_event_type, wait_event, state, query from pg_stat_activity where state != 'idle' and (wait_event_type != '' or query like '%vacuum%') order by duration desc\""
watch psql -U postgres -w -h 127.0.0.1 g2 -c "\"select count(*) as cnt, wait_event_type, wait_event from pg_stat_activity where state != 'idle'  and wait_event_type != '' group by wait_event_type, wait_event having count(*) > 1 order by cnt desc\""
```

One thing you will find is that once you are seeing lots of LWLock:BufferMapping waits, then adding more connections to the database is unlikely to scale.  PostgreSQL has 128 "buffer partitions," and when a select is looking to allocate memory to return results, it locks one of those partitions.  This means that once your workload shows heavy LWLock:BufferMapping waits, you need to look at a few options to continue scaling:
* Move to DB clustering: Using either https://senzing.zendesk.com/hc/en-us/articles/360010599254-Scaling-Out-Your-Database-With-Clustering or some tables may work well with more traditional database clustering
* Reduce the size of selects: If you increased generics thresholds for ingest and/or have keys causing entities to be highly related, you may want to revisit it

Here is an example of a load where the number of loading threads was changed from 768 to 384 to 192.  The dips are when the loaders were restarted with new settings.  Only at 192 did BufferMapping essentially disappear from being a wait event with performance dropping <5%, which could likely be recovered by increasing the threads slightly.
![image](https://github.com/Senzing/postgresql-performance/assets/24964308/de79e8f2-96f3-41b7-87cb-7ca00071ef43)

The other side effect of monitoring BufferMapping is with autovacuum.  Autovacuum leverages those same buffers, and contention on them severely impacts the ability of the autovacuum to keep up.  In the load above, the autovacuum was taking several times longer when there was contention.


## Partitioning
Partitioning can be very effective for Senzing.  Autovacuum, backup, and restore are all single-threaded operations per table in PostgreSQL.  By partitioning Senzing, you can achieve substantially better parallelization of these operations.  Some obvious tables to partition are:

```
RES_FEAT_EKEY
RES_FEAT_STAT
RES_ENT
DSRC_RECORD
```

In this repository, you will find a `partitioning_mods.sql` file for the latest.


## Governor
Recommend setting the thresholds to 1.2B/1.5B to allow for more time to vacuum.  Also, the smaller difference in the values can help prevent the cost of an expensive "double vacuum" where a "pause" is needed immediately after the initial vacuum as the XID is not dropped far enough.  I saw a reduction from 2-4 hours to <1hr in wait time on average by doing this.

The best setting for you may be different depending on the system you have.  I run pretty aggressively like:
```
synchronous_commit=off

lock_timeout = 500000
idle_in_transaction_session_timeout=600000

checkpoint_timeout = 2min
checkpoint_completion_target = 0.9
max_wal_size = 80GB

full_page_writes = off
wal_init_zero = off
wal_level = minimal
wal_writer_delay = 10000ms
wal_recycle = off
max_wal_senders = 0

effective_io_concurrency = 1000
maintenance_io_concurrency = 1000
max_parallel_maintenance_workers = 16
max_parallel_workers_per_gather = 16
max_worker_processes = 16
max_parallel_workers = 16

autovacuum_max_workers=16
autovacuum_vacuum_cost_limit = 10000
vacuum_cost_page_hit = 0		# 0-10000 credits
vacuum_cost_page_miss = 1		# 0-10000 credits
vacuum_cost_page_dirty = 1		# 0-10000 credits
vacuum_freeze_table_age=1000000000
vacuum_freeze_min_age=200000000
autovacuum_freeze_max_age = 1200000000
autovacuum_multixact_freeze_max_age = 1500000000
autovacuum_vacuum_scale_factor = 0.01
autovacuum_vacuum_insert_scale_factor = 0.01
autovacuum_vacuum_cost_delay = 0
autovacuum_naptime = 1min


default_toast_compression = 'lz4'       # 'pglz' or 'lz4'
enable_seqscan = off
random_page_cost = 1.1
```


## Auto-vacuuming
Keep the system in regular vacuum as much as possible.  The aggressive vacuum causes massive IO, making the cost 100x more expensive.  Partitioning of the hottest tables can help regular autovacuum keep up longer.


## Fillfactor
When PostgreSQL updates a record it creates a new version (a copy) of the record with the update.  If this can be done 1) without modifying an index and 2) with putting the copy in the same page as the old version, then this change does not contribute to additional vacuum workload.  In fact, the old copies can even be cleaned up during select operations.

The problem is that PostgreSQL by default fills 100% of a page in a table before splitting.  This means that there likely won't be room for this operation and some Senzing tables are updated frequently.  The negative of reducing the fillfactor is that it may increase disk space.  You may want to experiment with this yourself but for performance runs, I set the following:

```
ALTER TABLE RES_RELATE SET ( fillfactor = 100 );
ALTER TABLE LIB_FEAT SET ( fillfactor = 100 );
ALTER TABLE RES_FEAT_STAT SET ( fillfactor = 90 );
ALTER TABLE RES_FEAT_EKEY SET ( fillfactor = 90 );
ALTER TABLE RES_ENT SET ( fillfactor = 90 );
ALTER TABLE OBS_ENT SET ( fillfactor = 75 );
ALTER TABLE RES_ENT_OKEY SET ( fillfactor = 75 );
ALTER TABLE DSRC_RECORD SET ( fillfactor = 90 );
```

NOTE: If you have partitioned tables, this must be done on each partition.


## Memory issues
When trying 450M records in the heavily partitioned schema, I found Postgresql triggering the Linux OOM killer around 300M records.  This would happen repeatedly but made no sense as this dedicated DB server has 1.5TB RAM and 100GB of shared_buffers.  In doing some reviews, it appears that the kernel overcommit settings/algorithms just aren't good for this.  Oddly, the issue did not occur with lesser partitioning with the exact same data.

Setting these kernel parameters resolved the issue:

```
vm.overcommit_memory=2
vm.overcommit_ratio=90
```

## LUKS disk encryption
I do my performance runs with full disk encryption using Linux LUKS on LVM, mdraid0, etc.  This tries to characterize real world and not ideal workloads.  There are some parameters to the crypt devices that can be helpful and more coming in newer kernels.

** Note that I tried this and it works really well for a short period of time.  The problem is that the newer settings make the encryption happen in process.  This works great EXCEPT for kernel page flushing and checkpointing which are single process/thread operations.  The database can actually run out of space because WAL logs fill up the disk.  Depending on your write performance it may be beneficial to set no_read_workqueue but leave the write queue alone.

```
Ubuntu 20.04 w/ 5.4 kernel
cryptsetup --allow-discards --persistent refresh <device>

Newer kernels (to be tested):
cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh <device>
```

## IO concurrency
```
effective_io_concurrency = 1000
maintenance_io_concurrency = 1000
```
I tend to use the above settings.  It is also important to set the block device read-ahead too.  I will set the flash devices to 16 and DM devices to 256.  Since our access pattern is very random, I generally don't like read-ahead at all BUT PostgreSQL vacuum performs 3-4x better with readahead since it is a heavy sequential scan operation.  Hopefully PostgreSQL one day will support Direct IO and AsyncIO. Something like this:

```
blockdev --report
blockdev --setra 256 /dev/dm-* ## can also probably leave this as what the OS defaults to
blockdev --setra 16 /dev/nvme*n1
blockdev --report
```

Drop extra tables and indexes
```
DROP TABLE DSRC_RECORD_HKEY, LIB_FEAT_HKEY, OBS_ENT_SKEY, RES_ENT_RKEY, RES_FEAT_LKEY;
DROP TABLE OBS_FEAT_EKEY; -- ONLY IF THE TABLE IS COMPLETELY EMPTY
DROP INDEX DSRC_RECORD_HK; -- 3.6 and newer
```

