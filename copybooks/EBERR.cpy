      *================================================================*
      * EBERR    - REJECT REASON CODES AND DESCRIPTIONS               *
      *            01-09 ARE SET BY EBVALID, 10-12 BY EBUPDT.          *
      *================================================================*
       01  EB-REASON-VALUES.
           05  FILLER  PIC X(32) VALUE '01INVALID ACTION CODE'.
           05  FILLER  PIC X(32) VALUE '02ZIP5 NOT NUMERIC'.
           05  FILLER  PIC X(32) VALUE '03ZIP4 NOT NUMERIC'.
           05  FILLER  PIC X(32) VALUE '04REQUIRED FIELD MISSING'.
           05  FILLER  PIC X(32) VALUE '05EDIT DATE INVALID'.
           05  FILLER  PIC X(32) VALUE '06EDIT DATE AFTER RUN DATE'.
           05  FILLER  PIC X(32) VALUE '07ROUTE NOT ON AMS_ROUTE'.
           05  FILLER  PIC X(32) VALUE '08DELIVERY SEQUENCE INVALID'.
           05  FILLER  PIC X(32) VALUE '09LOW/HIGH-VALUES IN TEXT'.
           05  FILLER  PIC X(32) VALUE '10ADDRESS NOT FOUND AT SEQ'.
           05  FILLER  PIC X(32) VALUE '11DUPLICATE ACTIVE ADDRESS'.
           05  FILLER  PIC X(32) VALUE '12ADDRESS MISMATCH AT SEQ'.
       01  EB-REASON-TABLE REDEFINES EB-REASON-VALUES.
           05  EB-REASON-ENTRY      OCCURS 12 TIMES
                                    INDEXED BY EB-RSN-IX.
               10  EB-RSN-CD        PIC X(2).
               10  EB-RSN-TEXT      PIC X(30).
       01  EB-REASON-COUNT          PIC S9(4) COMP VALUE 12.
