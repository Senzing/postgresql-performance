--
-- RES_FEAT_EKEY
--
CREATE TABLE RES_FEAT_EKEY_NEW (RES_ENT_ID BIGINT NOT NULL, ECLASS_ID smallint NOT NULL, LENS_ID smallint NOT NULL, LIB_FEAT_ID BIGINT NOT NULL, FTYPE_ID smallint NOT NULL, UTYPE_CODE VARCHAR(50) NOT NULL, SUPPRESSED CHAR(1), USED_FROM_DT TIMESTAMP, USED_THRU_DT TIMESTAMP, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP) PARTITION BY HASH(RES_ENT_ID);

CREATE TABLE RES_FEAT_EKEY_0_NEW PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_1_NEW PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_2_NEW PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_3_NEW PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

COPY RES_FEAT_EKEY TO '/var/lib/postgresql/data/rfe.csv' DELIMITER ',';
-- COPY (SELECT * FROM RES_FEAT_EKEY) TO '/var/lib/postgresql/data/rfe.csv' DELIMITER ','; -- If partitioned already
COPY RES_FEAT_EKEY_NEW FROM '/var/lib/postgresql/data/rfe.csv' DELIMITER ',';

-- note that the default schema has this as a unique index but it is just the same fields in a different order from the primary key so it does not need to be unique
-- CREATE INDEX RES_FEAT_EKEY_SK ON RES_FEAT_EKEY(RES_ENT_ID, LENS_ID, LIB_FEAT_ID, UTYPE_CODE) ;

CREATE INDEX RES_FEAT_EKEY_SK2 ON RES_FEAT_EKEY_NEW (RES_ENT_ID) INCLUDE (LIB_FEAT_ID,FTYPE_ID,UTYPE_CODE,USED_FROM_DT,USED_THRU_DT,FIRST_SEEN_DT,LAST_SEEN_DT,SUPPRESSED);
CREATE UNIQUE INDEX RES_FEAT_EKEY_PK2 ON RES_FEAT_EKEY_NEW (LIB_FEAT_ID, RES_ENT_ID, UTYPE_CODE) INCLUDE (LENS_ID, ECLASS_ID);

-- DANGER: DROP TABLE RES_FEAT_EKEY;
ALTER TABLE RES_FEAT_EKEY_NEW RENAME TO RES_FEAT_EKEY;

--
-- RES_FEAT_STAT
--
CREATE TABLE RES_FEAT_STAT_NEW (LENS_ID smallint NOT NULL, LIB_FEAT_ID BIGINT NOT NULL, ECLASS_ID smallint NOT NULL, NUM_RES_ENT int NOT NULL, NUM_RES_ENT_OOM int NOT NULL, CANDIDATE_CAP_REACHED CHAR(1) DEFAULT 'N' NOT NULL, SCORING_CAP_REACHED CHAR(1) DEFAULT 'N' NOT NULL, PRIMARY KEY(LIB_FEAT_ID, LENS_ID, ECLASS_ID)) PARTITION BY HASH(LIB_FEAT_ID);

CREATE TABLE RES_FEAT_STAT_0 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_1 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_2 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_3 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);


INSERT INTO RES_FEAT_STAT_NEW SELECT * FROM RES_FEAT_STAT;
-- DANGER: DROP TABLE RES_FEAT_STAT;
ALTER TABLE RES_FEAT_STAT_NEW RENAME TO RES_FEAT_STAT;


--
-- RES_ENT
--
CREATE TABLE RES_ENT_NEW (RES_ENT_ID BIGINT NOT NULL, LENS_ID smallint NOT NULL, ECLASS_ID smallint NOT NULL, INTEREST_LEVEL smallint, CONFUSION_LEVEL smallint, NUM_OBS_ENT int, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, LAST_TOUCH_DT BIGINT, LOCKING_ID BIGINT NOT NULL, NODE_NAME VARCHAR(50) NOT NULL, LOCK_DSRC_ACTION CHAR(1), PRIMARY KEY(RES_ENT_ID, LENS_ID)) PARTITION BY HASH(RES_ENT_ID);

