#!/bin/sh
# Called by cobol-check with the generated test program: compile it with the
# project's copybooks and dialect, then run it.
#
# cobol-check runs the program under test as a main program, but EBVRULES is
# a called subprogram. Folding its LINKAGE SECTION into WORKING-STORAGE and
# dropping PROCEDURE DIVISION USING gives the linkage items real storage the
# test cases can MOVE into (the same trick is used for CALLed programs on z/OS
# test harnesses).
cd "$(dirname "$1")" || exit 1
sed -i -e '/^       LINKAGE SECTION\./d' \
       -e 's/^\(       PROCEDURE DIVISION\) USING [^.]*\./\1./' "$1"
cobc -xj -std=ibm -I ../copybooks "$@"
