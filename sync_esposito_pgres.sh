#!/bin/bash

set -e
set -u

# color for status
RED='\033[0;1;31m'
NC='\033[0m'

# predetermined messages
NEGATIVE_MSG="PostgreSQL \033[31;7mnot syncronized\033[0m with Oracle."
POSITIVE_MSG="PostgreSQL \033[32;7msyncronized\033[0m with Oracle."

script_dir="$( dirname "${BASH_SOURCE[0]}" )"
method=$(awk -F "=" '/registering_method/ {print $2}' $script_dir/update_parameters.ini)
awk -F\= '{gsub(/"/,"",$2);print "Content of " $1 " is " $2}' $script_dir/update_parameters.ini

echo -e "Writing logs on $method - Change update_parameters.ini for other options\n"
echo -e "Set registering_method eithet to "logfile" or "logdb"\n"

# path to psql
#PSQL=/usr/bin/psql
PSQL=$(awk -F "=" '/PSQL/ {print $2}' $script_dir/update_parameters.ini)

# database reference
#DB_NAME=e1gwis
DB_NAME=$(awk -F "=" '/DB_NAME/ {print $2}' $script_dir/update_parameters.ini)
#PGRES_SCHEMA=effis
PGRES_SCHEMA=$(awk -F "=" '/PGRES_SCHEMA/ {print $2}' $script_dir/update_parameters.ini)
#ORCL_SCHEMA=rdaprd
ORCL_SCHEMA=$(awk -F "=" '/ORCL_SCHEMA/ {print $2}' $script_dir/update_parameters.ini)
GEOM_FIELD="ST_Multi(shape)"

CURRENT_EVOLUTION_SEQ_ID=effis.current_burnt_area_evolution_id_seq

# table names in PostgreSQL and Oracle (some are arrays because it's possible to manage multiple DB instances
declare -a DB_HOSTS=( "pgsql96-srv1.jrc.org" )
declare -a PGRES_TABLES=( "current_burnt_area" "current_burnt_area_evolution" )
declare -a ORCL_TABLES=( "current_burntareaspoly" "current_firesevolution" )

DB_HOST=${DB_HOSTS[0]}
#DB_USER=e1gwis
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $script_dir/update_parameters.ini)
#DB_PWD=ka4Zie4i
DB_PWD=$(awk -F "=" '/DB_PWD/ {print $2}' $script_dir/update_parameters.ini)

RUN_ON_DB="$PSQL -X -U $DB_USER -h $DB_HOST -d $DB_NAME -P t --set ON_ERROR_STOP=on --set AUTOCOMMIT=off"

# if no param provided it will default to e(XTERNAL) database on DMZ
server=${1-e}

function check_record() {
   num_rec_current_orcl=$($RUN_ON_DB -c "SELECT COUNT(id) FROM $ORCL_SCHEMA.${ORCL_TABLES[0]};")
   num_rec_current_pgres=$($RUN_ON_DB -c "SELECT COUNT(ba_id) FROM $PGRES_SCHEMA.${PGRES_TABLES[0]};")
   if [ $num_rec_current_orcl != $num_rec_current_pgres ]; then
      recSync=false      
   else
      recSync=true
   fi
}

function check_area() {
   sum_area_ha_current_orcl=$($RUN_ON_DB -c "SELECT SUM(area_ha) FROM $ORCL_SCHEMA.${ORCL_TABLES[0]};")
   sum_area_ha_current_pgres=$($RUN_ON_DB -c "SELECT SUM(area_ha) FROM $PGRES_SCHEMA.${PGRES_TABLES[0]};")
   if [ $sum_area_ha_current_orcl != $sum_area_ha_current_pgres ]; then
      areaSync=false      
   else
      areaSync=true
   fi
}

function server_stats(){

   printf "Database Server:${DB_HOST} \nDatabase User:${DB_USER}\n
\t*** PostgreSQL ***   
Current BAs table:${PGRES_TABLES[0]} 
Evolution BAs table:${PGRES_TABLES[1]}

\t*** Oracle ***   
Current BAs table:${ORCL_TABLES[0]} 
Evolution BAs table:${ORCL_TABLES[1]}\n\n"
}

function write_log(){
	echo "Starting backup to $LOGFILE..."
	echo -e "`date +"%D:%T"` : $1 syncronized $2 - $3 syncronized $4" >> $LOGFILE 2>&1
}

