      *================================================================*
      * EBBOOK   - EDIT BOOK EXTRACT: ACTIVE ADDRESSES OF EACH ROUTE   *
      *            TOUCHED BY THIS RUN, IN DELIVERY ORDER. LRECL=80    *
      *================================================================*
       01  EB-BOOK-REC.
           05  EBB-ZIP5             PIC X(5).
           05  EBB-ROUTE-ID         PIC X(4).
           05  EBB-DLVY-SEQ         PIC 9(7).
           05  EBB-PRIMARY-NBR      PIC X(10).
           05  EBB-STREET-NAME      PIC X(28).
           05  EBB-UNIT             PIC X(8).
           05  EBB-ZIP4             PIC X(4).
           05  EBB-ADDR-ID          PIC 9(10).
           05  FILLER               PIC X(4).
