#!/usr/bin/env bash

dbname=e1gwis

if [ "$1" == "i" ]; then
    int_host=h05-srv-dbp96.jrc.it
    user=e1gwis
    pwd=ka4Zie4i
elif [ "$1" == "e" ]; then
    int_host=pgsql96-srv1.jrc.org
    user=e1gwis
    pwd=ka4Zie4i
elif [ -z "$1" ]; then
    int_host=localhost
    user=postgres
    pwd=antarone
fi

echo $int_host$user$pwd

postgresqltuner.pl --host=$int_host --database=$dbname --user=$user --password=$pwd

