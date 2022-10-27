# postgresql-performance

This repository is to document specific tweaks to PostgreSQL and the Senzing DDL that may be useful for larger installations.  Definitely add your own comments/experiences as GitHub issues in this repository.


## Fundamentals
A DBA needs to tune PostgreSQL for the available hardware... shared_buffers, worker memory, IO, etc.  The one "unusual" thing about Senzing is that it largerly runs in auto-commit mode which means that commit performance has a lot to do with overall performance, 10x+ so.  You can check single connection insert performance with `G2Command` and the `checkDBPerf -s 3` command.  Ideally you should get <.5ms per insert or 6000 inserts in 3 seconds.  Many systems, even cloud systems, will achieve .1-.3ms.

You can also use psql to the PostgreSQL database from the same environment you are running the Senzing API to check network performance.  Use `\timing` to enable timings and `select 1;` to check the roundtrip performance.  Since this does not leverage the Senzing schema or the database IO subsystem, if this is slow it is pure networking/connection overhead.

The primary configuration parameter to improve commit performance is to turn off disk flushes on commit with `synchronous_commit=off`.

There is more to pay attention to on your system though.  For instance, if replication is done synchronously then you end up with the same problem.  On AWS Aurora, replication to a different AZ forces synchronous commit back on.  As you are looking at the design of your database infrastructure, you will need to take these things into consideration.  To simplify things, customers will often do the initial historical loads without replication and set it up afterward when the DB performance needs tend to be much lower.


## PostgreSQL 14
This version has specific improvements to the handling of transactions and idle connections that can give substantional benefits for running OLTP applications like Senzing.  You can see if you are being impacted by the on previous versions of PostgreSQL by running `perf top` and looking for GetSnapshotData using significant CPU while the system is under load.  In my tests, this function was the largest consumer of CPU on the entire system.  This optimization is automatically enabled when you install 14.

lz4 TOAST compression may be a small win as it has significantly higher compression speeds.  In theory this should reduce latency.  It can be enabled with `default_toast_compression='lz4'` on a new system.


## Partitioning
Partitioning can be very effective for Senzing.  Autovacuum, backup, and restore are all single threaded operations per table in PostgreSQL.  By partitioning Senzing, you can achieve substantially better parallelization of these operations.  Some obvious tables to partition are:

```
RES_FEAT_EKEY
RES_FEAT_STAT
RES_ENT
DSRC_RECORD
```

It would be nice to partition LIB_FEAT and OBS_ENT also but they have 2 unique indexes which makes it incompatible with PostgreSQL partitioning.  Fortunately, I've found that LIB_FEAT and OBS_ENT rarely a vacuum problem and, over time, will become more read heavy.

Of course, some queries select records without including the partition key and instead use the secondary indexes.  This will use more CPU as they broadcast out the request to all partitions but, in my experience, vacuum and other operational issues are for more important than DB CPU.

In this repository you will find a `partitioning_mods.sql` file for the previously mentioned tables.


## Governor
Recommend setting the thresholds to 1.2B/1.5B to allow for more time to vacuum.  Also, the smaller difference in the values can help prevent the cost of expensive "double vacuum" where a "pause" is needed immediately after the initial vacuum as the XID is not dropped far enough.  I saw a reduction from 2-4hrs to <1hr in wait time on average by doing this.

Along with those governor changes, you can make autovacuum be more aggressive and less likely to hit an expensive autovacuum with these settings:
```
autovacuum_max_workers=16
autovacuum_vacuum_cost_limit = 10000
autovacuum_freeze_max_age = 1000000000
autovacuum_multixact_freeze_max_age = 1200000000
```

The best setting for you may be different depending on the system you have.  I run pretty aggressively like:
```
checkpoint_timeout = 2min               # range 30s-1d
checkpoint_completion_target = 0.9      # checkpoint target duration, 0.0 - 1.0
max_wal_size = 80GB
min_wal_size = 80GB
autovacuum_max_workers=16
autovacuum_vacuum_cost_limit = 10000
autovacuum_freeze_max_age = 1000000000
autovacuum_multixact_freeze_max_age = 1200000000
autovacuum_vacuum_threshold = 10000000  # min number of row updates before
                                        # vacuum
autovacuum_vacuum_insert_threshold = 10000000   # min number of row inserts
                                        # before vacuum; -1 disables insert
                                        # vacuums
autovacuum_analyze_threshold = 0        # min number of row updates before
                                        # analyze
autovacuum_analyze_scale_factor = 0.2   # fraction of table size before analyze
autovacuum_vacuum_scale_factor = 0      # fraction of table size before vacuum
autovacuum_vacuum_insert_scale_factor = 0       # fraction of inserts over table
                                        # size before insert vacuum
autovacuum_vacuum_cost_delay = 1ms      # default vacuum cost delay for
                                        # autovacuum, in milliseconds;
                                        # -1 means use vacuum_cost_delay
                                        log_autovacuum_min_duration = 100000    # log autovacuum activity;
                                        # -1 disables, 0 logs all actions and
                                        # their durations, > 0 logs only
                                        # actions running at least this number
                                        # of milliseconds.
log_checkpoints = on

default_toast_compression = 'lz4'       # 'pglz' or 'lz4'
```


## Auto-vacuuming
Keep the system in regular vacuum as much as possible.  The aggressive vacuum causes massive IO, making the cost 100x more expensive.  Partitioning of the hottest tables can help regular autovacuum keep up longer.


## Fillfactor
When PostgreSQL updates a record it creates a new version (a copy) of the record with the update.  If this can be done 1) without modifying an index and 2) with putting the copy in the same page as the old version, then this change does not contribute to additional vacuum workload.  In fact, the old copies can even be cleaned up during select operations.

The problem is that PostgreSQL by default fills 100% of a page in a table before splitting.  This means that there likely won't be room for this operation and some Senzing tables are updated frequently.  The negative of reducing the fillfactor is that it may increase diskspace.  You may want to experiment with this yourself but for performance runs I set the following:

```
ALTER TABLE RES_RELATE SET ( fillfactor = 50 );
ALTER TABLE RES_FEAT_STAT SET ( fillfactor = 50 );
ALTER TABLE RES_FEAT_EKEY SET ( fillfactor = 50 );
ALTER TABLE RES_ENT SET ( fillfactor = 50 );
ALTER TABLE OBS_ENT SET ( fillfactor = 50 );
ALTER TABLE DSRC_RECORD SET ( fillfactor = 50 );
```

NOTE: That if you have partitioned tables, this much be done on each partition.


## Memory issues
When trying 450M records in the heavily partitioned schema, I found postgresql triggering the Linux OOM killer around 300M records.  This would happen repeatedly but made no sense as this dedicated DB server has 1.5TB RAM and 100GB of shared_buffers.  In doing some reviews, it appears that the kernel overcommit settings/algorithms just aren't good for this.  Oddly, the issue did not occur with lesser partitioning with the exact same data.

Setting these kernel parameters resolved the issue:

```
vm.overcommit_memory=2
vm.overcommit_ratio=90
```

## LUKS disk encryption
I do my performance runs with full disk encryption using Linux LUKS on LVM, mdraid0, etc.  This tries to characterize real world and not ideal workloads.  There are some parameters to the crypt devices that can be helpful and more coming in newer kernels.

** Note that I tried the newer kernel settings and it was terrible.  More to look at here though.

```
Ubuntu 20.04 w/ 5.4 kernel
cryptsetup --perf-submit_from_crypt_cpus --allow-discards --persistent refresh <device>

Newer kernels (to be tested):
cryptsetup --allow-discards -perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh
```




