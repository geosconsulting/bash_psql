#!/usr/bin/env bash

log_dir="/home/jrc/pg_log/"

last_log=$(ls $log_dir -rt | tail -n 1)
echo $log_dir$last_log

cat $log_dir$last_log | grep -viE "create index|insert into analytics|vacuum analyze analytics" > /home/jrc/Documents/pg_clean.log

pgbadger -j 4 /home/jrc/Documents/pg_clean.log

#firefox /home/jrc/Documents/out.html
