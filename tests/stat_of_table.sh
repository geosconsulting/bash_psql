#!/bin/bash

set -e
set -u

if [ -z $1 ]; then
    echo "Usage: $0 table [db]"
    exit 1
fi

SCMTBL=$1
SCHEMANAME=${SCMTBL%%.*} #tutto quello che c'e' prima del punto (o SCMTBL se non c'e' niente)
TABLENAME=${SCMTBL#*.} #tutto quello che c'e' dopo il punto (o SCMTBL se non c'e' niente)

if [ ${SCHEMANAME} = ${TABLENAME} ]; then
    SCHEMANAME="public"
fi

echo $2;

if [ -n $2 ]; then
    DB=$2
else
    DB="effis"
fi

PSQL="psql -U postgres -h localhost -d $DB -x -c "

$PSQL "
SELECT '------------' as \"-------------\",
    schemaname,
    tablename,
    attname,
    null_frac,
    avg_width,
    n_district,
    correlation,
    most_common_vals,
    most_common_freqs,
    histogram_bounds
FROM pg_stats
WHERE schemaname='$SCHEMANAME'
AND tablename='$TABLENAME';
" | grep -v "\-\[ RECORDS "
