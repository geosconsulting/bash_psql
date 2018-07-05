#!/bin/bash

set -e
set -u

RED='\033[0;1;31m'
NC='\033[0m'

if [[ "$#" -eq 0 ]]; then
   #statements
   printf "Which Server?(${RED}l${NC}ocal, ${RED}i${NC}nternal, ${RED}e${NC}xternal)\n"
   exit 1
fi


PSQL=/usr/bin/psql

DB_NAME=e1gwis
PGRES_SCHEMA=effis
ORCL_SCHEMA=rdaprd
CURRENT_EVOLUTION_SEQ_ID=effis.current_burnt_area_evolution_id_seq

declare -a DB_HOSTS=( "localhost" "h05-srv-dbp96.jrc.it" "pgsql96-srv1.jrc.org" )
declare -a PGRES_TABLES=("current_burnt_area" "current_burnt_area_evolution")
declare -a GEOM_FIELDS=("ST_Transform(ST_SetSRID(shape,3035),4326)" "shape")

if [[ $1 == "l" ]]; then
    DB_HOST=${DB_HOSTS[0]}
    DB_USER=postgres
    echo $DB_HOST $DB_USER
elif [[ $1 == "i" ]]; then
    DB_HOST=${DB_HOSTS[1]}
    DB_USER=e1gwis
    echo $DB_HOST $DB_USER
else
    DB_HOST=${DB_HOSTS[2]}
    DB_USER=e1gwis
    echo $DB_HOST $DB_USER
fi

if [[ $1 == "l" ]] || [[ $1 == "i" ]]; then
	declare -a ORCL_TABLES=("rob_burntareas" "rob_firesevolution")
	GEOM_FIELD=${GEOM_FIELDS[0]}	
else
    #echo "current_burntareaspoly" "current_firesevolution"	
	declare -a ORCL_TABLES=("current_burntareaspoly" "current_firesevolution")
	GEOM_FIELD=${GEOM_FIELDS[1]}	
fi

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



else
	echo "Syncronized"
fi
