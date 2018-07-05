#!/bin/bash

echo "anno nascita?"
read anno_nascita

anno_corrente=$(date +"%Y")
echo $anno_corrente

anni=$((anno_corrente-anno_nascita))
echo "Hai $anni anni"

