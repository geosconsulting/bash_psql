#!/bin/bash

day=$1

ftp_dir="data/"
filetype="*.shp"

PSQL=/usr/bin/psql
DB_HOST=localhost
DB_NAME=test_egeos
DB_USER=postgres

#RUN_ON_DB="$PSQL -X -U $DB_USER -h $DBHOST -d $DB_NAME"

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
        already_in=$($PSQL -X -U $DB_USER -h $DB_HOST -P t -P format=unaligned $DB_NAME -c "SELECT COUNT(shp_id) FROM processed_data WHERE filename='$fname'")
        
        if [ $already_in == 0 ]; then
            file_date=$(echo $fbname | awk -F'_' '{print $1}')
            sensor=$(echo $fbname | awk -F'_' '{print $2}')
            data_type=$(echo $fbname | awk -F'_' '{print $3}')
             
            #echo "file date: $file_date, sensor: $sensot, data_type: $data_type"               
              
            $PSQL -X -U $DB_USER -h $DB_HOST -d $DB_NAME -c "INSERT INTO processed_data(filename,data_date,data_type,sensor) \
                                                             VALUES('$fname',to_date('$file_date','YYYYMMDD'),'$sensor','$data_type')" 
        
            shp2pgsql -a -s 4326 -g geom $nomefile temp_ba | psql -U postgres -d test_egeos
        else
            echo "Already processed. Cannot be repocessed with the same filename"
        fi
    fi
done
}

truncate_tables(){
    lista_tabelle=( temp_ba current_ba processed_data evolution_ba )  
    for tabella in "${lista_tabelle[@]}"
    do
    psql -U $DB_USER -d $DB_NAME -c "TRUNCATE $tabella" 
    done
}

truncate_table(){
    psql -U $DB_USER -d $DB_NAME -c "TRUNCATE $1" 
}

check_id_current_ba(){

CURRENT_ID=$($PSQL -X -U $DB_USER -h $DB_HOST -P t -P format=unaligned $DB_NAME -c "select max(id) from current_ba")
let NEXT_ID=CURRENT_ID+1

echo "Next id for burnt areas is $NEXT_ID"

}

current_bas(){

set -e
set -u

$PSQL \
     -X \
     -U $DB_USER \
     -h $DB_HOST \
     -c "select id, firedate, area_ha from current_ba" \
     --single-transaction \
     --set AUTOCOMMIT=off \
     --set ON_ERROR_STOP=on \
     --no-align \
     -t \
     --field-separator ' ' \
     --quiet \
     -d $DB_NAME \ | while read -a Record; do
      
     id=${Record[0]}
     firedate=${Record[1]}
     area_ha=${Record[2]}
                        
     echo "id: $id, firedate: $firedate, area_hectares: $area_ha"
 done
}


current_evolution_bas(){

set -e
set -u

$PSQL \
     -X \
     -U $DB_USER \
     -h $DB_HOST \
     -c "select * from link_current_evolution();" \
     --single-transaction \
     --set AUTOCOMMIT=off \
     --set ON_ERROR_STOP=on \
     --no-align \
     -t \
     --field-separator ' ' \
     --quiet \
     -d $DB_NAME \ | while read -a Record; do

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

set -e
set -u

$PSQL \
     -X \
     -U $DB_USER \
     -h $DB_HOST \
     -c "select * from link_current_no_evolution();" \
     --single-transaction \
     --set AUTOCOMMIT=off \
     --set ON_ERROR_STOP=on \
     --no-align \
     -t \
     --field-separator ' ' \
     --quiet \
     -d $DB_NAME \ | while read -a Record; do

     id=${Record[0]}     
     initial_firedate=${Record[1]}
     initial_area_ha=${Record[2]}
     
                        
     echo "fire id: $id, initial date: $initial_firedate, initial area: $initial_area_ha"
  done
}


declare -a choices
choices[${#choices[*]}]="Shapefile Metadata" 
choices[${#choices[*]}]="Current Burnt Areas"
choices[${#choices[*]}]="Evolution Burnt Areas"
choices[${#choices[*]}]="One Day Burnt Areas No Evolution" 
choices[${#choices[*]}]="Empty Tables"
choices[${#choices[*]}]="Upload Shape"
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
             break ;;
        *) echo "Exiting...."
            exit ;;
    esac
done
done

echo "Completed"