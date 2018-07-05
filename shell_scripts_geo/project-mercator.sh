#!/bin/bash
# reprojects a directory of .shp files to world mercator EPSG:3395

TSRS=$1 # data source's current CRS (may improve accuracy of OGR if specified)

for FILE in *.shp
do
 echo "Transforming $FILE file..."
 FILENEW=`echo $FILE | sed "s/.shp/_3395.shp/"`
 ogr2ogr \
 -f "ESRI Shapefile" \
 -s_srs $TSRS \
 -t_srs "EPSG:3395"\
$FILENEW  $FILE

done
