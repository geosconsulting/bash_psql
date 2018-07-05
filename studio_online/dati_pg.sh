#!/bin/bash


PGHOST='localhost'
PGPORT='5432'
PGUSER='postgres'
DBNAME='pg_96_cookbook'

 
tabelle=$(psql -U $PGUSER -d $DBNAME -A -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")

for tabella in $tabelle
do
  echo $tabella
done

choices="$tabelle quit"

PS3='Select option: '

select choice in $choices
do
if [ $choice == 'quit' ]
then
break
else
 echo Hai scelto $choice
 psql -U $PGUSER -d $DBNAME -c "SELECT * FROM $choice;"
fi
done
