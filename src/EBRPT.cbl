       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBRPT.
      *================================================================*
      * EBRPT    - EBUPD01 STEP040: RUN REPORT AND EDIT BOOK EXTRACT.  *
      *                                                                *
      * INPUT    SYSIN     CONTROL CARDS (RUNDATE, MODE)               *
      *          EBREJ     EBVALID REJECTS                 (OPTIONAL)  *
      *          EBUREJ    EBUPDT REJECTS                  (OPTIONAL)  *
      *          EBAUDIT   APPLIED ACTIONS                 (OPTIONAL)  *
      *          AMS_ADDRESS ACTIVE ADDRESSES (CURSOR BOOKCUR)         *
      * OUTPUT   EBRPT     132-COLUMN REPORT, ASA CARRIAGE CONTROL     *
      *          EBBOOK    ACTIVE ADDRESSES OF EVERY ROUTE CHANGED     *
      *                    THIS RUN, IN DELIVERY ORDER     LRECL=80    *
      *                                                                *
      * THE UPDATE FILES ARE OPTIONAL BECAUSE THIS STEP ALSO RUNS WHEN *
      * EBVALID ENDS RC 8 AND THE UPDATE WAS BYPASSED.                 *
      *                                                                *
      * RC  0  REPORT WRITTEN    12  FILE ERROR OR UNEXPECTED SQLCODE  *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE  ASSIGN TO SYSIN
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS CTL-SYSIN-FS.
           SELECT OPTIONAL EBREJ-FILE   ASSIGN TO EBREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-IN-FS.
           SELECT OPTIONAL EBUREJ-FILE  ASSIGN TO EBUREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-IN-FS.
           SELECT OPTIONAL EBAUDIT-FILE ASSIGN TO EBAUDIT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-AUD-FS.
           SELECT EBRPT-FILE  ASSIGN TO EBRPT
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RPT-FS.
           SELECT EBBOOK-FILE ASSIGN TO EBBOOK
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-BOOK-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                PIC X(80).
       FD  EBREJ-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 82 CHARACTERS.
       01  EBREJ-IN                 PIC X(82).
       FD  EBUREJ-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 82 CHARACTERS.
       01  EBUREJ-IN                PIC X(82).
       FD  EBAUDIT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 150 CHARACTERS.
       COPY EBAUDIT.
      *    133 BYTES: ASA CONTROL CHARACTER + 132 PRINT POSITIONS
       FD  EBRPT-FILE.
       01  EBRPT-REC.
           05  RPT-ASA              PIC X(1).
           05  RPT-LINE             PIC X(132).
       FD  EBBOOK-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       COPY EBBOOK.

       WORKING-STORAGE SECTION.
       01  WS-PGM-ID                PIC X(8)  VALUE 'EBRPT'.
       01  WS-FILE-STATUS.
           05  WS-IN-FS             PIC X(2).
           05  WS-AUD-FS            PIC X(2).
           05  WS-RPT-FS            PIC X(2).
           05  WS-BOOK-FS           PIC X(2).
       01  WS-SWITCHES.
           05  WS-EOF-SW            PIC X(1).
               88  WS-EOF                     VALUE 'Y'.
               88  WS-NOT-EOF                 VALUE 'N'.
           05  WS-UPDATE-RAN-SW     PIC X(1)  VALUE 'Y'.
               88  WS-UPDATE-RAN              VALUE 'Y'.
       01  WS-STEP-NAME             PIC X(8).
       01  WS-SUB                   PIC S9(4) COMP.
       01  WS-SUB2                  PIC S9(4) COMP.
       01  WS-RSN-NBR               PIC 99.

      *    PER-ROUTE TOTALS, KEPT IN ZIP5/ROUTE ORDER BY INSERTION.
       01  WS-ROUTE-TABLE.
           05  WS-RT-COUNT          PIC S9(4) COMP VALUE ZERO.
           05  WS-RT-MAX            PIC S9(4) COMP VALUE 200.
           05  WS-RT-ENTRY          OCCURS 1 TO 200 TIMES
                                    DEPENDING ON WS-RT-COUNT.
               10  WS-RT-KEY.
                   15  WS-RT-ZIP5   PIC X(5).
                   15  WS-RT-ROUTE  PIC X(4).
               10  WS-RT-ADDS       PIC S9(7) COMP-3.
               10  WS-RT-CHGS       PIC S9(7) COMP-3.
               10  WS-RT-DELS       PIC S9(7) COMP-3.
               10  WS-RT-SHIFT      PIC S9(7) COMP-3.
               10  WS-RT-VREJ       PIC S9(7) COMP-3.
               10  WS-RT-UREJ       PIC S9(7) COMP-3.
               10  WS-RT-ACTIVE     PIC S9(7) COMP-3.
       01  WS-FIND-KEY.
           05  WS-FIND-ZIP5         PIC X(5).
           05  WS-FIND-ROUTE        PIC X(4).
       01  WS-RSN-COUNTS.
           05  WS-RSN-CNT           PIC S9(7) COMP-3 OCCURS 12 TIMES.
       01  WS-TOTALS.
           05  WS-TOT-ADDS          PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-CHGS          PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-DELS          PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-SHIFT         PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-VREJ          PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-UREJ          PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-TOT-ACTIVE        PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-BOOK-ROUTES       PIC S9(7) COMP-3 VALUE ZERO.
           05  WS-BOOK-RECS         PIC S9(7) COMP-3 VALUE ZERO.

       01  WS-PRINT-CONTROL.
           05  WS-LINE-CNT          PIC S9(4) COMP VALUE 99.
           05  WS-LINES-PER-PAGE    PIC S9(4) COMP VALUE 55.
           05  WS-PAGE-CNT          PIC S9(4) COMP VALUE ZERO.
           05  WS-ASA               PIC X(1).
           05  WS-PRINT-LINE        PIC X(132).
           05  WS-SECTION-TITLE     PIC X(60).
           05  WS-COL-HDR1          PIC X(132).
           05  WS-COL-HDR2          PIC X(132).

       01  HDR-TITLE.
           05  FILLER               PIC X(10) VALUE 'EBRPT'.
           05  FILLER               PIC X(40)
               VALUE 'AMS EDIT BOOK UPDATE - JOB EBUPD01'.
           05  FILLER               PIC X(9)  VALUE 'RUN DATE'.
           05  HT-RUNDATE           PIC 9999/99/99.
           05  FILLER               PIC X(4)  VALUE SPACES.
           05  FILLER               PIC X(5)  VALUE 'MODE'.
           05  HT-MODE              PIC X(8).
           05  FILLER               PIC X(36) VALUE SPACES.
           05  FILLER               PIC X(5)  VALUE 'PAGE'.
           05  HT-PAGE              PIC ZZZ9.
           05  FILLER               PIC X(1)  VALUE SPACES.

       01  REJ-HDR1.
           05  FILLER               PIC X(9)  VALUE 'STEP'.
           05  FILLER               PIC X(4)  VALUE 'RSN'.
           05  FILLER               PIC X(26) VALUE 'DESCRIPTION'.
           05  FILLER               PIC X(4)  VALUE 'ACT'.
           05  FILLER               PIC X(6)  VALUE 'ZIP5'.
           05  FILLER               PIC X(5)  VALUE 'RTE'.
           05  FILLER               PIC X(9)  VALUE '    SEQ'.
           05  FILLER               PIC X(11) VALUE 'PRIMARY'.
           05  FILLER               PIC X(30) VALUE 'STREET NAME'.
           05  FILLER               PIC X(10) VALUE 'UNIT'.
           05  FILLER               PIC X(7)  VALUE 'CARR'.
           05  FILLER               PIC X(11) VALUE 'EDITDATE'.
       01  REJ-DETAIL.
           05  RD-STEP              PIC X(8).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  RD-RSN               PIC X(2).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-DESC              PIC X(25).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-ACT               PIC X(1).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-ZIP5              PIC X(5).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  RD-ROUTE             PIC X(4).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  RD-SEQ               PIC -(6)9.
           05  RD-SEQ-X REDEFINES RD-SEQ PIC X(7).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-PRIMARY           PIC X(10).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  RD-STREET            PIC X(28).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-UNIT              PIC X(8).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RD-CARRIER           PIC X(6).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  RD-DATE              PIC X(8).
           05  FILLER               PIC X(3)  VALUE SPACES.

       01  RSN-HDR1.
           05  FILLER               PIC X(4)  VALUE 'RSN'.
           05  FILLER               PIC X(34) VALUE 'DESCRIPTION'.
           05  FILLER               PIC X(94) VALUE ' COUNT'.
       01  RSN-DETAIL.
           05  RS-RSN               PIC X(2).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  RS-DESC              PIC X(30).
           05  FILLER               PIC X(4)  VALUE SPACES.
           05  RS-COUNT             PIC ZZ,ZZ9.
           05  FILLER               PIC X(88) VALUE SPACES.

       01  SUM-HDR1.
           05  FILLER               PIC X(6)  VALUE 'ZIP5'.
           05  FILLER               PIC X(6)  VALUE 'ROUTE'.
           05  FILLER               PIC X(9)  VALUE '   ADDS'.
           05  FILLER               PIC X(9)  VALUE 'CHANGES'.
           05  FILLER               PIC X(9)  VALUE 'DELETES'.
           05  FILLER               PIC X(9)  VALUE 'SHIFTED'.
           05  FILLER               PIC X(9)  VALUE 'VAL-REJ'.
           05  FILLER               PIC X(9)  VALUE 'UPD-REJ'.
           05  FILLER               PIC X(66) VALUE ' ACTIVE'.
       01  SUM-DETAIL.
           05  SD-ZIP5              PIC X(5).
           05  FILLER               PIC X(1)  VALUE SPACES.
           05  SD-ROUTE             PIC X(4).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-ADDS              PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-CHGS              PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-DELS              PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-SHIFT             PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-VREJ              PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-UREJ              PIC ZZZ,ZZ9.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SD-ACTIVE            PIC ZZZ,ZZ9.
           05  FILLER               PIC X(59) VALUE SPACES.

       01  MSG-LINE.
           05  ML-TEXT              PIC X(60).
           05  ML-COUNT             PIC ZZZ,ZZ9.
           05  FILLER               PIC X(65) VALUE SPACES.

       COPY EBTRANS.
       COPY EBREJ.
       COPY EBERR.
       COPY EBCTLWS.

           EXEC SQL INCLUDE SQLCA END-EXEC.
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
           EXEC SQL INCLUDE EBDBWS END-EXEC.
       01  HV-ZIP5                  PIC X(5).
       01  HV-ROUTE-ID              PIC X(4).
       01  HV-COUNT                 PIC S9(9) COMP-3.
       01  HV-BOOK.
           05  HV-ADDR-ID           PIC S9(18) COMP-3.
           05  HV-DLVY-SEQ          PIC S9(9) COMP-3.
           05  HV-PRIMARY-NBR       PIC X(10).
           05  HV-STREET-NAME       PIC X(28).
           05  HV-UNIT              PIC X(8).
           05  HV-ZIP4              PIC X(4).
       01  HV-UNIT-IND              PIC S9(4) COMP.
       01  HV-ZIP4-IND              PIC S9(4) COMP.
           EXEC SQL END DECLARE SECTION END-EXEC.

      *    ONE ROUTE'S ACTIVE ADDRESSES IN DELIVERY ORDER.
           EXEC SQL
               DECLARE BOOKCUR CURSOR FOR
                SELECT ADDR_ID, DLVY_SEQ, PRIMARY_NBR, STREET_NAME,
                       UNIT, ZIP4
                  FROM AMS_ADDRESS
                 WHERE ZIP5      = :HV-ZIP5
                   AND ROUTE_ID  = :HV-ROUTE-ID
                   AND STATUS_CD = 'A'
                 ORDER BY DLVY_SEQ
           END-EXEC

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-REJECT-SECTION
           PERFORM 3000-LOAD-AUDIT
           PERFORM 4000-SUMMARY-SECTION
           PERFORM 5000-WRITE-EDIT-BOOKS
           PERFORM 6000-TERMINATE
           GOBACK
           .

       1000-INITIALIZE.
           PERFORM 9100-READ-CONTROL-CARDS
           IF CTL-ERROR
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE CTL-RUNDATE TO HT-RUNDATE
           MOVE CTL-MODE    TO HT-MODE
           INITIALIZE WS-RSN-COUNTS
           OPEN OUTPUT EBRPT-FILE EBBOOK-FILE
           IF WS-RPT-FS NOT = '00' OR WS-BOOK-FS NOT = '00'
               DISPLAY 'EBRPT EBR0001E OPEN FAILED EBRPT=' WS-RPT-FS
                       ' EBBOOK=' WS-BOOK-FS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 9800-DB-CONNECT
           .

      *----------------------------------------------------------------*
      * SECTION 1: REJECTED TRANSACTIONS (EBVALID, THEN EBUPDT)        *
      *----------------------------------------------------------------*
       2000-REJECT-SECTION.
           MOVE 'SECTION 1 - REJECTED TRANSACTIONS' TO WS-SECTION-TITLE
           MOVE REJ-HDR1 TO WS-COL-HDR1
           MOVE ALL '-'  TO WS-COL-HDR2
           MOVE 99 TO WS-LINE-CNT

           MOVE 'EBVALID' TO WS-STEP-NAME
           OPEN INPUT EBREJ-FILE
           PERFORM 2050-CHECK-OPEN
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ EBREJ-FILE INTO EB-REJ-REC
                   AT END SET WS-EOF TO TRUE
                   NOT AT END PERFORM 2100-PRINT-REJECT
               END-READ
           END-PERFORM
           CLOSE EBREJ-FILE

           MOVE 'EBUPDT' TO WS-STEP-NAME
           OPEN INPUT EBUREJ-FILE
           PERFORM 2050-CHECK-OPEN
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ EBUREJ-FILE INTO EB-REJ-REC
                   AT END SET WS-EOF TO TRUE
                   NOT AT END PERFORM 2100-PRINT-REJECT
               END-READ
           END-PERFORM
           CLOSE EBUREJ-FILE

           MOVE SPACES TO MSG-LINE
           MOVE 'TOTAL REJECTED BY EBVALID' TO ML-TEXT
           MOVE WS-TOT-VREJ TO ML-COUNT
           MOVE '0' TO WS-ASA
           MOVE MSG-LINE TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE
           MOVE 'TOTAL REJECTED BY EBUPDT' TO ML-TEXT
           MOVE WS-TOT-UREJ TO ML-COUNT
           MOVE MSG-LINE TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE

           PERFORM 2200-REASON-SUMMARY
           .

      *    STATUS 05 = OPTIONAL FILE NOT PRESENT: TREAT AS EMPTY.
       2050-CHECK-OPEN.
           IF WS-IN-FS NOT = '00' AND NOT = '05'
               DISPLAY 'EBRPT EBR0002E ' WS-STEP-NAME
                       ' REJECT FILE OPEN FAILED, STATUS ' WS-IN-FS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           .

       2100-PRINT-REJECT.
           MOVE EBR-TRANS-IMAGE TO EB-TRANS-REC
           MOVE WS-STEP-NAME    TO RD-STEP
           MOVE EBR-REASON-CD   TO RD-RSN
           MOVE 'UNKNOWN REASON CODE' TO RD-DESC
           SET EB-RSN-IX TO 1
           SEARCH EB-REASON-ENTRY
               WHEN EB-RSN-CD(EB-RSN-IX) = EBR-REASON-CD
                   MOVE EB-RSN-TEXT(EB-RSN-IX) TO RD-DESC
                   SET WS-SUB TO EB-RSN-IX
                   ADD 1 TO WS-RSN-CNT(WS-SUB)
           END-SEARCH
           MOVE EBT-ACTION-CD   TO RD-ACT
           MOVE EBT-ZIP5        TO RD-ZIP5
           MOVE EBT-ROUTE-ID    TO RD-ROUTE
      *    NEVER DO ARITHMETIC ON AN UNCHECKED PACKED FIELD (S0C7).
           IF EBT-DLVY-SEQ IS NUMERIC
               MOVE EBT-DLVY-SEQ TO RD-SEQ
           ELSE
               MOVE '*BADPK*' TO RD-SEQ-X
           END-IF
           MOVE EBT-PRIMARY-NBR TO RD-PRIMARY
           MOVE EBT-STREET-NAME TO RD-STREET
           MOVE EBT-UNIT        TO RD-UNIT
           MOVE EBT-CARRIER-ID  TO RD-CARRIER
           MOVE EBT-EDIT-DATE-X TO RD-DATE
      *    MAKE UNPRINTABLE BYTES VISIBLE INSTEAD OF SENDING THEM TO
      *    THE PRINTER.
           INSPECT REJ-DETAIL REPLACING ALL LOW-VALUE  BY '.'
                                        ALL HIGH-VALUE BY '.'
           MOVE ' ' TO WS-ASA
           MOVE REJ-DETAIL TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE

           MOVE EBT-ZIP5     TO WS-FIND-ZIP5
           MOVE EBT-ROUTE-ID TO WS-FIND-ROUTE
           PERFORM 7000-FIND-ROUTE
           IF WS-STEP-NAME = 'EBVALID'
               ADD 1 TO WS-RT-VREJ(WS-SUB) WS-TOT-VREJ
           ELSE
               ADD 1 TO WS-RT-UREJ(WS-SUB) WS-TOT-UREJ
           END-IF
           .

       2200-REASON-SUMMARY.
           MOVE 'SECTION 1 - REJECTS BY REASON CODE'
             TO WS-SECTION-TITLE
           MOVE RSN-HDR1 TO WS-COL-HDR1
           MOVE 99 TO WS-LINE-CNT
           PERFORM VARYING WS-SUB FROM 1 BY 1
                   UNTIL WS-SUB > EB-REASON-COUNT
               IF WS-RSN-CNT(WS-SUB) > ZERO
                   MOVE EB-RSN-CD(WS-SUB)   TO RS-RSN
                   MOVE EB-RSN-TEXT(WS-SUB) TO RS-DESC
                   MOVE WS-RSN-CNT(WS-SUB)  TO RS-COUNT
                   MOVE ' ' TO WS-ASA
                   MOVE RSN-DETAIL TO WS-PRINT-LINE
                   PERFORM 8500-PRINT-LINE
               END-IF
           END-PERFORM
           .

      *----------------------------------------------------------------*
      * ACCUMULATE APPLIED ACTIONS PER ROUTE FROM THE AUDIT FILE       *
      *----------------------------------------------------------------*
       3000-LOAD-AUDIT.
           OPEN INPUT EBAUDIT-FILE
           EVALUATE WS-AUD-FS
               WHEN '00'
                   CONTINUE
               WHEN '05'
                   MOVE 'N' TO WS-UPDATE-RAN-SW
               WHEN OTHER
                   DISPLAY 'EBRPT EBR0003E EBAUDIT OPEN FAILED, STATUS '
                           WS-AUD-FS
                   MOVE 12 TO RETURN-CODE
                   STOP RUN
           END-EVALUATE
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ EBAUDIT-FILE
                   AT END SET WS-EOF TO TRUE
                   NOT AT END PERFORM 3100-ADD-AUDIT
               END-READ
           END-PERFORM
           CLOSE EBAUDIT-FILE
           .

       3100-ADD-AUDIT.
           MOVE EBA-ZIP5     TO WS-FIND-ZIP5
           MOVE EBA-ROUTE-ID TO WS-FIND-ROUTE
           PERFORM 7000-FIND-ROUTE
           EVALUATE EBA-ACTION-CD
               WHEN 'A'
                   ADD 1 TO WS-RT-ADDS(WS-SUB) WS-TOT-ADDS
                   ADD EBA-SHIFT-CNT TO WS-RT-SHIFT(WS-SUB)
                                        WS-TOT-SHIFT
               WHEN 'C'
                   ADD 1 TO WS-RT-CHGS(WS-SUB) WS-TOT-CHGS
               WHEN 'D'
                   ADD 1 TO WS-RT-DELS(WS-SUB) WS-TOT-DELS
           END-EVALUATE
           .

      *----------------------------------------------------------------*
      * SECTION 2: ROUTE SUMMARY WITH CURRENT ACTIVE COUNTS            *
      *----------------------------------------------------------------*
       4000-SUMMARY-SECTION.
           MOVE 'SECTION 2 - ROUTE SUMMARY' TO WS-SECTION-TITLE
           MOVE SUM-HDR1 TO WS-COL-HDR1
           MOVE 99 TO WS-LINE-CNT
           PERFORM VARYING WS-SUB FROM 1 BY 1
                   UNTIL WS-SUB > WS-RT-COUNT
               MOVE WS-RT-ZIP5(WS-SUB)  TO HV-ZIP5
               MOVE WS-RT-ROUTE(WS-SUB) TO HV-ROUTE-ID
               EXEC SQL
                   SELECT COUNT(*)
                     INTO :HV-COUNT
                     FROM AMS_ADDRESS
                    WHERE ZIP5      = :HV-ZIP5
                      AND ROUTE_ID  = :HV-ROUTE-ID
                      AND STATUS_CD = 'A'
               END-EXEC
               IF SQLCODE NOT = 0
                   PERFORM 9900-SQL-ERROR
               END-IF
               MOVE HV-COUNT TO WS-RT-ACTIVE(WS-SUB)
               ADD HV-COUNT  TO WS-TOT-ACTIVE
               MOVE WS-RT-ZIP5(WS-SUB)   TO SD-ZIP5
               MOVE WS-RT-ROUTE(WS-SUB)  TO SD-ROUTE
               MOVE WS-RT-ADDS(WS-SUB)   TO SD-ADDS
               MOVE WS-RT-CHGS(WS-SUB)   TO SD-CHGS
               MOVE WS-RT-DELS(WS-SUB)   TO SD-DELS
               MOVE WS-RT-SHIFT(WS-SUB)  TO SD-SHIFT
               MOVE WS-RT-VREJ(WS-SUB)   TO SD-VREJ
               MOVE WS-RT-UREJ(WS-SUB)   TO SD-UREJ
               MOVE WS-RT-ACTIVE(WS-SUB) TO SD-ACTIVE
               INSPECT SUM-DETAIL REPLACING ALL LOW-VALUE  BY '.'
                                            ALL HIGH-VALUE BY '.'
               MOVE ' ' TO WS-ASA
               MOVE SUM-DETAIL TO WS-PRINT-LINE
               PERFORM 8500-PRINT-LINE
           END-PERFORM

           MOVE 'TOTAL'       TO SD-ZIP5
           MOVE SPACES        TO SD-ROUTE
           MOVE WS-TOT-ADDS   TO SD-ADDS
           MOVE WS-TOT-CHGS   TO SD-CHGS
           MOVE WS-TOT-DELS   TO SD-DELS
           MOVE WS-TOT-SHIFT  TO SD-SHIFT
           MOVE WS-TOT-VREJ   TO SD-VREJ
           MOVE WS-TOT-UREJ   TO SD-UREJ
           MOVE WS-TOT-ACTIVE TO SD-ACTIVE
           MOVE '0' TO WS-ASA
           MOVE SUM-DETAIL TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE

           MOVE SPACES TO MSG-LINE
           EVALUATE TRUE
               WHEN NOT WS-UPDATE-RAN
                   MOVE
                     '*** EBUPDT DID NOT RUN - NO CHANGES APPLIED ***'
                     TO ML-TEXT
               WHEN CTL-MODE-VALIDATE
                   MOVE
                     '*** MODE=VALIDATE - ALL CHANGES ROLLED BACK ***'
                     TO ML-TEXT
               WHEN OTHER
                   MOVE '*** CHANGES COMMITTED TO AMS ***' TO ML-TEXT
           END-EVALUATE
           MOVE '0' TO WS-ASA
           MOVE MSG-LINE TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE
           .

      *----------------------------------------------------------------*
      * EBBOOK: ACTIVE ADDRESSES OF EVERY ROUTE WITH AN APPLIED CHANGE *
      *----------------------------------------------------------------*
       5000-WRITE-EDIT-BOOKS.
           PERFORM VARYING WS-SUB FROM 1 BY 1
                   UNTIL WS-SUB > WS-RT-COUNT
               IF WS-RT-ADDS(WS-SUB) + WS-RT-CHGS(WS-SUB)
                  + WS-RT-DELS(WS-SUB) > ZERO
                   MOVE WS-RT-ZIP5(WS-SUB)  TO HV-ZIP5
                   MOVE WS-RT-ROUTE(WS-SUB) TO HV-ROUTE-ID
                   PERFORM 5100-WRITE-ONE-BOOK
                   ADD 1 TO WS-BOOK-ROUTES
               END-IF
           END-PERFORM
           MOVE SPACES TO MSG-LINE
           MOVE 'EDIT BOOKS WRITTEN TO EBBOOK (ROUTES)' TO ML-TEXT
           MOVE WS-BOOK-ROUTES TO ML-COUNT
           MOVE '0' TO WS-ASA
           MOVE MSG-LINE TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE
           MOVE 'EDIT BOOK ADDRESS LINES' TO ML-TEXT
           MOVE WS-BOOK-RECS TO ML-COUNT
           MOVE ' ' TO WS-ASA
           MOVE MSG-LINE TO WS-PRINT-LINE
           PERFORM 8500-PRINT-LINE
           .

       5100-WRITE-ONE-BOOK.
           EXEC SQL OPEN BOOKCUR END-EXEC
           IF SQLCODE NOT = 0
               PERFORM 9900-SQL-ERROR
           END-IF
           PERFORM 5200-FETCH-BOOK
           PERFORM UNTIL SQLCODE = 100
               MOVE HV-ZIP5        TO EBB-ZIP5
               MOVE HV-ROUTE-ID    TO EBB-ROUTE-ID
               MOVE HV-DLVY-SEQ    TO EBB-DLVY-SEQ
               MOVE HV-PRIMARY-NBR TO EBB-PRIMARY-NBR
               MOVE HV-STREET-NAME TO EBB-STREET-NAME
               MOVE HV-UNIT        TO EBB-UNIT
               MOVE HV-ZIP4        TO EBB-ZIP4
               MOVE HV-ADDR-ID     TO EBB-ADDR-ID
               WRITE EB-BOOK-REC
               ADD 1 TO WS-BOOK-RECS
               PERFORM 5200-FETCH-BOOK
           END-PERFORM
           EXEC SQL CLOSE BOOKCUR END-EXEC
           .

       5200-FETCH-BOOK.
           EXEC SQL
               FETCH BOOKCUR
                INTO :HV-ADDR-ID, :HV-DLVY-SEQ, :HV-PRIMARY-NBR,
                     :HV-STREET-NAME, :HV-UNIT:HV-UNIT-IND,
                     :HV-ZIP4:HV-ZIP4-IND
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
                   CONTINUE
               WHEN OTHER
                   PERFORM 9900-SQL-ERROR
           END-EVALUATE
           .

       6000-TERMINATE.
           CLOSE EBRPT-FILE EBBOOK-FILE
           PERFORM 9810-DB-DISCONNECT
           DISPLAY 'EBRPT PAGES WRITTEN ' WS-PAGE-CNT
           MOVE 0 TO RETURN-CODE
           .

      *----------------------------------------------------------------*
      * ROUTE TABLE: FIND WS-FIND-KEY, INSERTING IT IN KEY ORDER IF    *
      * IT IS NEW. RETURNS ITS SUBSCRIPT IN WS-SUB.                    *
      *----------------------------------------------------------------*
       7000-FIND-ROUTE.
           MOVE 1 TO WS-SUB
           PERFORM UNTIL WS-SUB > WS-RT-COUNT
               IF WS-RT-KEY(WS-SUB) >= WS-FIND-KEY
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-SUB
           END-PERFORM
           IF WS-SUB <= WS-RT-COUNT
               IF WS-RT-KEY(WS-SUB) = WS-FIND-KEY
                   EXIT PARAGRAPH
               END-IF
           END-IF
           IF WS-RT-COUNT >= WS-RT-MAX
               DISPLAY 'EBRPT EBR0004E ROUTE TABLE FULL AT '
                       WS-RT-MAX ' ENTRIES'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           ADD 1 TO WS-RT-COUNT
           PERFORM VARYING WS-SUB2 FROM WS-RT-COUNT BY -1
                   UNTIL WS-SUB2 <= WS-SUB
               MOVE WS-RT-ENTRY(WS-SUB2 - 1) TO WS-RT-ENTRY(WS-SUB2)
           END-PERFORM
           INITIALIZE WS-RT-ENTRY(WS-SUB)
           MOVE WS-FIND-KEY TO WS-RT-KEY(WS-SUB)
           .

      *----------------------------------------------------------------*
      * PRINTING: ASA '1' NEW PAGE, ' ' SINGLE, '0' DOUBLE SPACE       *
      *----------------------------------------------------------------*
       8500-PRINT-LINE.
           IF WS-LINE-CNT >= WS-LINES-PER-PAGE
               PERFORM 8600-PAGE-HEADINGS
           END-IF
           MOVE WS-ASA        TO RPT-ASA
           MOVE WS-PRINT-LINE TO RPT-LINE
           WRITE EBRPT-REC
           IF WS-ASA = '0'
               ADD 2 TO WS-LINE-CNT
           ELSE
               ADD 1 TO WS-LINE-CNT
           END-IF
           .

       8600-PAGE-HEADINGS.
           ADD 1 TO WS-PAGE-CNT
           MOVE WS-PAGE-CNT TO HT-PAGE
           MOVE '1'       TO RPT-ASA
           MOVE HDR-TITLE TO RPT-LINE
           WRITE EBRPT-REC
           MOVE ' ' TO RPT-ASA
           MOVE WS-SECTION-TITLE TO RPT-LINE
           WRITE EBRPT-REC
           MOVE '0' TO RPT-ASA
           MOVE WS-COL-HDR1 TO RPT-LINE
           WRITE EBRPT-REC
           MOVE ' ' TO RPT-ASA
           MOVE WS-COL-HDR2 TO RPT-LINE
           WRITE EBRPT-REC
           MOVE 5 TO WS-LINE-CNT
           .

       COPY EBCTLRD.
           EXEC SQL INCLUDE EBDBPD END-EXEC.
