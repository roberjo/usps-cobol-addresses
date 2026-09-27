      *================================================================*
      * EBAUDIT  - BEFORE/AFTER IMAGE OF EACH APPLIED ACTION LRECL=150 *
      *            BEFORE IS SPACES FOR AN ADD.                        *
      *================================================================*
       01  EB-AUDIT-REC.
           05  EBA-ACTION-CD        PIC X(1).
           05  EBA-ZIP5             PIC X(5).
           05  EBA-ROUTE-ID         PIC X(4).
           05  EBA-DLVY-SEQ         PIC 9(7).
           05  EBA-ADDR-ID          PIC 9(10).
           05  EBA-SHIFT-CNT        PIC 9(5).
           05  EBA-BEFORE.
               10  EBA-B-PRIMARY-NBR PIC X(10).
               10  EBA-B-STREET-NAME PIC X(28).
               10  EBA-B-UNIT        PIC X(8).
               10  EBA-B-ZIP4        PIC X(4).
               10  EBA-B-STATUS-CD   PIC X(1).
           05  EBA-AFTER.
               10  EBA-A-PRIMARY-NBR PIC X(10).
               10  EBA-A-STREET-NAME PIC X(28).
               10  EBA-A-UNIT        PIC X(8).
               10  EBA-A-ZIP4        PIC X(4).
               10  EBA-A-STATUS-CD   PIC X(1).
           05  EBA-RUN-DATE         PIC 9(8).
           05  FILLER               PIC X(8).
