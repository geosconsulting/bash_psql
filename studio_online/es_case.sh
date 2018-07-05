#!/bin/bash

case $1 in
    start)
      echo starting
    ;;
    stop) 
      echo stopping
    ;;
    *)
      echo don\'t know    
    ;;
esac
