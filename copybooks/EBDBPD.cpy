      *================================================================*
      * EBDBPD   - CONNECT / DISCONNECT / SQL ERROR PARAGRAPHS.        *
      *            CALLER DEFINES WS-PGM-ID PIC X(8) AND SETS          *
      *            RETURN-CODE. ENV: EBDB_DSN, EBDB_AUTH (USER.PASS).  *
      *================================================================*
       9800-DB-CONNECT.
           ACCEPT EB-DB-DSN  FROM ENVIRONMENT 'EBDB_DSN'
           ACCEPT EB-DB-AUTH FROM ENVIRONMENT 'EBDB_AUTH'
           IF EB-DB-DSN = SPACES
               DISPLAY WS-PGM-ID ' EBDB01E EBDB_DSN IS NOT SET'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           EXEC SQL
               CONNECT TO :EB-DB-DSN USER :EB-DB-AUTH
           END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY WS-PGM-ID ' EBDB02E CONNECT FAILED'
               PERFORM 9900-SQL-ERROR
           END-IF
           .

       9810-DB-DISCONNECT.
           EXEC SQL
               CONNECT RESET
           END-EXEC
           .

       9900-SQL-ERROR.
           DISPLAY WS-PGM-ID ' EBDB99E UNEXPECTED SQLCODE ' SQLCODE
                   ' SQLSTATE ' SQLSTATE
           DISPLAY WS-PGM-ID ' EBDB99E ' SQLERRMC
           EXEC SQL
               ROLLBACK
           END-EXEC
           MOVE 12 TO RETURN-CODE
           STOP RUN
           .
