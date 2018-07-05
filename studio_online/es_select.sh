#!/bin/bash

choices='Postgres Quit'
PS3='Select option: '

select choice in $choices
do
if [ $choice == 'Quit' ]
then
break
elif [ $choice == 'Postgres' ]
then
   pg.sh
fi
echo Hello $choice

done

echo Bye
