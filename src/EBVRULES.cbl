       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBVRULES.
      *================================================================*
      * EBVRULES - FIELD EDITS FOR ONE EBTRANS RECORD.                 *
      *            NO FILE OR DATABASE ACCESS, SO THE RULES CAN BE     *
      *            UNIT TESTED IN ISOLATION (TESTS/UNIT).              *
      *                                                                *
      * CALL 'EBVRULES' USING EB-TRANS-REC  RUNDATE  REASON-CD         *
      *      REASON-CD RETURNS '00' WHEN THE RECORD PASSES, ELSE THE   *
      *      FIRST FAILING REASON (SEE COPYBOOK EBERR).                *
      *                                                                *
      * ROUTE EXISTENCE (07) NEEDS DB2 AND IS CHECKED BY EBVALID.      *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-BAD-CHAR-CNT          PIC S9(4) COMP.
       LINKAGE SECTION.
       COPY EBTRANS.
       01  LK-RUNDATE               PIC 9(8).
       01  LK-REASON-CD             PIC X(2).

       PROCEDURE DIVISION USING EB-TRANS-REC LK-RUNDATE LK-REASON-CD.
       0000-MAIN.
           MOVE '00' TO LK-REASON-CD
           PERFORM 1000-EDIT-ACTION
           IF LK-REASON-CD = '00'
               PERFORM 2000-EDIT-ZIP
           END-IF
           IF LK-REASON-CD = '00'
               PERFORM 3000-EDIT-TEXT-CHARS
           END-IF
           IF LK-REASON-CD = '00'
               PERFORM 4000-EDIT-REQUIRED
           END-IF
           IF LK-REASON-CD = '00'
               PERFORM 5000-EDIT-DATE
           END-IF
           IF LK-REASON-CD = '00'
               PERFORM 6000-EDIT-SEQUENCE
           END-IF
           GOBACK
           .

       1000-EDIT-ACTION.
           IF NOT EBT-VALID-ACTION
               MOVE '01' TO LK-REASON-CD
           END-IF
           .

       2000-EDIT-ZIP.
           IF EBT-ZIP5 IS NOT NUMERIC
               MOVE '02' TO LK-REASON-CD
           ELSE
               IF EBT-ZIP4 NOT = SPACES AND EBT-ZIP4 IS NOT NUMERIC
                   MOVE '03' TO LK-REASON-CD
               END-IF
           END-IF
           .

      *    LOW-VALUES / HIGH-VALUES USUALLY MEAN AN UNINITIALISED
      *    FIELD UPSTREAM. REJECT THEM RATHER THAN STORE THEM.
       3000-EDIT-TEXT-CHARS.
           MOVE ZERO TO WS-BAD-CHAR-CNT
           INSPECT EBT-ROUTE-ID TALLYING WS-BAD-CHAR-CNT
               FOR ALL LOW-VALUE ALL HIGH-VALUE
           INSPECT EBT-PRIMARY-NBR TALLYING WS-BAD-CHAR-CNT
               FOR ALL LOW-VALUE ALL HIGH-VALUE
           INSPECT EBT-STREET-NAME TALLYING WS-BAD-CHAR-CNT
               FOR ALL LOW-VALUE ALL HIGH-VALUE
           INSPECT EBT-UNIT TALLYING WS-BAD-CHAR-CNT
               FOR ALL LOW-VALUE ALL HIGH-VALUE
           INSPECT EBT-CARRIER-ID TALLYING WS-BAD-CHAR-CNT
               FOR ALL LOW-VALUE ALL HIGH-VALUE
           IF WS-BAD-CHAR-CNT > ZERO
               MOVE '09' TO LK-REASON-CD
           END-IF
           .

      *    EVERY ACTION NEEDS ROUTE, PRIMARY NUMBER AND CARRIER.
      *    ADD AND CHANGE ALSO NEED THE STREET NAME.
       4000-EDIT-REQUIRED.
           IF EBT-ROUTE-ID = SPACES
              OR EBT-PRIMARY-NBR = SPACES
              OR EBT-CARRIER-ID = SPACES
               MOVE '04' TO LK-REASON-CD
           END-IF
           IF (EBT-ADD OR EBT-CHANGE) AND EBT-STREET-NAME = SPACES
               MOVE '04' TO LK-REASON-CD
           END-IF
           .

       5000-EDIT-DATE.
           IF EBT-EDIT-DATE IS NOT NUMERIC
               MOVE '05' TO LK-REASON-CD
           ELSE
               IF FUNCTION TEST-DATE-YYYYMMDD(EBT-EDIT-DATE) NOT = 0
                   MOVE '05' TO LK-REASON-CD
               ELSE
                   IF EBT-EDIT-DATE > LK-RUNDATE
                       MOVE '06' TO LK-REASON-CD
                   END-IF
               END-IF
           END-IF
           .

      *    TEST NUMERIC BEFORE ANY ARITHMETIC: A BAD PACKED FIELD IS
      *    AN S0C7 DATA EXCEPTION ON Z/OS.
       6000-EDIT-SEQUENCE.
           IF EBT-DLVY-SEQ IS NOT NUMERIC
               MOVE '08' TO LK-REASON-CD
           ELSE
               IF EBT-DLVY-SEQ NOT > ZERO
                   MOVE '08' TO LK-REASON-CD
               END-IF
           END-IF
           .
