#!/usr/bin/env bash
# Print ams_address rows for the routes this job touches, in a stable order.
# Used by the golden regression (tests/golden/ams_address.txt). Timestamps
# are left out because they change every run.
set -euo pipefail
psql -At -F '|' -v ON_ERROR_STOP=1 <<'SQL'
SELECT a.addr_id, a.zip5, a.route_id, a.dlvy_seq, a.status_cd,
       rtrim(a.primary_nbr), rtrim(a.street_name),
       coalesce(rtrim(a.unit), '<null>'), coalesce(a.zip4, '<null>')
  FROM ams_address a
 WHERE (a.zip5, a.route_id) IN (SELECT DISTINCT zip5, route_id
                                  FROM ams_address
                                 WHERE status_cd = 'D' OR last_upd_ts >
                                       (SELECT min(last_upd_ts) FROM ams_address))
 ORDER BY a.zip5, a.route_id, a.status_cd, a.dlvy_seq, a.addr_id;
SQL
