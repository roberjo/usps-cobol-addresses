       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBSORT.
      *================================================================*
      * EBSORT   - EBUPD01 STEP020: SORT VALIDATED TRANSACTIONS.       *
      *                                                                *
      * ORDER    ZIP5 ASC, ROUTE ASC, DELIVERY SEQ DESC, ACTION DESC   *
      *                                                                *
      * EBUPDT WORKS EACH ROUTE FROM THE HIGHEST SEQUENCE DOWN. AN ADD *
      * THAT RESEQUENCES A ROUTE ONLY MOVES POSITIONS ABOVE ITSELF,    *
      * WHICH ARE ALREADY DONE, SO EVERY SEQUENCE NUMBER IN THE FILE   *
      * STILL MEANS THE POSITION THE CARRIER SAW IN THE PRINTED BOOK.  *
      * ACTION DESC GIVES D BEFORE C BEFORE A AT THE SAME SEQUENCE, SO *
      * A DELETE FREES A POSITION BEFORE AN ADD REUSES IT.             *
      *                                                                *
      * DFSORT EQUIVALENT (JCL/EBUPD01.JCL):                           *
      *   SORT FIELDS=(2,5,CH,A,7,4,CH,A,11,4,PD,D,1,1,CH,D),EQUALS    *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EBVALOUT-FILE ASSIGN TO EBVALOUT
               ORGANIZATION IS SEQUENTIAL.
           SELECT EBSRTOUT-FILE ASSIGN TO EBSRTOUT
               ORGANIZATION IS SEQUENTIAL.
           SELECT SORT-WORK     ASSIGN TO SORTWK01.

       DATA DIVISION.
       FILE SECTION.
       FD  EBVALOUT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01  EBVALOUT-REC             PIC X(80).
       FD  EBSRTOUT-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01  EBSRTOUT-REC             PIC X(80).
       SD  SORT-WORK.
       01  SRT-REC.
           05  SRT-ACTION-CD        PIC X(1).
           05  SRT-ZIP5             PIC X(5).
           05  SRT-ROUTE-ID         PIC X(4).
           05  SRT-DLVY-SEQ         PIC S9(7) COMP-3.
           05  FILLER               PIC X(66).

       WORKING-STORAGE SECTION.
       01  WS-SORT-RC               PIC -(4)9.

       PROCEDURE DIVISION.
       0000-MAIN.
           SORT SORT-WORK
               ON ASCENDING  KEY SRT-ZIP5 SRT-ROUTE-ID
               ON DESCENDING KEY SRT-DLVY-SEQ SRT-ACTION-CD
               WITH DUPLICATES IN ORDER
               USING  EBVALOUT-FILE
               GIVING EBSRTOUT-FILE
           IF SORT-RETURN NOT = ZERO
               MOVE SORT-RETURN TO WS-SORT-RC
               DISPLAY 'EBSORT EBS0001E SORT FAILED, SORT-RETURN='
                       WS-SORT-RC
               MOVE 12 TO RETURN-CODE
           ELSE
               DISPLAY 'EBSORT SORT COMPLETE'
               MOVE 0 TO RETURN-CODE
           END-IF
           GOBACK
           .
