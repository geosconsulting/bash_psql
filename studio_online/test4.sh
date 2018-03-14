#!/bin/bash

if [ $# = 0 ]
then
  nome=Mauro
else
  nome=$1
fi

echo "Primo parametro passato $nome"

num_scripts=$( ls /home/fabio/scripts | wc -l )
echo Ci sono $num_scripts scripts nella directory /home/fabio/scripts 
