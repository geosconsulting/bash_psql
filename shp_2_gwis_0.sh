#!/bin/bash

#for nomefile in simulazione_egeos/*.shp
ftp_dir="data/"
prefix="2018120"
day=$1
postfix="_MODA_BA_WGS84.shp"
nomefile=$ftp_dir$prefix$1$postfix
echo $nomefile

#do 
fname=$(basename $nomefile)
#echo $fname
fbname=${fname%.*}
#echo $fbname
psql -U postgres -d test_egeos -c "TRUNCATE temp_ba;"
shp2pgsql -a -s 4326 -g geom $nomefile temp_ba | psql -U postgres -d test_egeos
#done