CREATE TABLE RES_ENT_0 PARTITION OF RES_ENT_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_1 PARTITION OF RES_ENT_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_2 PARTITION OF RES_ENT_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_3 PARTITION OF RES_ENT_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

INSERT INTO RES_ENT_NEW SELECT * FROM RES_ENT;
-- DANGER: DROP TABLE RES_ENT;
ALTER TABLE RES_ENT_NEW RENAME TO RES_ENT;


--
-- DSRC_RECORD
--
CREATE TABLE DSRC_RECORD_NEW (DSRC_ID smallint NOT NULL, RECORD_ID VARCHAR(250) NOT NULL, ETYPE_ID smallint NOT NULL, ENT_SRC_KEY VARCHAR(250) NOT NULL, OBS_ENT_HASH CHAR(40) NOT NULL, JSON_DATA TEXT, CONFIG_ID BIGINT, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, PRIMARY KEY(RECORD_ID, DSRC_ID)) PARTITION BY HASH(RECORD_ID);

CREATE TABLE DSRC_RECORD_0 PARTITION OF DSRC_RECORD_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_1 PARTITION OF DSRC_RECORD_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_2 PARTITION OF DSRC_RECORD_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_3 PARTITION OF DSRC_RECORD_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

CREATE INDEX DSRC_RECORD_SK_NEW ON DSRC_RECORD_NEW(ENT_SRC_KEY, DSRC_ID) ;
CREATE INDEX DSRC_RECORD_HK_NEW ON DSRC_RECORD_NEW(OBS_ENT_HASH, DSRC_ID, ETYPE_ID) ;

INSERT INTO DSRC_RECORD_NEW SELECT * FROM DSRC_RECORD;
-- DANGER: DROP TABLE DSRC_RECORD;
ALTER TABLE DSRC_RECORD_NEW RENAME TO DSRC_RECORD;

--
-- RES_REL_EKEY
--
CREATE TABLE RES_REL_EKEY_NEW (RES_ENT_ID BIGINT NOT NULL, LENS_ID smallint NOT NULL, REL_ENT_ID BIGINT NOT NULL, RES_REL_ID BIGINT NOT NULL, PRIMARY KEY(RES_ENT_ID, LENS_ID, REL_ENT_ID)) PARTITION BY HASH(RES_ENT_ID);

CREATE TABLE RES_REL_EKEY_0 PARTITION OF RES_REL_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_REL_EKEY_1 PARTITION OF RES_REL_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_REL_EKEY_2 PARTITION OF RES_REL_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_REL_EKEY_3 PARTITION OF RES_REL_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

INSERT INTO RES_REL_EKEY_NEW SELECT * FROM RES_REL_EKEY;
-- DANGER: DROP TABLE RES_REL_EKEY;
ALTER TABLE RES_REL_EKEY_NEW RENAME TO RES_REL_EKEY;


--
-- RES_RELATE
--
CREATE TABLE RES_RELATE_NEW (RES_REL_ID BIGINT NOT NULL, LENS_ID smallint NOT NULL, MIN_RES_ENT_ID BIGINT NOT NULL, MAX_RES_ENT_ID BIGINT NOT NULL, REL_STRENGTH smallint, REL_STATUS smallint, IS_DISCLOSED smallint, IS_AMBIGUOUS smallint, INTEREST_LEVEL smallint, CONFUSION_LEVEL smallint, LAST_ER_ID BIGINT, LAST_REF_SCORE smallint, LAST_ERRULE_ID smallint, MATCH_KEY TEXT, MATCH_LEVELS VARCHAR(50), FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, PRIMARY KEY(RES_REL_ID)) PARTITION BY HASH(RES_REL_ID);

CREATE TABLE RES_RELATE_0 PARTITION OF RES_RELATE_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_RELATE_1 PARTITION OF RES_RELATE_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_RELATE_2 PARTITION OF RES_RELATE_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_RELATE_3 PARTITION OF RES_RELATE_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

INSERT INTO RES_RELATE_NEW SELECT * FROM RES_RELATE;
-- DANGER: DROP TABLE RES_RELATE;
ALTER TABLE RES_RELATE_NEW RENAME TO RES_RELATE;

-- grant all on all tables in schema "schema_name" to user




