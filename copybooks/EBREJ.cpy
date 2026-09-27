      *================================================================*
      * EBREJ    - REJECTED TRANSACTION                   LRECL=82 FB  *
      *            ORIGINAL EBTRANS IMAGE + 2-BYTE REASON CODE.        *
      *            WRITTEN BY EBVALID (EBREJ) AND EBUPDT (EBUREJ).     *
      *================================================================*
       01  EB-REJ-REC.
           05  EBR-TRANS-IMAGE      PIC X(80).
           05  EBR-REASON-CD        PIC X(2).
