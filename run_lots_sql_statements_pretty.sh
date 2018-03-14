#!/bin/bash

set -e
set -u

RUN_ON_MYDB="psql -X -U postgres -h localhost --set ON_ERROR_STOP=on --set AUTOCOMMIT=off test_egeos"

$RUN_ON_MYDB <<SQL
drop table my_new_table;
create table my_new_table (like current_ba);
commit;
SQL


$RUN_ON_MYDB <<SQL
create index my_new_table_id_idx on my_new_table(id);
commit;
SQL

CREATE_MY_TABLE_SQL=$(cat <<EOF
    create table foo (
         id bigint not null,
         name text not null);
EOF
)
echo $CREATE_MY_TABLE_SQL;

$RUN_ON_MYDB <<SQL
$CREATE_MY_TABLE_SQL
commit;
SQL
