# AMS Edit Book mock -- build, run and test EBUPD01.
#
# On the Mac every target runs inside the toolchain container (docker/Dockerfile),
# next to a PostgreSQL 16 container standing in for DB2. Inside the container
# (IN_TOOLCHAIN=1) the same targets run directly.
#
#   make image      build the toolchain image (first time: ~10 min)
#   make up         start the database container
#   make ci         lint + build + cobol-check + pytest regression (what CI runs)
#   make shell      interactive shell in the toolchain

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Everything that needs the toolchain; on the host these are forwarded to it.
TOOLCHAIN_TARGETS := build run restart test unit lint reset-db gen ci \
                     golden ebcdic-demo clean dump-db

ifndef IN_TOOLCHAIN
# ----------------------------------------------------------------- host side
COMPOSE ?= $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo docker-compose)
# Pass through the knobs the targets understand.
PASS_ENV := $(foreach v,SYSIN MODE EBUPDT_ABEND_AFTER UPDATE_GOLDEN PYTEST_ARGS,$(if $($(v)),-e $(v)='$($(v))'))

.PHONY: help image up down shell $(TOOLCHAIN_TARGETS)
help:
	@sed -n '2,10p' Makefile | sed 's/^# \{0,1\}//'
	@echo "  toolchain targets: $(TOOLCHAIN_TARGETS)"

image:
	$(COMPOSE) build toolchain

up:
	$(COMPOSE) up -d --wait db

down:
	$(COMPOSE) down

shell: up
	$(COMPOSE) run --rm toolchain bash

$(TOOLCHAIN_TARGETS): up
	$(COMPOSE) run --rm -T $(PASS_ENV) toolchain make $@

else
# ------------------------------------------------------------ toolchain side
GIXSQL_HOME ?= /opt/gixsql
COBFLAGS    := -std=ibm -g -save-temps=obj -debug -fec=all -Wall -Wno-others -Wno-arithmetic-osvs -I copybooks
GIXPP       := gixpp -e -S -p -E .cpy -I copybooks -I $(GIXSQL_HOME)/share/gixsql/copy
GIXLIB      := -L$(GIXSQL_HOME)/lib -lgixsql
COPYBOOKS   := $(wildcard copybooks/*.cpy)
PROGRAMS    := bin/EBVALID bin/EBSORT bin/EBUPDT bin/EBRPT

.PHONY: help build run restart test unit lint reset-db gen ci golden \
        ebcdic-demo clean dump-db
help:
	@echo "toolchain targets: $(TOOLCHAIN_TARGETS)"

build: $(PROGRAMS)

bin obj data/work data/out:
	@mkdir -p $@

# Embedded-SQL programs: precompile with gixpp, then compile the output.
# -std=ibm starts WORKING-STORAGE as binary zeros (like z/OS), but gixpp's
# cursor-init flags have no VALUE clause and are tested for SPACE, so the
# sed gives them one. Without it every OPEN CURSOR is silently skipped.
obj/%.cbl: src/%.cbl $(COPYBOOKS) Makefile | obj
	$(GIXPP) -i $< -o $@
	sed -i -E 's/^(GIXSQL 01  GIXSQL-CI-F-[A-Z0-9-]+) PIC X\./\1 PIC X VALUE SPACE./' $@

# -Wno-dialect: gixpp-generated cursor code uses an optional period.
bin/EBVALID: obj/EBVALID.cbl src/EBVRULES.cbl | bin
	cobc -x $(COBFLAGS) -Wno-dialect -fstatic-call -o $@ $^ $(GIXLIB)

bin/EBUPDT bin/EBRPT: bin/%: obj/%.cbl | bin
	cobc -x $(COBFLAGS) -Wno-dialect -o $@ $< $(GIXLIB)

# Plain COBOL, no SQL.
bin/EBSORT: src/EBSORT.cbl $(COPYBOOKS) | bin obj
	cobc -x $(COBFLAGS) -o $@ $<

reset-db:
	psql -q -v ON_ERROR_STOP=1 -f db/schema.sql
	psql -q -v ON_ERROR_STOP=1 -f db/seed.sql

gen:
	python3 tools/gen_data.py

run: build | data/work data/out
	jobs/ebupd01.sh

restart: build
	jobs/ebupd01.sh --restart

dump-db:
	@tools/dump_db.sh

# Fixed-format source must stay in columns 1-72; 73-80 are ignored by the
# compiler, so code that drifts past column 72 is silently dropped.
lint:
	@bad=$$(awk 'length > 72 {print FILENAME":"FNR": "length" cols"}' src/*.cbl copybooks/*.cpy); \
	if [ -n "$$bad" ]; then echo "$$bad"; echo "lint: lines past column 72"; exit 1; fi; \
	echo "lint: all COBOL source within column 72"

# cobol-check paragraph-level unit tests (tests/unit/<PROGRAM>/*.cut).
# cobol-check exits 0 even when a test fails, so read its results file.
UNIT_PROGRAMS := EBVRULES
unit:
	@rm -rf testruns
	@java -jar $(COBOLCHECK_HOME)/bin/cobol-check.jar -c tests/unit/cobol-check.properties \
	    -p $(UNIT_PROGRAMS) > /dev/null 2>&1
	@cat testruns/testResults.txt
	@grep -q 'TEST CASES WERE EXECUTED' testruns/testResults.txt
	@! grep -Eq '^ *[1-9][0-9]* FAILED' testruns/testResults.txt

test: build
	python3 -m pytest -q $(PYTEST_ARGS)

golden: build
	UPDATE_GOLDEN=1 python3 -m pytest -q tests/test_ebupd01.py -k golden

ci: lint build unit test

ebcdic-demo:
	tools/ebcdic_demo.sh

clean:
	rm -rf bin obj data/work data/out testruns

endif