function syncronization_messages(){

   if [[ "$recSync" = true ]]; then      
      echo -e "$1in "$POSITIVE_MSG       
      printf "Oracle="$(echo -e "${num_rec_current_orcl}" | 
      	      sed -e 's/^[[:space:]]*//')" Postgres="$(echo -e "${num_rec_current_pgres}" | 
      	      sed -e 's/^[[:space:]]*//')"\n\n"
   else            
      echo -e "$1in "$NEGATIVE_MSG       
      printf "Oracle="$(echo -e "${num_rec_current_orcl}" | 
      	      sed -e 's/^[[:space:]]*//')" Postgres="$(echo -e "${num_rec_current_pgres}" | 
      	      sed -e 's/^[[:space:]]*//')"\n\n"
   fi   

   if [[ $areaSync = true ]]; then
      echo -e "$2in "$POSITIVE_MSG
      printf "Oracle="$(echo -e "${sum_area_ha_current_orcl}" | 
      	      sed -e 's/^[[:space:]]*//')" Postgres="$(echo -e "${sum_area_ha_current_pgres}" | 
      	      sed -e 's/^[[:space:]]*//')"\n\n"
   else
      echo -e "$2in "$NEGATIVE_MSG
      printf "Oracle="$(echo -e "${sum_area_ha_current_orcl}" | 
      	        sed -e 's/^[[:space:]]*//')" Postgres="$(echo -e "${sum_area_ha_current_pgres}" | 
      	        sed -e 's/^[[:space:]]*//')"\n\n"
   fi
}

# get current ba areas from oracle to pgres
COPY_BAS_ORCL_TO_PGRES_SQL=$(cat <<EOF
  INSERT INTO effis.current_burnt_area 
	SELECT id,
    	   area_ha,    
           firedate,    
           lastupdate,    
           $GEOM_FIELD
    FROM $ORCL_SCHEMA.${ORCL_TABLES[0]}
    WHERE id is not null;
EOF
)

# get evolution ba areas from oracle to pgres
COPY_BAS_EVOLUTION_ORCL_TO_PGRES_SQL=$(cat <<EOF
    INSERT INTO effis.current_burnt_area_evolution(ba_id,area_ha,firedate,lastupdate,geom)
    SELECT id,
    	area_ha,    
    	firedate,    
    	lastupdate,
        $GEOM_FIELD 
    FROM $ORCL_SCHEMA.${ORCL_TABLES[1]};
EOF
)

# view off all BA's current + historical
RECREATE_ALL_BAS_VIEW=$(cat <<EOF
  BEGIN;
  DROP VIEW IF EXISTS effis.modis_burnt_areas CASCADE;
  CREATE VIEW effis.modis_burnt_areas AS (
              SELECT CASE 
                WHEN yearseason IS NULL THEN '9999_' || archived_and_current.ba_id
                ELSE yearseason || '_' || archived_and_current.ba_id
              END AS global_id,                      
                archived_and_current.ba_id AS ba_id,
                archived_and_current.area_ha AS area_ha,
                archived_and_current.firedate AS firedate,
                archived_and_current.lastupdate AS lastupdate,
                archived_and_current.geom As geom
              FROM (SELECT ba_id,area_ha,firedate,lastupdate,extract(year from firedate::DATE) as yearseason,geom 
   FROM effis.current_burnt_area 
   UNION 
   SELECT ba_id,area_ha,firedate,lastupdate,yearseason,geom 
       FROM effis.archived_burnt_area) AS archived_and_current);   
   COMMIT;                    
EOF
)

# table from view off all BA's current + historical
RECREATE_ALL_BAS_TABLE=$(cat <<EOF
  BEGIN;

  DROP TABLE IF EXISTS effis.burnt_areas CASCADE;
  CREATE TABLE effis.burnt_areas AS SELECT * FROM effis.modis_burnt_areas;
  ALTER TABLE effis.burnt_areas ADD PRIMARY KEY(global_id);

  ALTER TABLE effis.burnt_areas ALTER COLUMN global_id TYPE varchar;
  ALTER TABLE effis.burnt_areas ALTER COLUMN firedate TYPE DATE using to_date(firedate, 'YYYY-MM-DD');
  ALTER TABLE effis.burnt_areas ALTER COLUMN lastupdate TYPE DATE using to_date(lastupdate, 'YYYY-MM-DD');
  
  grant usage on schema effis to e1gwis;
  grant usage on schema effis to e1gwisro;

  grant all on all tables in schema effis to e1gwis;
  grant all on all sequences in schema effis to e1gwis;
  grant all on all functions in schema effis to e1gwis;

  grant SELECT on all tables in schema effis to e1gwisro;
  grant SELECT on all sequences in schema effis to e1gwisro;
  grant execute on all functions in schema effis to e1gwisro;
  
  grant SELECT on all tables in schema effis to e1gwised;
  grant SELECT on all sequences in schema effis to e1gwised;
  grant execute on all functions in schema effis to e1gwised;

  CREATE INDEX sidx_burnt_areas
  ON effis.burnt_areas
  USING gist
  (geom);

  CREATE INDEX idx_burnt_areas_firedate
  ON effis.burnt_areas
  USING btree
  (firedate);

  CREATE INDEX idx_burnt_areas_lastupdate
  ON effis.burnt_areas
  USING btree
  (lastupdate);

  COMMIT;                    
EOF
)

