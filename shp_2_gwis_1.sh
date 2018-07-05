#!/bin/bash

ftp_dir="simulazione_egeos/"
today=`date`
echo $today
year=`date +%Y`
month=`date +%m`
day=`date +%d`
extension=".shp"

for nomefile in $ftp_dir/*.shp
do 
fname=$(basename $nomefile)
echo $fname
fbname=${fname%.*}
echo $fbname

date_file_txt=$(echo $fname | awk -F '_' '{print $1}')
echo $date_file_txt

date_file=$(`date "$date_file_txt" +%Y%m%d`)
echo $date_file

#psql -U postgres -d test_egeos -c "TRUNCATE temp_ba;"
#shp2pgsql -a -s 4326 -g geom $nomefile temp_ba | psql -U postgres -d test_egeos
done
