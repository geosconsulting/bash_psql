#!/bin/bash

set -e
set -u

RED='\033[0;1;31m'
NC='\033[0m'
PSQL=/usr/bin/psql

DB_NAME=e1gwis
PGRES_SCHEMA=effis
ORCL_SCHEMA=rdaprd
CURRENT_EVOLUTION_SEQ_ID=effis.current_burnt_area_evolution_id_seq

declare -a DB_HOSTS=( "localhost" "h05-srv-dbp96.jrc.it" "pgsql96-srv1.jrc.org" )
declare -a PGRES_TABLES=("current_burnt_area" "current_burnt_area_evolution")
declare -a GEOM_FIELDS=("ST_Transform(ST_SetSRID(shape,3035),4326)" "shape")

if [[ "$#" -eq 0 ]]; then
   #statements
   printf "Which Server?(${RED}l${NC}ocal, ${RED}i${NC}nternal, ${RED}e${NC}xternal)\n"
   exit 1
elif [[ "$1" == "c" ]]; then
   DB_HOST=${DB_HOSTS[0]}
   DB_USER=postgres
   declare -a ORCL_TABLES=("rob_burntareas" "rob_firesevolution")
   RUN_ON_DB="$PSQL -X -U $DB_USER -h $DB_HOST -d $DB_NAME -P t --set ON_ERROR_STOP=on --set AUTOCOMMIT=off"
   num_rec_current_orcl=$($RUN_ON_DB -c "SELECT COUNT(id) FROM $ORCL_SCHEMA.${ORCL_TABLES[0]};")
   num_rec_current_pgres=$($RUN_ON_DB -c "SELECT COUNT(ba_id) FROM $PGRES_SCHEMA.${PGRES_TABLES[0]};")
   if [ $num_rec_current_orcl != $num_rec_current_pgres ]; then
      printf "Not Syncronized orcl $num_rec_current_orcl pgres $num_rec_current_pgres \n"
   else
      echo -e "\033[33;7mSyncronized\033[0m"
   fi
   exit 1
elif [[ $1 == "l" ]]; then
    DB_HOST=${DB_HOSTS[0]}
    DB_USER=postgres
    declare -a ORCL_TABLES=("rob_burntareas" "rob_firesevolution")
    GEOM_FIELD=${GEOM_FIELDS[0]}	
    echo $DB_HOST $DB_USER
elif [[ $1 == "i" ]]; then
    DB_HOST=${DB_HOSTS[1]}
    DB_USER=e1gwis
    declare -a ORCL_TABLES=("rob_burntareas" "rob_firesevolution")
    GEOM_FIELD=${GEOM_FIELDS[0]}	
    echo $DB_HOST $DB_USER
else
    DB_HOST=${DB_HOSTS[2]}
    DB_USER=e1gwis
    declare -a ORCL_TABLES=("current_burntareaspoly" "current_firesevolution")
    GEOM_FIELD=${GEOM_FIELDS[1]}	
    echo $DB_HOST $DB_USER
fi

function check_record() {
   num_rec_current_orcl=$($RUN_ON_DB -c "SELECT COUNT(id) FROM $ORCL_SCHEMA.${ORCL_TABLES[0]};")
   num_rec_current_pgres=$($RUN_ON_DB -c "SELECT COUNT(ba_id) FROM $PGRES_SCHEMA.${PGRES_TABLES[0]};")
   if [ $num_rec_current_orcl != $num_rec_current_pgres ]; then
      sincronizzato='sincorinizzato'
   else
      sincronizzato='nonsincronizzato'
   fi

}

RUN_ON_DB="$PSQL -X -U $DB_USER -h $DB_HOST -d $DB_NAME -P t --set ON_ERROR_STOP=on --set AUTOCOMMIT=off"
num_rec_current_orcl=$($RUN_ON_DB -c "SELECT COUNT(id) FROM $ORCL_SCHEMA.${ORCL_TABLES[0]};")
num_rec_current_pgres=$($RUN_ON_DB -c "SELECT COUNT(ba_id) FROM $PGRES_SCHEMA.${PGRES_TABLES[0]};")

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

RECREATE_ALL_BAS_VIEW=$(cat <<EOF
  BEGIN;
  DROP VIEW IF EXISTS effis.modis_burnt_areas CASCADE;
  CREATE VIEW effis.modis_burnt_areas AS (
              SELECT CASE 
                WHEN extract(year FROM firedate::DATE) IS NULL THEN '9999_' || archived_and_current.ba_id
                ELSE extract(year FROM firedate::DATE) || '_' || archived_and_current.ba_id
              END AS global_id,                      
              archived_and_current.ba_id AS ba_id,
              archived_and_current.area_ha AS area_ha,
              archived_and_current.firedate AS firedate,
              archived_and_current.lastupdate AS lastupdate,
              archived_and_current.geom As geom
              FROM ( SELECT ba_id,area_ha,firedate,lastupdate,geom 
                     FROM effis.current_burnt_area 
                     UNION 
                     SELECT ba_id,area_ha,firedate,lastupdate,geom 
                     FROM effis.archived_burnt_area) AS archived_and_current);   
   COMMIT;                    
EOF
)

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

if [ $num_rec_current_orcl != $num_rec_current_pgres ]
then
  printf "Not Syncronized orcl $num_rec_current_orcl pgres $num_rec_current_pgres \n"

$RUN_ON_DB <<SQL    
    TRUNCATE $PGRES_SCHEMA.${PGRES_TABLES[0]} CASCADE;
    TRUNCATE $PGRES_SCHEMA.${PGRES_TABLES[1]};	
    ALTER SEQUENCE $CURRENT_EVOLUTION_SEQ_ID RESTART WITH 1;
    commit;
SQL

$RUN_ON_DB <<SQL
   $COPY_BAS_ORCL_TO_PGRES_SQL 
   $COPY_BAS_EVOLUTION_ORCL_TO_PGRES_SQL
   commit;
SQL

$RUN_ON_DB <<SQL
   $RECREATE_ALL_BAS_VIEW
   $RECREATE_ALL_BAS_TABLE
SQL

if [[ $1 == 'e' ]]
then
$RUN_ON_DB <<SQL
   $REGENERATE_EMISSION_ENVIRONMENTAL_DAMAGES_TABLES
SQL
fi

else
   echo -e "\033[33;7mSyncronized\033[0m"
fi