# emission table for each current ba 
REGENERATE_EMISSION_ENVIRONMENTAL_DAMAGES_TABLES=$(cat <<EOF
  BEGIN;

  TRUNCATE effis.fire_environmental_damage_statistic;
  ALTER SEQUENCE effis.fire_environmental_damage_statistic_id_seq RESTART WITH 1;
  
  INSERT INTO effis.fire_environmental_damage_statistic(ba_id,agricultural_area,artificial_surface,broad_leaved_forest,
                                                        coniferous,mixed,other_land_cover,other_natural_landcover,
                                                        percentage_natura2k,sclerophyllous,transitional)
  SELECT id,agriareas,artifsurf,broadlea,conifer,mixed,otherlc,othernatlc,percna2k,scleroph,transit FROM  rdaprd.current_burntareaspoly;

  TRUNCATE effis.fire_emission_statistic;
  ALTER SEQUENCE effis.fire_emission_statistic_id_seq RESTART WITH 1;
  INSERT INTO effis.fire_emission_statistic(ba_id,biomass,ch4,co,co2,ec,nmhc,nox,oc,pm,pm10,pm2_5,voc)
  SELECT id,biomass,ch4,co,co2,ec,nmhc,nox,oc,pm,pm10,pm2_5,voc from rdaprd.emissions_fires;

  COMMIT;                    
EOF
)

# if c is passed only counts records and check area sum otherwise syncronize dbs
if [[ $server == "c" ]]; then   
   server_stats 
   check_record   
   check_area   
   syncronization_messages "Records " "Area "

  if [ $method == logfile ]; then   

    echo "Checking directory with stored logs......."
    dir_logs=$script_dir/update_logs

    find $dir_logs -name 'update_*.log'  -type f -mtime +7 -print -delete #>> $log

    today=$(date +"%m_%d_%Y")
    LOGFILE=update_logs/update_$today.log

    #check if log directory exists if not create it
    if [ ! -d $dir_logs ]; then
      mkdir -p $dir_logs;
    fi

  elif [ $method = logdb ]; then   

    echo "Writing in PostgreSQL......."  

  questo_momento=$(date +"%Y-%m-%d:%T")
   
$RUN_ON_DB<<SQL 
     insert into effis._updates(datetime_update,num_records,area_ha) 
     values('$questo_momento',$num_rec_current_orcl,$sum_area_ha_current_pgres);
     commit;
SQL

  else
    echo "Changes unlogged"
  fi

   exit 1
else    
   server_stats
   check_record   
   check_area
if [[ $recSync = true ]] && [[ $areaSync = true ]]
then 
   syncronization_messages "Records " "Area "
   exit 1;
else
   syncronization_messages "Records " "Area "
  

# empty tables
$RUN_ON_DB <<SQL    
    TRUNCATE $PGRES_SCHEMA.${PGRES_TABLES[0]} CASCADE;
    TRUNCATE $PGRES_SCHEMA.${PGRES_TABLES[1]};	
    ALTER SEQUENCE $CURRENT_EVOLUTION_SEQ_ID RESTART WITH 1;
    commit;
SQL

# copy tables from oracle to emptied tables
$RUN_ON_DB <<SQL
   $COPY_BAS_ORCL_TO_PGRES_SQL 
   $COPY_BAS_EVOLUTION_ORCL_TO_PGRES_SQL
   commit;
SQL

# recreate view and table of all bas
$RUN_ON_DB <<SQL
   $RECREATE_ALL_BAS_VIEW
   $RECREATE_ALL_BAS_TABLE
   commit;
SQL

# recreate emission table
$RUN_ON_DB <<SQL
   $REGENERATE_EMISSION_ENVIRONMENTAL_DAMAGES_TABLES
   commit;
SQL
fi
   write_log records $recSync area_ha $areaSync
fi
