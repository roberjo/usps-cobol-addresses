      *================================================================*
      * EBDBWS   - DATABASE CONNECTION FIELDS. COPY INSIDE THE         *
      *            EXEC SQL BEGIN/END DECLARE SECTION.                 *
      *            ON Z/OS THE PLAN IS BOUND AND DB2 IS ATTACHED BY    *
      *            THE JCL (IKJEFT01 / DSN RUN), SO NO CONNECT IS      *
      *            CODED. LOCALLY GIXSQL NEEDS AN EXPLICIT CONNECT.    *
      *================================================================*
       01  EB-DB-DSN                PIC X(100).
       01  EB-DB-AUTH               PIC X(60).
