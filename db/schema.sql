-- AMS Edit Book mock: master tables (PostgreSQL 16 standing in for DB2 for z/OS).
-- Text columns are CHAR(n), blank-padded like DB2 CHAR, so COBOL PIC X host
-- variables compare cleanly. See sql/db2-notes.md for the DB2 equivalents.

DROP TABLE IF EXISTS eb_checkpoint;
DROP TABLE IF EXISTS ams_address;
DROP TABLE IF EXISTS ams_route;

CREATE TABLE ams_route (
  zip5        CHAR(5) NOT NULL,
  route_id    CHAR(4) NOT NULL,
  route_type  CHAR(1) NOT NULL,           -- R = rural, C = city
  PRIMARY KEY (zip5, route_id)
);

CREATE TABLE ams_address (
  addr_id      BIGSERIAL   PRIMARY KEY,
  zip5         CHAR(5)     NOT NULL,
  zip4         CHAR(4),                   -- NULL = not yet assigned
  route_id     CHAR(4)     NOT NULL,
  dlvy_seq     INTEGER     NOT NULL,
  primary_nbr  CHAR(10)    NOT NULL,
  street_name  CHAR(28)    NOT NULL,
  unit         CHAR(8),                   -- NULL = no secondary unit
  status_cd    CHAR(1)     NOT NULL DEFAULT 'A',   -- A active, D deleted
  last_upd_ts  TIMESTAMP   NOT NULL DEFAULT now(),
  FOREIGN KEY (zip5, route_id) REFERENCES ams_route
);

-- One active address per delivery position. Postgres-only partial index; on
-- DB2 for z/OS this rule is enforced in EBUPDT (see sql/db2-notes.md).
CREATE UNIQUE INDEX ux_active_seq
  ON ams_address (zip5, route_id, dlvy_seq) WHERE status_cd = 'A';

-- Commit/restart control for EBUPDT. Updated in the same unit of work as the
-- address changes it describes, so a restart resumes exactly after the last commit.
CREATE TABLE eb_checkpoint (
  job_name     CHAR(8)   NOT NULL PRIMARY KEY,
  status_cd    CHAR(1)   NOT NULL,        -- R running (restartable), C complete
  recs_read    INTEGER   NOT NULL,
  recs_applied INTEGER   NOT NULL,
  recs_rej     INTEGER   NOT NULL,
  audit_cnt    INTEGER   NOT NULL,
  last_zip5    CHAR(5)   NOT NULL,
  last_route   CHAR(4)   NOT NULL,
  last_seq     INTEGER   NOT NULL,
  upd_ts       TIMESTAMP NOT NULL DEFAULT now()
);
