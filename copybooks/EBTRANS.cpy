      *================================================================*
      * EBTRANS  - EDIT BOOK TRANSACTION RECORD           LRECL=80 FB  *
      *            ONE CARRIER ANNOTATION (ADD / CHANGE / DELETE).     *
      *            LAYOUT IS DOCUMENTED IN DOCS/ICD-EBTRANS.MD.        *
      *================================================================*
       01  EB-TRANS-REC.
           05  EBT-ACTION-CD        PIC X(1).
               88  EBT-ADD          VALUE 'A'.
               88  EBT-CHANGE       VALUE 'C'.
               88  EBT-DELETE       VALUE 'D'.
               88  EBT-VALID-ACTION VALUE 'A' 'C' 'D'.
           05  EBT-ZIP5             PIC X(5).
           05  EBT-ROUTE-ID         PIC X(4).
           05  EBT-DLVY-SEQ         PIC S9(7) COMP-3.
           05  EBT-PRIMARY-NBR      PIC X(10).
           05  EBT-STREET-NAME      PIC X(28).
           05  EBT-UNIT             PIC X(8).
           05  EBT-ZIP4             PIC X(4).
           05  EBT-CARRIER-ID       PIC X(6).
           05  EBT-EDIT-DATE        PIC 9(8).
           05  EBT-EDIT-DATE-X      REDEFINES EBT-EDIT-DATE
                                    PIC X(8).
           05  FILLER               PIC X(2).
