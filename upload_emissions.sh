#! /bin/bash

set -e
set -u

RED='\033[0;1;31m'
NC='\033[0m'
PSQL=/usr/bin/psql

basedir='/data/EFFIS_SMOKE_EMISSION_MODULE/data/emission_chain_1_day.out/'
finaldir=$basedir$2

echo $1 $2 $basedir/$2/* $finaldir

if [ "$#" -gt 1 ] && [ "$#" -lt 2 ]; then
    printf "Provide a username and year as parameters e.g. upload_emission.sh user 2018\n"
    exit 1
fi

ssh "$1"@"139.191.148.169" -t "cd $basedir; bash --login"

ls $finaldir

for file in "$basedir/$2/*"
do
  echo $file
done
