## Autovacuum experiments

Autovacuum is a pain. I spend more time dealing with making that work well than anything else with PostgreSQL. I've recently tried a very different approach to try to best optimize autovaccum.

This become even more important with PostgreSQL v16 where autovacuum was a bottleneck even at the beginning of the load.

### postgresql.conf

```
log_autovacuum_min_duration = 100000    # log autovacuum activity;
autovacuum_max_workers=16
autovacuum_analyze_scale_factor = 0.4   # we don't need to run this often
autovacuum_freeze_max_age = 1200000000
autovacuum_multixact_freeze_max_age = 1500000000
vacuum_cost_page_hit = 0
vacuum_cost_page_miss = 0
vacuum_cost_page_dirty = 1
vacuum_buffer_usage_limit=16GB # new in v16
```

This marks a significant departure from what I've done before. This lets the system largely default to what it normally does.

vacuum_cost: I really just care any time a page is dirty and needs to be processed so set the costs on reads to zero. With the default (low) cost delay, if an autovacuum is doing real write work it will be seen in VacuumDelay a lot.

### Altering specific tables

Then I went to see what the counts would be on the most troublesome modified tables by doing `select pg_stat_reset()` and coming back two hours later to execute a query to see what happened.

Note: this one was after >12hrs

```
select relname,n_tup_ins,n_tup_upd,n_tup_del, (n_tup_ins+n_tup_upd+n_tup_del) as tot from pg_stat_all_tables order by tot desc limit 50;
       relname       | n_tup_ins | n_tup_upd | n_tup_del |    tot
---------------------+-----------+-----------+-----------+-----------
 lib_feat_2_new      | 547261826 |        30 |         0 | 547261856
 lib_feat_3_new      | 547256659 |        22 |         0 | 547256681
 lib_feat_0_new      | 547220931 |        14 |         0 | 547220945
 lib_feat_1_new      | 547220429 |        17 |         0 | 547220446
 res_feat_ekey_4_new | 459854908 |   4732613 |   9265015 | 473852536
 res_feat_ekey_0_new | 458739420 |   5815530 |   8892506 | 473447456
 res_feat_ekey_3_new | 459693517 |   4597130 |   8764196 | 473054843
 res_feat_ekey_6_new | 459158533 |   4937509 |   8580991 | 472677033
 res_feat_ekey_2_new | 459145467 |   4662979 |   8646015 | 472454461
 res_feat_ekey_5_new | 458952241 |   4749889 |   8462745 | 472164875
 res_feat_ekey_7_new | 459204800 |   4389730 |   8513777 | 472108307
 res_feat_ekey_1_new | 457919572 |   4666575 |   8553026 | 471139173
 res_feat_stat_4_new | 273670442 | 146298163 |         0 | 419968605
 res_feat_stat_2_new | 273637695 | 146294855 |         0 | 419932550
 res_feat_stat_3_new | 273639511 | 146291154 |         0 | 419930665
 res_feat_stat_5_new | 273637534 | 146249564 |         0 | 419887098
 res_feat_stat_6_new | 273603149 | 146259538 |         0 | 419862687
 res_feat_stat_1_new | 273612468 | 146232553 |         0 | 419845021
 res_feat_stat_7_new | 273575236 | 146240885 |         0 | 419816121
 res_feat_stat_0_new | 273582990 | 146231790 |         0 | 419814780
 res_rel_ekey_2      | 104952890 |         0 |  44381024 | 149333914
 res_rel_ekey_3      | 104896796 |         0 |  44271478 | 149168274
 res_rel_ekey_0      | 104832454 |         0 |  44233086 | 149065540
 res_rel_ekey_1      | 104814069 |         0 |  44222797 | 149036866
 res_ent_okey        |  99241732 |   1377811 |         0 | 100619543
 res_relate_1        |  52576193 |   7376425 |  22144140 |  82096758
 res_relate_0        |  52568182 |   7382373 |  22132961 |  82083516
 res_relate_3        |  52569178 |   7377031 |  22135680 |  82081889
 res_relate_2        |  52572458 |   7367353 |  22141101 |  82080912
 obs_ent_3_new       |  24811709 |  56959417 |         0 |  81771126
 obs_ent_1_new       |  24808034 |  56959848 |         0 |  81767882
 obs_ent_0_new       |  24811674 |  56954259 |         0 |  81765933
 obs_ent_2_new       |  24810522 |  56953199 |         0 |  81763721
 res_ent_0           |  24100341 |  31985864 |     30783 |  56116988
 res_ent_3           |  24097933 |  31984900 |     30336 |  56113169
 res_ent_2           |  24097202 |  31984235 |     30423 |  56111860
 res_ent_1           |  24093973 |  31973491 |     30454 |  56097918
 dsrc_record_0       |  24817281 |   2941978 |         0 |  27759259
 dsrc_record_1       |  24814552 |   2942581 |         0 |  27757133
```

So first, with LIB_FEAT, this confirms what we already know: that it is an insert-only table. One of the things with insert-only tables is that you can completely disable the default behavior for auto-vacuum to periodically table scale to freeze tuples. Also, that two hours was about 40M inserts per partition, and I decided to make it so autovacuum would trigger on partitions about every two hours.

```
alter table LIB_FEAT_0_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000);
alter table LIB_FEAT_1_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000);
alter table LIB_FEAT_2_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000);
alter table LIB_FEAT_3_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000);
```

Next up, with RES_FEAT_EKEY, it does have updates/deletes but at a rate substantially lower than inserts. This change causes it to autovacuum every 40M inserts or 1M regular changes. We let it freeze to its thing, though how much that helps is up for debate.

```
alter table RES_FEAT_EKEY_0_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_1_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_2_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_3_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_4_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_5_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_6_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
alter table RES_FEAT_EKEY_7_NEW set (autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=1000000);
```

Lastly, RES_FEAT_STAT has inserts and many updates. Since the updates are random, they tend to touch many pages, so freezing likely has little benefit, so we turn it off. For this one we turn off freeze scans and track to 40M inserts or 20M update/deletes.

```
alter table RES_FEAT_STAT_0_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_1_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_2_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_3_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_4_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_5_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_6_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
alter table RES_FEAT_STAT_7_NEW set (autovacuum_freeze_min_age = 0,autovacuum_vacuum_insert_scale_factor=0,autovacuum_vacuum_insert_threshold=40000000,autovacuum_vacuum_scale_factor=0,autovacuum_vacuum_threshold=2000000);
```

That is it... the rest of the tables are substantially less active and are active in ways than the default settings. Every once in an OBS_ENT or other table will come up with an aggressive vacuum, but this solved two problems for me:

1. In v16, I basically ended up with all 16 autovacuum workers busy the entire load
2. Since the default thresholds were percentage-based, most of the tables/partitions grow at similar rates, so they all needed to be autovacuumed at the same time.
