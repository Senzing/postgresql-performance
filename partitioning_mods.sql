
CREATE TABLE RES_FEAT_EKEY_NEW (RES_ENT_ID BIGINT NOT NULL, ECLASS_ID smallint NOT NULL, LENS_ID smallint NOT NULL, LIB_FEAT_ID BIGINT NOT NULL, FTYPE_ID smallint NOT NULL, UTYPE_CODE VARCHAR(50) NOT NULL, SUPPRESSED CHAR(1), USED_FROM_DT TIMESTAMP, USED_THRU_DT TIMESTAMP, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, PRIMARY KEY(LIB_FEAT_ID, LENS_ID, RES_ENT_ID, UTYPE_CODE)) PARTITION BY HASH(LIB_FEAT_ID);

CREATE TABLE RES_FEAT_EKEY_0 PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_1 PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_2 PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_EKEY_3 PARTITION OF RES_FEAT_EKEY_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

-- note that the default schema has this as a unique index but it is just the same fields in a different order from the primary key so it does not need to be unique
-- CREATE INDEX RES_FEAT_EKEY_SK ON RES_FEAT_EKEY(RES_ENT_ID, LENS_ID, LIB_FEAT_ID, UTYPE_CODE) ;
CREATE INDEX RES_FEAT_EKEY_HASH ON RES_FEAT_EKEY_NEW USING HASH (RES_ENT_ID);

INSERT INTO RES_FEAT_EKEY_NEW SELECT * FROM RES_FEAT_EKEY;
-- DROP TABLE RES_FEAT_EKEY;
ALTER TABLE RES_FEAT_EKEY_NEW RENAME TO RES_FEAT_EKEY;


CREATE TABLE RES_FEAT_STAT_NEW (LENS_ID smallint NOT NULL, LIB_FEAT_ID BIGINT NOT NULL, ECLASS_ID smallint NOT NULL, NUM_RES_ENT int NOT NULL, NUM_RES_ENT_OOM int NOT NULL, CANDIDATE_CAP_REACHED CHAR(1) DEFAULT 'N' NOT NULL, SCORING_CAP_REACHED CHAR(1) DEFAULT 'N' NOT NULL, PRIMARY KEY(LIB_FEAT_ID, LENS_ID, ECLASS_ID)) PARTITION BY HASH(LIB_FEAT_ID);

CREATE TABLE RES_FEAT_STAT_0 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_1 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_2 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_FEAT_STAT_3 PARTITION OF RES_FEAT_STAT_NEW FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);


INSERT INTO RES_FEAT_STAT_NEW SELECT * FROM RES_FEAT_STAT;
-- DANGER: DROP TABLE RES_FEAT_STAT;
ALTER TABLE RES_FEAT_STAT_NEW RENAME TO RES_FEAT_STAT;


-- DANGER: DROP TABLE RES_ENT;
CREATE TABLE RES_ENT (RES_ENT_ID BIGINT NOT NULL, LENS_ID smallint NOT NULL, ECLASS_ID smallint NOT NULL, INTEREST_LEVEL smallint, CONFUSION_LEVEL smallint, NUM_OBS_ENT int, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, LAST_TOUCH_DT BIGINT, LOCKING_ID BIGINT NOT NULL, NODE_NAME VARCHAR(50) NOT NULL, LOCK_DSRC_ACTION CHAR(1), PRIMARY KEY(RES_ENT_ID, LENS_ID)) PARTITION BY HASH(RES_ENT_ID);

CREATE TABLE RES_ENT_0 PARTITION OF RES_ENT FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_1 PARTITION OF RES_ENT FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_2 PARTITION OF RES_ENT FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE RES_ENT_3 PARTITION OF RES_ENT FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);


-- DANGER: DROP TABLE DSRC_RECORD;
CREATE TABLE DSRC_RECORD (DSRC_ID smallint NOT NULL, RECORD_ID VARCHAR(250) NOT NULL, ETYPE_ID smallint NOT NULL, ENT_SRC_KEY VARCHAR(250) NOT NULL, OBS_ENT_HASH CHAR(40) NOT NULL, JSON_DATA TEXT, CONFIG_ID BIGINT, FIRST_SEEN_DT TIMESTAMP, LAST_SEEN_DT TIMESTAMP, PRIMARY KEY(RECORD_ID, DSRC_ID)) PARTITION BY HASH(RECORD_ID);

CREATE TABLE DSRC_RECORD_0 PARTITION OF DSRC_RECORD FOR VALUES WITH (modulus 4, remainder 0) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_1 PARTITION OF DSRC_RECORD FOR VALUES WITH (modulus 4, remainder 1) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_2 PARTITION OF DSRC_RECORD FOR VALUES WITH (modulus 4, remainder 2) WITH (FILLFACTOR=50);
CREATE TABLE DSRC_RECORD_3 PARTITION OF DSRC_RECORD FOR VALUES WITH (modulus 4, remainder 3) WITH (FILLFACTOR=50);

CREATE INDEX DSRC_RECORD_SK ON DSRC_RECORD(ENT_SRC_KEY, DSRC_ID) ;
CREATE INDEX DSRC_RECORD_HK ON DSRC_RECORD(OBS_ENT_HASH, DSRC_ID, ETYPE_ID) ;

