upload_new_shapefiles(){
for nomefile in $ftp_dir$filetype
do    
    #name with extension
    fname=$(basename $nomefile)
    #name without extension
    fbname=${fname%.*}
    echo $fbname
#   shp2pgsql -a -s 4326 -g geom $nomefile temp_ba | psql -U postgres -d test_egeos
done
}
