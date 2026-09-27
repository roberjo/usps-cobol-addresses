#!/usr/bin/env bash
# =====================================================================
# EBUPD01 -- AMS edit book update. Shell equivalent of jcl/EBUPD01.jcl.
#
# Each DD statement becomes a DD_<name> environment variable, which
# GnuCOBOL uses to resolve SELECT ... ASSIGN TO <name>. Each step runs
# only if no earlier step ended with RC >= 8 (JCL COND=(8,LE)); the
# report step runs unless RC >= 12, so a validation failure still gets
# a reject listing. The job ends with the highest step RC (max CC).
#
#   jobs/ebupd01.sh              normal run from STEP000
#   jobs/ebupd01.sh --restart    resume STEP030 from its last checkpoint
#
# Env: SYSIN (control cards, default ctl/ebupd01.sysin), PG* (database).
# =====================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

JOB=EBUPD01
RESTART=N
[[ "${1:-}" == "--restart" ]] && RESTART=Y

# autocommit=off: EBUPDT decides where units of work end (COMMIT=n).
export EBDB_DSN="pgsql://${PGHOST:-localhost}:${PGPORT:-5432}/${PGDATABASE:-amsdev}?autocommit=off"
export EBDB_AUTH="${PGUSER:-ams}.${PGPASSWORD:-ams}"
export COB_SCREEN_EXCEPTIONS=N

IN=data/in WORK=data/work OUT=data/out
mkdir -p "$WORK" "$OUT"

# SYSIN: the control cards, with RESTART=Y forced on a restart.
SYSIN_SRC=${SYSIN:-ctl/ebupd01.sysin}
export DD_SYSIN=$WORK/sysin.txt
if [[ $RESTART == Y ]]; then
    grep -v '^RESTART=' "$SYSIN_SRC" > "$DD_SYSIN"; echo "RESTART=Y" >> "$DD_SYSIN"
else
    cp "$SYSIN_SRC" "$DD_SYSIN"
fi

maxrc=0
say() { printf '%s %-8s %s\n' "$JOB" "$1" "$2"; }

# step NAME PROGRAM COND-LIMIT: run unless maxrc >= COND-LIMIT
step() {
    local name=$1 pgm=$2 limit=$3 rc
    if (( maxrc >= limit )); then
        say "$name" "$pgm FLUSHED (COND: prior RC $maxrc >= $limit)"
        return
    fi
    say "$name" "$pgm STARTED"
    "./bin/$pgm"
    rc=$?
    say "$name" "$pgm ENDED RC=$(printf '%04d' "$rc")"
    (( rc > maxrc )) && maxrc=$rc
}

ckpt_open() {
    psql -At -c "SELECT count(*) FROM eb_checkpoint
                 WHERE job_name = '$JOB' AND status_cd = 'R'" 2>/dev/null
}

if [[ $RESTART == N ]]; then
    # STEP000 guard: an unfinished run's partial outputs are needed for
    # the restart, so refuse to clean up and start over on top of them.
    if [[ "$(ckpt_open)" == 1 ]]; then
        say STEP000 "EBUPDT HAS AN OPEN CHECKPOINT - RESUBMIT WITH --restart"
        say "$JOB" "ENDED MAXCC=0012"
        exit 12
    fi
    # STEP000 -- IEFBR14-style cleanup: delete last run's datasets.
    rm -f "$WORK"/ebvalout.dat "$WORK"/ebsrtout.dat \
          "$OUT"/ebrej.dat "$OUT"/eburej.dat "$OUT"/ebaudit.dat \
          "$OUT"/ebrpt.txt "$OUT"/ebbook.dat

    # STEP010 -- validate transactions
    export DD_EBTRANS=$IN/ebtrans.dat
    export DD_EBVALOUT=$WORK/ebvalout.dat
    export DD_EBREJ=$OUT/ebrej.dat
    step STEP010 EBVALID 8

    # STEP020 -- sort into update order
    export DD_EBVALOUT=$WORK/ebvalout.dat
    export DD_EBSRTOUT=$WORK/ebsrtout.dat
    export DD_SORTWK01=$WORK/sortwk01.tmp
    step STEP020 EBSORT 8
else
    # Restart prep: drop audit/reject records written after the last
    # commit, so they are not duplicated when EBUPDT reprocesses them.
    read -r audit_cnt rej_cnt < <(psql -At -F ' ' -c \
        "SELECT audit_cnt, recs_rej FROM eb_checkpoint
          WHERE job_name = '$JOB' AND status_cd = 'R'" 2>/dev/null)
    if [[ -n "${audit_cnt:-}" ]]; then
        truncate -s $(( audit_cnt * 150 )) "$OUT/ebaudit.dat"
        truncate -s $(( rej_cnt * 82 )) "$OUT/eburej.dat"
        say RESTART "TRIMMED EBAUDIT TO $audit_cnt, EBUREJ TO $rej_cnt RECORDS"
    fi
    say RESTART "RESUMING AT STEP030"
fi

# STEP030 -- apply to AMS (commit/restart)
export DD_EBSRTOUT=$WORK/ebsrtout.dat
export DD_EBAUDIT=$OUT/ebaudit.dat
export DD_EBUREJ=$OUT/eburej.dat
step STEP030 EBUPDT 8

# STEP040 -- report and edit book extract (runs even after an RC 8)
export DD_EBREJ=$OUT/ebrej.dat
export DD_EBUREJ=$OUT/eburej.dat
export DD_EBAUDIT=$OUT/ebaudit.dat
export DD_EBRPT=$OUT/ebrpt.txt
export DD_EBBOOK=$OUT/ebbook.dat
step STEP040 EBRPT 12

say "$JOB" "ENDED MAXCC=$(printf '%04d' "$maxrc")"
exit "$maxrc"
