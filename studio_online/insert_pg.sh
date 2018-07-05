#!/bin/bash


PGHOST='localhost'
PGPORT='5432'
PGUSER='postgres'
DBNAME='pg_96_cookbook'
TABNAME='nuova_tab'


psql -U $PGUSER -d $DBNAME -c "INSERT INTO $TABNAME(column1,column2) VALUES($1,$2);"
