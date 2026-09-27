       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBUPDT.
      *================================================================*
      * EBUPDT   - EBUPD01 STEP030: APPLY EDIT BOOK CHANGES TO AMS.    *
      *                                                                *
      * INPUT    SYSIN     CONTROL CARDS (MODE, COMMIT, RESTART)       *
      *          EBSRTOUT  VALID TRANSACTIONS, SORTED BY EBSORT        *
      * UPDATE   AMS_ADDRESS, EB_CHECKPOINT                            *
      * OUTPUT   EBAUDIT   BEFORE/AFTER IMAGES          LRECL=150      *
      *          EBUREJ    UPDATE-TIME REJECTS          LRECL=82       *
      *                                                                *
      * ACTIONS  D  SOFT DELETE (STATUS_CD = 'D'). THE PRIMARY NUMBER  *
      *             MUST MATCH THE ADDRESS AT THAT SEQUENCE.           *
      *          C  REPLACE ADDRESS FIELDS AT THAT SEQUENCE.           *
      *          A  INSERT AT THAT SEQUENCE. IF IT IS OCCUPIED, EVERY  *
      *             ACTIVE ADDRESS AT OR ABOVE IT MOVES UP ONE.        *
      *                                                                *
      * COMMIT/RESTART                                                 *
      *   EVERY COMMIT= RECORDS THE CHECKPOINT ROW IS UPDATED AND      *
      *   COMMITTED WITH THE ADDRESS CHANGES. WITH RESTART=Y THE       *
      *   PROGRAM SKIPS THE RECORDS ALREADY COMMITTED AND CARRIES ON.  *
      *   MODE=VALIDATE DOES ALL THE WORK AND ROLLS IT BACK.           *
      *                                                                *
      * RC  0  ALL APPLIED    4  SOME UPDATE REJECTS                   *
      *    12  FILE ERROR, BAD CONTROL CARD, UNEXPECTED SQLCODE,       *
      *        OR AN UNFINISHED PRIOR RUN WITHOUT RESTART=Y            *
      *    16  SIMULATED ABEND (EBUPDT_ABEND_AFTER, RESTART DRILLS)    *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE    ASSIGN TO SYSIN
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS CTL-SYSIN-FS.
           SELECT EBSRTOUT-FILE ASSIGN TO EBSRTOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-SRT-FS.
           SELECT EBAUDIT-FILE  ASSIGN TO EBAUDIT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-AUD-FS.
           SELECT EBUREJ-FILE   ASSIGN TO EBUREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-REJ-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                PIC X(80).
       FD  EBSRTOUT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01  EBSRTOUT-REC             PIC X(80).
       FD  EBAUDIT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 150 CHARACTERS.
       COPY EBAUDIT.
       FD  EBUREJ-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 82 CHARACTERS.
       COPY EBREJ.

       WORKING-STORAGE SECTION.
       01  WS-PGM-ID                PIC X(8)  VALUE 'EBUPDT'.
       01  WS-JOB-NAME              PIC X(8)  VALUE 'EBUPD01'.
       01  WS-FILE-STATUS.
           05  WS-SRT-FS            PIC X(2).
           05  WS-AUD-FS            PIC X(2).
           05  WS-REJ-FS            PIC X(2).
       01  WS-SWITCHES.
           05  WS-EOF-SW            PIC X(1)  VALUE 'N'.
               88  WS-EOF                     VALUE 'Y'.
           05  WS-RESTARTING-SW     PIC X(1)  VALUE 'N'.
               88  WS-RESTARTING              VALUE 'Y'.
       01  WS-COUNTERS.
           05  WS-READ-CNT          PIC S9(9) COMP VALUE ZERO.
           05  WS-SKIP-CNT          PIC S9(9) COMP VALUE ZERO.
           05  WS-APPLIED-CNT       PIC S9(9) COMP VALUE ZERO.
           05  WS-REJ-CNT           PIC S9(9) COMP VALUE ZERO.
           05  WS-AUDIT-CNT         PIC S9(9) COMP VALUE ZERO.
           05  WS-ADD-CNT           PIC S9(9) COMP VALUE ZERO.
           05  WS-CHG-CNT           PIC S9(9) COMP VALUE ZERO.
           05  WS-DEL-CNT           PIC S9(9) COMP VALUE ZERO.
           05  WS-SHIFT-TOT         PIC S9(9) COMP VALUE ZERO.
           05  WS-SINCE-COMMIT      PIC S9(9) COMP VALUE ZERO.
           05  WS-ROUTE-CNT         PIC S9(9) COMP VALUE ZERO.
       01  WS-PRIOR-KEY.
           05  WS-PRIOR-ZIP5        PIC X(5)  VALUE LOW-VALUES.
           05  WS-PRIOR-ROUTE       PIC X(4)  VALUE LOW-VALUES.
       01  WS-CURR-KEY.
           05  WS-CURR-ZIP5         PIC X(5).
           05  WS-CURR-ROUTE        PIC X(4).
       01  WS-REASON-CD             PIC X(2).
       01  WS-ABEND-AFTER-X         PIC X(9).
       01  WS-ABEND-AFTER           PIC 9(9)  VALUE ZERO.
       01  WS-DISPLAY-CNT           PIC ZZZ,ZZZ,ZZ9.
       01  WS-DISPLAY-SEQ           PIC Z(6)9.

       COPY EBTRANS.
       COPY EBCTLWS.

           EXEC SQL INCLUDE SQLCA END-EXEC.
      *    NUMERIC HOST VARIABLES ARE COMP-3: GIXSQL 1.0.20B SENDS
      *    BINARY (COMP/COMP-5) INPUT VARIABLES WRONGLY. DB2 TAKES BOTH.
      *    NULL INDICATORS MUST STAY S9(4) COMP (ONLY 0 AND -1 USED).
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
           EXEC SQL INCLUDE EBDBWS END-EXEC.
       01  HV-ADDRESS.
           05  HV-ADDR-ID           PIC S9(18) COMP-3.
           05  HV-ZIP5              PIC X(5).
           05  HV-ROUTE-ID          PIC X(4).
           05  HV-DLVY-SEQ          PIC S9(9) COMP-3.
           05  HV-PRIMARY-NBR       PIC X(10).
           05  HV-STREET-NAME       PIC X(28).
           05  HV-UNIT              PIC X(8).
           05  HV-ZIP4              PIC X(4).
       01  HV-UNIT-IND              PIC S9(4) COMP.
       01  HV-ZIP4-IND              PIC S9(4) COMP.
       01  HV-COUNT                 PIC S9(9) COMP-3.
       01  HV-CHECKPOINT.
           05  HV-JOB-NAME          PIC X(8).
           05  HV-CK-STATUS         PIC X(1).
           05  HV-CK-READ           PIC S9(9) COMP-3.
           05  HV-CK-APPLIED        PIC S9(9) COMP-3.
           05  HV-CK-REJ            PIC S9(9) COMP-3.
           05  HV-CK-AUDIT          PIC S9(9) COMP-3.
           05  HV-CK-ZIP5           PIC X(5).
           05  HV-CK-ROUTE          PIC X(4).
           05  HV-CK-SEQ            PIC S9(9) COMP-3.
           EXEC SQL END DECLARE SECTION END-EXEC.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-TRANS UNTIL WS-EOF
           PERFORM 3000-TERMINATE
           GOBACK
           .

      *----------------------------------------------------------------*
      * INITIALIZATION AND RESTART                                     *
      *----------------------------------------------------------------*
       1000-INITIALIZE.
           PERFORM 9100-READ-CONTROL-CARDS
           IF CTL-ERROR
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           DISPLAY 'EBUPDT MODE=' CTL-MODE ' COMMIT=' CTL-COMMIT
                   ' RESTART=' CTL-RESTART
           ACCEPT WS-ABEND-AFTER-X FROM ENVIRONMENT
               'EBUPDT_ABEND_AFTER'
           IF WS-ABEND-AFTER-X NOT = SPACES
               COMPUTE WS-ABEND-AFTER =
                   FUNCTION NUMVAL(WS-ABEND-AFTER-X)
               DISPLAY 'EBUPDT DRILL: WILL ABEND AFTER RECORD '
                       WS-ABEND-AFTER
           END-IF
           MOVE WS-JOB-NAME TO HV-JOB-NAME
           PERFORM 9800-DB-CONNECT
           PERFORM 1100-CHECK-RESTART
           OPEN INPUT EBSRTOUT-FILE
           IF WS-RESTARTING
               OPEN EXTEND EBAUDIT-FILE EBUREJ-FILE
           ELSE
               OPEN OUTPUT EBAUDIT-FILE EBUREJ-FILE
           END-IF
           IF WS-SRT-FS NOT = '00' OR WS-AUD-FS NOT = '00'
              OR WS-REJ-FS NOT = '00'
               DISPLAY 'EBUPDT EBU0001E OPEN FAILED EBSRTOUT='
                       WS-SRT-FS ' EBAUDIT=' WS-AUD-FS
                       ' EBUREJ=' WS-REJ-FS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 8000-READ-TRANS
           PERFORM UNTIL WS-EOF OR WS-READ-CNT > WS-SKIP-CNT
               PERFORM 8000-READ-TRANS
           END-PERFORM
           .

       1100-CHECK-RESTART.
           EXEC SQL
               SELECT STATUS_CD, RECS_READ, RECS_APPLIED, RECS_REJ,
                      AUDIT_CNT, LAST_ZIP5, LAST_ROUTE, LAST_SEQ
                 INTO :HV-CK-STATUS, :HV-CK-READ, :HV-CK-APPLIED,
                      :HV-CK-REJ, :HV-CK-AUDIT, :HV-CK-ZIP5,
                      :HV-CK-ROUTE, :HV-CK-SEQ
                 FROM EB_CHECKPOINT
                WHERE JOB_NAME = :HV-JOB-NAME
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   CONTINUE
               WHEN 100
                   MOVE 'C' TO HV-CK-STATUS
               WHEN OTHER
                   PERFORM 9900-SQL-ERROR
           END-EVALUATE

           EVALUATE TRUE
               WHEN HV-CK-STATUS = 'R' AND CTL-RESTART-YES
                   SET WS-RESTARTING TO TRUE
                   MOVE HV-CK-READ    TO WS-SKIP-CNT
                   MOVE HV-CK-APPLIED TO WS-APPLIED-CNT
                   MOVE HV-CK-REJ     TO WS-REJ-CNT
                   MOVE HV-CK-AUDIT   TO WS-AUDIT-CNT
                   MOVE HV-CK-SEQ     TO WS-DISPLAY-SEQ
                   MOVE WS-SKIP-CNT   TO WS-DISPLAY-CNT
                   DISPLAY 'EBUPDT EBU0002I RESTARTING AFTER RECORD'
                           WS-DISPLAY-CNT ' KEY ' HV-CK-ZIP5 '/'
                           HV-CK-ROUTE '/' WS-DISPLAY-SEQ
               WHEN HV-CK-STATUS = 'R'
                   DISPLAY 'EBUPDT EBU0003E PRIOR RUN DID NOT FINISH -'
                           ' RESUBMIT WITH RESTART=Y'
                   MOVE 12 TO RETURN-CODE
                   STOP RUN
               WHEN CTL-RESTART-YES
                   DISPLAY 'EBUPDT EBU0004W RESTART=Y BUT NO OPEN'
                           ' CHECKPOINT - STARTING FROM THE TOP'
                   PERFORM 1200-START-CHECKPOINT
               WHEN OTHER
                   PERFORM 1200-START-CHECKPOINT
           END-EVALUATE
           .

      *    THE 'R' ROW IS ONLY COMMITTED WITH THE FIRST BATCH OF
      *    UPDATES. AN ABEND BEFORE THAT LEAVES NOTHING TO RESTART.
       1200-START-CHECKPOINT.
           IF CTL-MODE-UPDATE
               EXEC SQL
                   DELETE FROM EB_CHECKPOINT
                    WHERE JOB_NAME = :HV-JOB-NAME
               END-EXEC
               IF SQLCODE NOT = 0 AND NOT = 100
                   PERFORM 9900-SQL-ERROR
               END-IF
               EXEC SQL
                   INSERT INTO EB_CHECKPOINT
                          (JOB_NAME, STATUS_CD, RECS_READ,
                           RECS_APPLIED, RECS_REJ, AUDIT_CNT,
                           LAST_ZIP5, LAST_ROUTE, LAST_SEQ)
                   VALUES (:HV-JOB-NAME, 'R', 0, 0, 0, 0,
                           ' ', ' ', 0)
               END-EXEC
               IF SQLCODE NOT = 0
                   PERFORM 9900-SQL-ERROR
               END-IF
           END-IF
           .

      *----------------------------------------------------------------*
      * MAIN LOOP                                                      *
      *----------------------------------------------------------------*
       2000-PROCESS-TRANS.
           MOVE EBSRTOUT-REC TO EB-TRANS-REC
           MOVE EBT-ZIP5     TO WS-CURR-ZIP5
           MOVE EBT-ROUTE-ID TO WS-CURR-ROUTE
           IF WS-CURR-KEY NOT = WS-PRIOR-KEY
               PERFORM 2900-ROUTE-BREAK
           END-IF
           ADD 1 TO WS-ROUTE-CNT

           MOVE EBT-ZIP5        TO HV-ZIP5
           MOVE EBT-ROUTE-ID    TO HV-ROUTE-ID
           MOVE EBT-DLVY-SEQ    TO HV-DLVY-SEQ
           MOVE '00'            TO WS-REASON-CD
           EVALUATE TRUE
               WHEN EBT-DELETE
                   PERFORM 2100-APPLY-DELETE
               WHEN EBT-CHANGE
                   PERFORM 2200-APPLY-CHANGE
               WHEN EBT-ADD
                   PERFORM 2300-APPLY-ADD
           END-EVALUATE
           IF WS-REASON-CD NOT = '00'
               PERFORM 2800-WRITE-REJECT
           END-IF

           ADD 1 TO WS-SINCE-COMMIT
           IF WS-SINCE-COMMIT >= CTL-COMMIT
               PERFORM 7000-CHECKPOINT
           END-IF
           IF WS-ABEND-AFTER > ZERO AND WS-READ-CNT = WS-ABEND-AFTER
               PERFORM 9990-SIMULATED-ABEND
           END-IF
           PERFORM 8000-READ-TRANS
           .

       2100-APPLY-DELETE.
           PERFORM 6000-SELECT-AT-SEQ
           IF WS-REASON-CD = '00'
               IF HV-PRIMARY-NBR NOT = EBT-PRIMARY-NBR
                   MOVE '12' TO WS-REASON-CD
               ELSE
                   EXEC SQL
                       UPDATE AMS_ADDRESS
                          SET STATUS_CD   = 'D',
                              LAST_UPD_TS = CURRENT_TIMESTAMP
                        WHERE ADDR_ID = :HV-ADDR-ID
                   END-EXEC
                   IF SQLCODE NOT = 0
                       PERFORM 9900-SQL-ERROR
                   END-IF
                   PERFORM 6100-AUDIT-BEFORE
                   MOVE EBA-BEFORE TO EBA-AFTER
                   MOVE 'D'        TO EBA-A-STATUS-CD
                   ADD 1 TO WS-DEL-CNT
                   PERFORM 2700-WRITE-AUDIT
               END-IF
           END-IF
           .

       2200-APPLY-CHANGE.
           PERFORM 6000-SELECT-AT-SEQ
           IF WS-REASON-CD = '00'
               PERFORM 6100-AUDIT-BEFORE
               PERFORM 6200-TRANS-TO-HOST
               EXEC SQL
                   UPDATE AMS_ADDRESS
                      SET PRIMARY_NBR = :HV-PRIMARY-NBR,
                          STREET_NAME = :HV-STREET-NAME,
                          UNIT        = :HV-UNIT:HV-UNIT-IND,
                          ZIP4        = :HV-ZIP4:HV-ZIP4-IND,
                          LAST_UPD_TS = CURRENT_TIMESTAMP
                    WHERE ADDR_ID = :HV-ADDR-ID
               END-EXEC
               IF SQLCODE NOT = 0
                   PERFORM 9900-SQL-ERROR
               END-IF
               PERFORM 6300-AUDIT-AFTER
               ADD 1 TO WS-CHG-CNT
               PERFORM 2700-WRITE-AUDIT
           END-IF
           .

       2300-APPLY-ADD.
           PERFORM 6200-TRANS-TO-HOST
           EXEC SQL
               SELECT COUNT(*)
                 INTO :HV-COUNT
                 FROM AMS_ADDRESS
                WHERE ZIP5        = :HV-ZIP5
                  AND ROUTE_ID    = :HV-ROUTE-ID
                  AND PRIMARY_NBR = :HV-PRIMARY-NBR
                  AND STREET_NAME = :HV-STREET-NAME
                  AND COALESCE(UNIT, ' ') = :HV-UNIT
                  AND STATUS_CD   = 'A'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           IF HV-COUNT > ZERO
               MOVE '11' TO WS-REASON-CD
               EXIT PARAGRAPH
           END-IF

           MOVE ZERO TO EBA-SHIFT-CNT
           PERFORM 2400-RESEQUENCE
           EXEC SQL
               INSERT INTO AMS_ADDRESS
                      (ZIP5, ZIP4, ROUTE_ID, DLVY_SEQ, PRIMARY_NBR,
                       STREET_NAME, UNIT, STATUS_CD)
               VALUES (:HV-ZIP5, :HV-ZIP4:HV-ZIP4-IND, :HV-ROUTE-ID,
                       :HV-DLVY-SEQ, :HV-PRIMARY-NBR, :HV-STREET-NAME,
                       :HV-UNIT:HV-UNIT-IND, 'A')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           EXEC SQL
               SELECT ADDR_ID
                 INTO :HV-ADDR-ID
                 FROM AMS_ADDRESS
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ  = :HV-DLVY-SEQ
                  AND STATUS_CD = 'A'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           MOVE SPACES TO EBA-BEFORE
           PERFORM 6300-AUDIT-AFTER
           ADD 1 TO WS-ADD-CNT
           PERFORM 2700-WRITE-AUDIT
           .

      *    OPEN UP THE TARGET SEQUENCE IF IT IS TAKEN. THE SHIFT IS
      *    DONE IN TWO PASSES (NEGATE, THEN FLIP BACK) BECAUSE A
      *    SINGLE SET DLVY_SEQ = DLVY_SEQ + 1 CAN COLLIDE WITH THE
      *    UNIQUE INDEX PART WAY THROUGH, DEPENDING ON ROW ORDER.
       2400-RESEQUENCE.
           EXEC SQL
               SELECT COUNT(*)
                 INTO :HV-COUNT
                 FROM AMS_ADDRESS
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ  = :HV-DLVY-SEQ
                  AND STATUS_CD = 'A'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           IF HV-COUNT = ZERO
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT COUNT(*)
                 INTO :HV-COUNT
                 FROM AMS_ADDRESS
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ >= :HV-DLVY-SEQ
                  AND STATUS_CD = 'A'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           MOVE HV-COUNT TO EBA-SHIFT-CNT
           ADD HV-COUNT  TO WS-SHIFT-TOT
           EXEC SQL
               UPDATE AMS_ADDRESS
                  SET DLVY_SEQ    = -(DLVY_SEQ + 1),
                      LAST_UPD_TS = CURRENT_TIMESTAMP
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ >= :HV-DLVY-SEQ
                  AND STATUS_CD = 'A'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           EXEC SQL
               UPDATE AMS_ADDRESS
                  SET DLVY_SEQ = -DLVY_SEQ
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ  < 0
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           .

       2700-WRITE-AUDIT.
           MOVE EBT-ACTION-CD TO EBA-ACTION-CD
           MOVE EBT-ZIP5      TO EBA-ZIP5
           MOVE EBT-ROUTE-ID  TO EBA-ROUTE-ID
           MOVE HV-DLVY-SEQ   TO EBA-DLVY-SEQ
           MOVE HV-ADDR-ID    TO EBA-ADDR-ID
           MOVE CTL-RUNDATE   TO EBA-RUN-DATE
           IF NOT EBT-ADD
               MOVE ZERO TO EBA-SHIFT-CNT
           END-IF
           WRITE EB-AUDIT-REC
           IF WS-AUD-FS NOT = '00'
               DISPLAY 'EBUPDT EBU0005E EBAUDIT WRITE FAILED, STATUS '
                       WS-AUD-FS
               PERFORM 9900-SQL-ERROR
           END-IF
           ADD 1 TO WS-AUDIT-CNT
           ADD 1 TO WS-APPLIED-CNT
           .

       2800-WRITE-REJECT.
           MOVE EB-TRANS-REC  TO EBR-TRANS-IMAGE
           MOVE WS-REASON-CD  TO EBR-REASON-CD
           WRITE EB-REJ-REC
           ADD 1 TO WS-REJ-CNT
           .

      *    CONTROL BREAK ON ZIP5 + ROUTE: SYSOUT LINE PER ROUTE.
       2900-ROUTE-BREAK.
           IF WS-PRIOR-KEY NOT = LOW-VALUES
               MOVE WS-ROUTE-CNT TO WS-DISPLAY-CNT
               DISPLAY 'EBUPDT ROUTE ' WS-PRIOR-ZIP5 '/'
                       WS-PRIOR-ROUTE ' TRANSACTIONS' WS-DISPLAY-CNT
           END-IF
           MOVE WS-CURR-KEY TO WS-PRIOR-KEY
           MOVE ZERO TO WS-ROUTE-CNT
           .

      *----------------------------------------------------------------*
      * TERMINATION                                                    *
      *----------------------------------------------------------------*
       3000-TERMINATE.
           MOVE LOW-VALUES TO WS-CURR-KEY
           PERFORM 2900-ROUTE-BREAK
           IF CTL-MODE-UPDATE
               MOVE 'C' TO HV-CK-STATUS
               PERFORM 7100-UPDATE-CHECKPOINT
               EXEC SQL COMMIT END-EXEC
               IF SQLCODE NOT = 0
                   PERFORM 9900-SQL-ERROR
               END-IF
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY 'EBUPDT EBU0006I MODE=VALIDATE - ALL CHANGES'
                       ' ROLLED BACK'
           END-IF
           CLOSE EBSRTOUT-FILE EBAUDIT-FILE EBUREJ-FILE
           PERFORM 9810-DB-DISCONNECT

           MOVE WS-READ-CNT    TO WS-DISPLAY-CNT
           DISPLAY 'EBUPDT RECORDS READ      ' WS-DISPLAY-CNT
           MOVE WS-SKIP-CNT    TO WS-DISPLAY-CNT
           DISPLAY 'EBUPDT SKIPPED (RESTART) ' WS-DISPLAY-CNT
           MOVE WS-APPLIED-CNT TO WS-DISPLAY-CNT
           DISPLAY 'EBUPDT APPLIED           ' WS-DISPLAY-CNT
           MOVE WS-REJ-CNT     TO WS-DISPLAY-CNT
           DISPLAY 'EBUPDT REJECTED          ' WS-DISPLAY-CNT
           MOVE WS-SHIFT-TOT   TO WS-DISPLAY-CNT
           DISPLAY 'EBUPDT ROWS RESEQUENCED  ' WS-DISPLAY-CNT
           IF WS-REJ-CNT > ZERO
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE 0 TO RETURN-CODE
           END-IF
           .

      *----------------------------------------------------------------*
      * COMMIT / CHECKPOINT                                            *
      *----------------------------------------------------------------*
       7000-CHECKPOINT.
           IF CTL-MODE-UPDATE
               MOVE 'R' TO HV-CK-STATUS
               PERFORM 7100-UPDATE-CHECKPOINT
               EXEC SQL COMMIT END-EXEC
               IF SQLCODE NOT = 0
                   PERFORM 9900-SQL-ERROR
               END-IF
           END-IF
           MOVE ZERO TO WS-SINCE-COMMIT
           .

       7100-UPDATE-CHECKPOINT.
           MOVE WS-READ-CNT    TO HV-CK-READ
           MOVE WS-APPLIED-CNT TO HV-CK-APPLIED
           MOVE WS-REJ-CNT     TO HV-CK-REJ
           MOVE WS-AUDIT-CNT   TO HV-CK-AUDIT
           MOVE EBT-ZIP5       TO HV-CK-ZIP5
           MOVE EBT-ROUTE-ID   TO HV-CK-ROUTE
           MOVE HV-DLVY-SEQ    TO HV-CK-SEQ
           EXEC SQL
               UPDATE EB_CHECKPOINT
                  SET STATUS_CD    = :HV-CK-STATUS,
                      RECS_READ    = :HV-CK-READ,
                      RECS_APPLIED = :HV-CK-APPLIED,
                      RECS_REJ     = :HV-CK-REJ,
                      AUDIT_CNT    = :HV-CK-AUDIT,
                      LAST_ZIP5    = :HV-CK-ZIP5,
                      LAST_ROUTE   = :HV-CK-ROUTE,
                      LAST_SEQ     = :HV-CK-SEQ,
                      UPD_TS       = CURRENT_TIMESTAMP
                WHERE JOB_NAME = :HV-JOB-NAME
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           .

      *----------------------------------------------------------------*
      * SHARED ROUTINES                                                *
      *----------------------------------------------------------------*
       6000-SELECT-AT-SEQ.
           EXEC SQL
               SELECT ADDR_ID, PRIMARY_NBR, STREET_NAME, UNIT, ZIP4
                 INTO :HV-ADDR-ID, :HV-PRIMARY-NBR, :HV-STREET-NAME,
                      :HV-UNIT:HV-UNIT-IND, :HV-ZIP4:HV-ZIP4-IND
                 FROM AMS_ADDRESS
                WHERE ZIP5      = :HV-ZIP5
                  AND ROUTE_ID  = :HV-ROUTE-ID
                  AND DLVY_SEQ  = :HV-DLVY-SEQ
                  AND STATUS_CD = 'A'
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   IF HV-UNIT-IND < 0
                       MOVE SPACES TO HV-UNIT
                   END-IF
                   IF HV-ZIP4-IND < 0
                       MOVE SPACES TO HV-ZIP4
                   END-IF
               WHEN 100
                   MOVE '10' TO WS-REASON-CD
               WHEN OTHER
                   PERFORM 9900-SQL-ERROR
           END-EVALUATE
           .

       6100-AUDIT-BEFORE.
           MOVE HV-PRIMARY-NBR TO EBA-B-PRIMARY-NBR
           MOVE HV-STREET-NAME TO EBA-B-STREET-NAME
           MOVE HV-UNIT        TO EBA-B-UNIT
           MOVE HV-ZIP4        TO EBA-B-ZIP4
           MOVE 'A'            TO EBA-B-STATUS-CD
           .

      *    BLANK UNIT OR ZIP4 IS STORED AS NULL (INDICATOR -1).
       6200-TRANS-TO-HOST.
           MOVE EBT-PRIMARY-NBR TO HV-PRIMARY-NBR
           MOVE EBT-STREET-NAME TO HV-STREET-NAME
           MOVE EBT-UNIT        TO HV-UNIT
           MOVE EBT-ZIP4        TO HV-ZIP4
           IF HV-UNIT = SPACES
               MOVE -1 TO HV-UNIT-IND
           ELSE
               MOVE 0 TO HV-UNIT-IND
           END-IF
           IF HV-ZIP4 = SPACES
               MOVE -1 TO HV-ZIP4-IND
           ELSE
               MOVE 0 TO HV-ZIP4-IND
           END-IF
           .

       6300-AUDIT-AFTER.
           MOVE HV-PRIMARY-NBR TO EBA-A-PRIMARY-NBR
           MOVE HV-STREET-NAME TO EBA-A-STREET-NAME
           MOVE HV-UNIT        TO EBA-A-UNIT
           MOVE HV-ZIP4        TO EBA-A-ZIP4
           MOVE 'A'            TO EBA-A-STATUS-CD
           .

       8000-READ-TRANS.
           READ EBSRTOUT-FILE
               AT END
                   SET WS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-READ-CNT
           END-READ
           IF WS-SRT-FS NOT = '00' AND NOT = '10'
               DISPLAY 'EBUPDT EBU0007E EBSRTOUT READ ERROR, STATUS '
                       WS-SRT-FS
               PERFORM 9900-SQL-ERROR
           END-IF
           .

      *    RESTART DRILL: END WITHOUT COMMITTING, AS IF THE JOB WAS
      *    CANCELLED. WORK SINCE THE LAST CHECKPOINT IS ROLLED BACK.
       9990-SIMULATED-ABEND.
           DISPLAY 'EBUPDT EBU0999S SIMULATED ABEND AFTER RECORD '
                   WS-ABEND-AFTER ' - UNCOMMITTED WORK ROLLED BACK'
           EXEC SQL ROLLBACK END-EXEC
           CLOSE EBSRTOUT-FILE EBAUDIT-FILE EBUREJ-FILE
           MOVE 16 TO RETURN-CODE
           STOP RUN
           .

       COPY EBCTLRD.
           EXEC SQL INCLUDE EBDBPD END-EXEC.
