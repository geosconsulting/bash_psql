#!/bin/bash

set -e
set -u

#Set these environmental variables to override them,
#but theu have safe defaults.
export PGHOST=${PGHOST-localhost}
export PGPORT=${PGPORT-5432}
export PGDATABASE=${PGDATABASE-test_egeos}
export PGUSER=${PGUSER-postgres}
export PGPASSWORD=${PGPASSWORD-antarone}

RUN_PSQL="psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on "


${RUN_PSQL} <<SQL
select blah_column 
from blahs 
where blah_column = 'foo';
rollback;
SQL


