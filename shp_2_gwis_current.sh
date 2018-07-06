#!/bin/bash

set -e 
set -u

ftp_dir="data/"
filetype="*.shp"

PSQL=/usr/bin/psql
DB_HOST=localhost
DB_NAME=effis
DB_SCHEMA=egeos
DB_USER=postgres

TABLE_PROCESSED_FILES=processed_data
TABLE_CURRENT_BA=current_ba
TABLE_EVOLUTION_BA=evolution_ba
TABLE_TEMPORARY_UPLOAD=temp_ba
TABLE_ANOMALIES=ba_problems

#RUN_ON_DB="$PSQL -X -U $DB_USER -h $DB_HOST --set ON_ERROR_STOP=on --set AUTOCOMMIT=off $DB_NAME"
#already_in=$($PSQL -X -U $DB_USER -h $DB_HOST -P t -P format=unaligned $DB_NAME -c "SELECT COUNT(shp_id) FROM processed_data WHERE filename='$fname'")

RUN_ON_DB="$PSQL -X -U $DB_USER -h $DB_HOST -d $DB_NAME -P t"

manage_shapefiles(){
for nomefile in $ftp_dir$filetype
do   
    #name with extension
    fname=$(basename $nomefile)

    #name without extension
    fbname=${fname%.*}
    
    if [ $1 == 1 ]; then 
          echo $nomefile  
          ./get_contained_ba.sh $nomefile 
    else        
        
        already_in=$($RUN_ON_DB -c "SELECT COUNT(shp_id) FROM $DB_SCHEMA.$TABLE_PROCESSED_FILES WHERE filename='$fname'")

        if [ $already_in == 0 ]; then
            
             file_date=$(echo $fbname | awk -F'_' '{print $1}')
             sensor=$(echo $fbname | awk -F'_' '{print $2}')
             data_type=$(echo $fbname | awk -F'_' '{print $3}')
             
             echo $fname 
             echo "file date: $file_date, sensor: $sensor, data_type: $data_type"               
              
             $RUN_ON_DB -c "INSERT INTO $DB_SCHEMA.$TABLE_PROCESSED_FILES(filename,data_date,data_type,sensor) \
                            VALUES('$fname',to_date('$file_date','YYYYMMDD'),'$sensor','$data_type')" 

             shp2pgsql -a -s 4326 -g geom $nomefile $DB_SCHEMA.$TABLE_TEMPORARY_UPLOAD | psql -U $DB_USER -d $DB_NAME

        else
            echo "$fname already processed. Cannot be repocessed with the same filename"
        fi
    fi
done
}


truncate_tables(){
    lista_tabelle=( $DB_SCHEMA.$TABLE_TEMPORARY_UPLOAD 
                    $DB_SCHEMA.$TABLE_CURRENT_BA 
                    $DB_SCHEMA.$TABLE_PROCESSED_FILES 
                    $DB_SCHEMA.$TABLE_EVOLUTION_BA 
                    $DB_SCHEMA.$TABLE_ANOMALIES )  
    
    for tabella in "${lista_tabelle[@]}"
    do
       $RUN_ON_DB -c "TRUNCATE $tabella" 
    done
}


check_id_current_ba(){

     CURRENT_ID=$($RUN_ON_DB -c "select max(id) from  $DB_SCHEMA.$TABLE_CURRENT_BA")
     let NEXT_ID=CURRENT_ID+1

     echo "Next id for burnt areas is $NEXT_ID"

}

current_bas(){

$RUN_ON_DB -c "select id, firedate, area_ha from $DB_SCHEMA.$TABLE_CURRENT_BA" \
           --single-transaction \
           --set AUTOCOMMIT=off \
           --set ON_ERROR_STOP=on \
           --no-align \
           --field-separator ' ' \
           --quiet \ | while read -a Record; do
             
        id=${Record[0]}
        firedate=${Record[1]}
        area_ha=${Record[2]}
                        
     echo "id: $id, firedate: $firedate, area_hectares: $area_ha"
 done
}


current_evolution_bas(){

$RUN_ON_DB -c "select * from egeos.link_current_evolution();" \
           --single-transaction \
           --set AUTOCOMMIT=off \
           --set ON_ERROR_STOP=on \
           --no-align \
           --field-separator ' ' \
           --quiet \ | while read -a Record; do

     id=${Record[0]}
     updated_firedate=${Record[1]}
     updated_area_ha=${Record[2]}
     initial_firedate=${Record[3]}
     initial_area_ha=${Record[4]}
     difference_area_ha=${Record[5]}
                        
     echo "fire id: $id, initial date: $initial_firedate, initial area: $initial_area_ha, update date: $updated_firedate, update area: $updated_area_ha, increased burnt area: $difference_area_ha"
  done
}

no_evolution_bas(){

$RUN_ON_DB -c "select * from egeos.link_current_no_evolution();" \
           --single-transaction \
           --set AUTOCOMMIT=off \
           --set ON_ERROR_STOP=on \
           --no-align \
           --field-separator ' ' \
           --quiet \ | while read -a Record; do

     id=${Record[0]}     
     initial_firedate=${Record[1]}
     initial_area_ha=${Record[2]}     
                        
     echo "fire id: $id, initial date: $initial_firedate, initial area: $initial_area_ha"
  done
}


ba_anomalies(){

$RUN_ON_DB -c "select * from egeos.ba_problems;" \
           --single-transaction \
           --set AUTOCOMMIT=off \
           --set ON_ERROR_STOP=on \
           --no-align \
           --field-separator ' ' \
           --quiet \ | while read -a Record; do

     sequence=${Record[0]}     
     ba_id=${Record[1]}
     anomaly_definition=${Record[2]}     
                        
     echo "sequence id: $sequence, ba_id: $ba_id, anomaly type: $anomaly_definition"
  done
}


declare -a choices=("Shapefile Metadata")
choices[${#choices[*]}]="Current Burnt Areas"
choices[${#choices[*]}]="Evolution Burnt Areas"
choices[${#choices[*]}]="One Day Burnt Areas No Evolution" 
choices[${#choices[*]}]="Empty Tables"
choices[${#choices[*]}]="Upload Shape"
choices[${#choices[*]}]="Last ID Current BurntArea"
choices[${#choices[*]}]="BurntArea Anomalies"
choices[${#choices[*]}]="List of Options"
choices[${#choices[*]}]="Quit"
#choices+=( "Current Burnt Areas" "Empty Tables" "Upload Shape" "Quit" )

PS3='Select Option: '
all_done=0

while (( !all_done )); do
select choice in "${choices[@]}"
do
    case ${choice} in 
        ${choices[0]})
            manage_shapefiles 1 ;;
        ${choices[1]})
            current_bas ;;
        ${choices[2]})
            current_evolution_bas ;;
        ${choices[3]})
            no_evolution_bas ;;
        ${choices[4]})
            truncate_tables ;;
        ${choices[5]})
            manage_shapefiles 2 ;;
        ${choices[6]})
            ba_anomalies ;;
        ${choices[7]})
           check_id_current_ba ;;
        ${choices[8]})
             break ;;
        *) echo "Exiting...."
            exit ;;
    esac
done
done

echo "Completed"
