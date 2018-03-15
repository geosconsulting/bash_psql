#!/bin/bash

FILE=$1

function columns {
        ogrinfo $FILE -al -so | \
        sed '/Column/,$!d' | \
        sed '/Geometry Column/d' | \
        sed -e 's/Column =/\:/g' | \
        awk -F: '{print $1}' | \
        awk -v RS= -v OFS="|" '{$1 = $1} 1'
    }

function data {
    ogrinfo $FILE -al | \
    sed '/OGRFeature/,$!d' | \
    sed '/POLYGON\|LINESTRING\|POINT/ d' | \
    sed -e 's/OGRFeature\(.*\)\://g' | \
    sed -e 's/.*\s*\(.*\)\s*=\s*//g' | \
    awk -v RS= -v OFS="|" '{$1 = $1} 1'
    }

{ columns; data; }

echo $data
