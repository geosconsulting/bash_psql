#!/bin/bash

set -e
set -u

PSQL=/usr/bin/psql

DB_USER=postgres
DB_HOST=localhost
DB_NAME=test_egeos


$PSQL \
      -X \
      -U $DB_USER \
      -h $DB_HOST \
      -c "select id, firedate, area_ha from current_ba" \
      --single-transaction \
      --set AUTOCOMMIT=off \
      --set ON_ERROR_STOP=on \
      --no-align \
      -t \
      --field-separator ' ' \
      --quiet \
      -d $DB_NAME \ | while read -a Record; do
      
      id=${Record[0]}
      firedate=${Record[1]}
      area_ha=${Record[2]}
      
      echo "id: $id, firedate: $firedate, area_hectares: $area_ha"
done
