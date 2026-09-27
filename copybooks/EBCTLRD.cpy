      *================================================================*
      * EBCTLRD  - READ AND EDIT THE SYSIN CONTROL CARDS.              *
      *            CALLER NEEDS: FD SYSIN-FILE / 01 SYSIN-REC X(80),   *
      *            COPY EBCTLWS. SETS CTL-ERROR ON ANY BAD CARD.       *
      *================================================================*
       9100-READ-CONTROL-CARDS.
           OPEN INPUT SYSIN-FILE
           IF CTL-SYSIN-FS NOT = '00'
               DISPLAY 'EBCTL01E SYSIN OPEN FAILED, STATUS '
                       CTL-SYSIN-FS
               SET CTL-ERROR TO TRUE
           ELSE
               PERFORM UNTIL CTL-EOF
                   READ SYSIN-FILE
                       AT END SET CTL-EOF TO TRUE
                       NOT AT END PERFORM 9110-EDIT-CARD
                   END-READ
               END-PERFORM
               CLOSE SYSIN-FILE
           END-IF
           IF CTL-RUNDATE = ZERO
               DISPLAY 'EBCTL02E RUNDATE CARD IS REQUIRED'
               SET CTL-ERROR TO TRUE
           END-IF
           .

       9110-EDIT-CARD.
           IF SYSIN-REC(1:1) = '*' OR SYSIN-REC = SPACES
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO CTL-KEY CTL-VALUE
           UNSTRING SYSIN-REC DELIMITED BY '=' OR ' '
               INTO CTL-KEY CTL-VALUE
           END-UNSTRING
           EVALUATE CTL-KEY
               WHEN 'RUNDATE'
                   IF CTL-VALUE(1:8) IS NUMERIC
                      AND CTL-VALUE(9:) = SPACES
                      AND FUNCTION TEST-DATE-YYYYMMDD
                          (FUNCTION NUMVAL(CTL-VALUE(1:8))) = 0
                       MOVE CTL-VALUE(1:8) TO CTL-RUNDATE
                   ELSE
                       PERFORM 9190-BAD-CARD
                   END-IF
               WHEN 'MODE'
                   MOVE CTL-VALUE TO CTL-MODE
                   IF NOT CTL-MODE-UPDATE AND NOT CTL-MODE-VALIDATE
                       PERFORM 9190-BAD-CARD
                   END-IF
               WHEN 'COMMIT'
                   IF FUNCTION TEST-NUMVAL(CTL-VALUE) = 0
                      AND FUNCTION NUMVAL(CTL-VALUE) > 0
                      AND FUNCTION NUMVAL(CTL-VALUE) < 100000
                       COMPUTE CTL-COMMIT = FUNCTION NUMVAL(CTL-VALUE)
                   ELSE
                       PERFORM 9190-BAD-CARD
                   END-IF
               WHEN 'REJMAX'
                   IF FUNCTION TEST-NUMVAL(CTL-VALUE) = 0
                      AND FUNCTION NUMVAL(CTL-VALUE) >= 0
                      AND FUNCTION NUMVAL(CTL-VALUE) <= 100
                       COMPUTE CTL-REJMAX = FUNCTION NUMVAL(CTL-VALUE)
                   ELSE
                       PERFORM 9190-BAD-CARD
                   END-IF
               WHEN 'RESTART'
                   IF CTL-VALUE = 'Y' OR 'N'
                       MOVE CTL-VALUE TO CTL-RESTART
                   ELSE
                       PERFORM 9190-BAD-CARD
                   END-IF
               WHEN OTHER
                   PERFORM 9190-BAD-CARD
           END-EVALUATE
           .

       9190-BAD-CARD.
           DISPLAY 'EBCTL03E INVALID CONTROL CARD: ' SYSIN-REC(1:40)
           SET CTL-ERROR TO TRUE
           .
