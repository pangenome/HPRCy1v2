#!/bin/bash

f=$1
odgi extract -i $f -l <(odgi depth -i $f -w 1000 -d | awk 'NR > 1 && $2 <= 110 && $3 >= 3 && $3 <= 110 { print $1 }' ) \
     -c 1 -R <(odgi paths -i $f -L | grep '^chm13\|^grch38' ) -o $(basename $f .og).burn.og -t 16
