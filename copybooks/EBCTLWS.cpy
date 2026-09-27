      *================================================================*
      * EBCTLWS  - SYSIN CONTROL CARD VALUES (KEYWORD=VALUE CARDS)     *
      *            PAIRED WITH EBCTLRD (PROCEDURE DIVISION).           *
      *================================================================*
       01  EB-CONTROL.
           05  CTL-RUNDATE          PIC 9(8)  VALUE ZERO.
           05  CTL-MODE             PIC X(8)  VALUE 'UPDATE'.
               88  CTL-MODE-UPDATE            VALUE 'UPDATE'.
               88  CTL-MODE-VALIDATE          VALUE 'VALIDATE'.
           05  CTL-COMMIT           PIC 9(5)  VALUE 500.
           05  CTL-REJMAX           PIC 9(3)  VALUE 10.
           05  CTL-RESTART          PIC X(1)  VALUE 'N'.
               88  CTL-RESTART-YES            VALUE 'Y'.
       01  CTL-WORK.
           05  CTL-SYSIN-FS         PIC X(2).
           05  CTL-EOF-SW           PIC X(1)  VALUE 'N'.
               88  CTL-EOF                    VALUE 'Y'.
           05  CTL-ERROR-SW         PIC X(1)  VALUE 'N'.
               88  CTL-ERROR                  VALUE 'Y'.
           05  CTL-KEY              PIC X(20).
           05  CTL-VALUE            PIC X(20).
