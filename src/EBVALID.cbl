       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBVALID.
      *================================================================*
      * EBVALID  - EBUPD01 STEP010: VALIDATE EDIT BOOK TRANSACTIONS.   *
      *                                                                *
      * INPUT    SYSIN     CONTROL CARDS (RUNDATE, REJMAX)             *
      *          EBTRANS   EDIT TRANSACTIONS            LRECL=80       *
      *          AMS_ROUTE ROUTE MASTER (SINGLETON SELECT)             *
      * OUTPUT   EBVALOUT  TRANSACTIONS THAT PASSED     LRECL=80       *
      *          EBREJ     REJECTS + REASON CODE        LRECL=82       *
      *                                                                *
      * RC  0  ALL RECORDS PASSED                                      *
      *     4  SOME REJECTS, REJECT RATE <= REJMAX PERCENT             *
      *     8  REJECT RATE > REJMAX: LATER STEPS ARE BYPASSED, SO      *
      *        NOTHING IS APPLIED TO AMS                               *
      *    12  BAD CONTROL CARD, FILE ERROR OR UNEXPECTED SQLCODE      *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE    ASSIGN TO SYSIN
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS CTL-SYSIN-FS.
           SELECT EBTRANS-FILE  ASSIGN TO EBTRANS
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TRANS-FS.
           SELECT EBVALOUT-FILE ASSIGN TO EBVALOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-VALOUT-FS.
           SELECT EBREJ-FILE    ASSIGN TO EBREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-REJ-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                PIC X(80).
       FD  EBTRANS-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01  EBTRANS-IN               PIC X(80).
       FD  EBVALOUT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01  EBVALOUT-REC             PIC X(80).
       FD  EBREJ-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 82 CHARACTERS.
       COPY EBREJ.

       WORKING-STORAGE SECTION.
       01  WS-PGM-ID                PIC X(8)  VALUE 'EBVALID'.
       01  WS-FILE-STATUS.
           05  WS-TRANS-FS          PIC X(2).
           05  WS-VALOUT-FS         PIC X(2).
           05  WS-REJ-FS            PIC X(2).
       01  WS-SWITCHES.
           05  WS-EOF-SW            PIC X(1)  VALUE 'N'.
               88  WS-EOF                     VALUE 'Y'.
       01  WS-COUNTERS.
           05  WS-READ-CNT          PIC S9(9) COMP-3 VALUE ZERO.
           05  WS-PASS-CNT          PIC S9(9) COMP-3 VALUE ZERO.
           05  WS-REJ-CNT           PIC S9(9) COMP-3 VALUE ZERO.
           05  WS-REJ-PCT           PIC S9(3)V99 COMP-3 VALUE ZERO.
       01  WS-REASON-CD             PIC X(2).
       01  WS-DISPLAY-CNT           PIC ZZZ,ZZZ,ZZ9.
       01  WS-DISPLAY-PCT           PIC ZZ9.99.
       01  WS-DISPLAY-SQLCODE       PIC -(9)9.

       COPY EBTRANS.
       COPY EBCTLWS.

           EXEC SQL INCLUDE SQLCA END-EXEC.
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
           EXEC SQL INCLUDE EBDBWS END-EXEC.
       01  HV-ZIP5                  PIC X(5).
       01  HV-ROUTE-ID              PIC X(4).
       01  HV-ROUTE-TYPE            PIC X(1).
           EXEC SQL END DECLARE SECTION END-EXEC.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-TRANS UNTIL WS-EOF
           PERFORM 3000-TERMINATE
           GOBACK
           .

       1000-INITIALIZE.
           PERFORM 9100-READ-CONTROL-CARDS
           IF CTL-ERROR
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           DISPLAY 'EBVALID RUNDATE=' CTL-RUNDATE ' REJMAX='
                   CTL-REJMAX '%'
           OPEN INPUT  EBTRANS-FILE
                OUTPUT EBVALOUT-FILE
                       EBREJ-FILE
           IF WS-TRANS-FS NOT = '00' OR WS-VALOUT-FS NOT = '00'
              OR WS-REJ-FS NOT = '00'
               DISPLAY 'EBVALID EBV0001E OPEN FAILED EBTRANS='
                       WS-TRANS-FS ' EBVALOUT=' WS-VALOUT-FS
                       ' EBREJ=' WS-REJ-FS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 9800-DB-CONNECT
           PERFORM 8000-READ-TRANS
           .

       2000-PROCESS-TRANS.
           MOVE EBTRANS-IN TO EB-TRANS-REC
           CALL 'EBVRULES' USING EB-TRANS-REC CTL-RUNDATE WS-REASON-CD
           IF WS-REASON-CD = '00'
               PERFORM 2100-CHECK-ROUTE
           END-IF
           IF WS-REASON-CD = '00'
               WRITE EBVALOUT-REC FROM EB-TRANS-REC
               ADD 1 TO WS-PASS-CNT
           ELSE
               MOVE EB-TRANS-REC  TO EBR-TRANS-IMAGE
               MOVE WS-REASON-CD  TO EBR-REASON-CD
               WRITE EB-REJ-REC
               ADD 1 TO WS-REJ-CNT
           END-IF
           PERFORM 8000-READ-TRANS
           .

       2100-CHECK-ROUTE.
           MOVE EBT-ZIP5     TO HV-ZIP5
           MOVE EBT-ROUTE-ID TO HV-ROUTE-ID
           EXEC SQL
               SELECT ROUTE_TYPE
                 INTO :HV-ROUTE-TYPE
                 FROM AMS_ROUTE
                WHERE ZIP5     = :HV-ZIP5
                  AND ROUTE_ID = :HV-ROUTE-ID
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   CONTINUE
               WHEN 100
                   MOVE '07' TO WS-REASON-CD
               WHEN OTHER
                   PERFORM 9900-SQL-ERROR
           END-EVALUATE
           .

       3000-TERMINATE.
           CLOSE EBTRANS-FILE EBVALOUT-FILE EBREJ-FILE
           PERFORM 9810-DB-DISCONNECT
           IF WS-READ-CNT > ZERO
               COMPUTE WS-REJ-PCT ROUNDED =
                   WS-REJ-CNT * 100 / WS-READ-CNT
           END-IF
           MOVE WS-READ-CNT TO WS-DISPLAY-CNT
           DISPLAY 'EBVALID RECORDS READ     ' WS-DISPLAY-CNT
           MOVE WS-PASS-CNT TO WS-DISPLAY-CNT
           DISPLAY 'EBVALID RECORDS PASSED   ' WS-DISPLAY-CNT
           MOVE WS-REJ-CNT  TO WS-DISPLAY-CNT
           MOVE WS-REJ-PCT  TO WS-DISPLAY-PCT
           DISPLAY 'EBVALID RECORDS REJECTED ' WS-DISPLAY-CNT
                   ' (' WS-DISPLAY-PCT '%)'
           EVALUATE TRUE
               WHEN WS-REJ-PCT > CTL-REJMAX
                   DISPLAY 'EBVALID EBV0008E REJECT RATE EXCEEDS REJMAX'
                           ' - UPDATE WILL NOT RUN'
                   MOVE 8 TO RETURN-CODE
               WHEN WS-REJ-CNT > ZERO
                   MOVE 4 TO RETURN-CODE
               WHEN OTHER
                   MOVE 0 TO RETURN-CODE
           END-EVALUATE
           .

       8000-READ-TRANS.
           READ EBTRANS-FILE
               AT END
                   SET WS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-READ-CNT
           END-READ
           IF WS-TRANS-FS NOT = '00' AND NOT = '10'
               DISPLAY 'EBVALID EBV0002E EBTRANS READ ERROR, STATUS '
                       WS-TRANS-FS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           .

       COPY EBCTLRD.
           EXEC SQL INCLUDE EBDBPD END-EXEC.
