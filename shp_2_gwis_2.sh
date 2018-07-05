#!/bin/bash

ftp_dir="data/"
filetype="*.shp"

#psql service=S1

for nomefile in $ftp_dir$filetype
do    
    fname=$(basename $nomefile)
    echo $fname
    echo $nomefile
#  psql service=$1
  shp2pgsql -a -s 4326 -g geom $nomefile temp_ba | psql -U postgres -d test_egeos
done
