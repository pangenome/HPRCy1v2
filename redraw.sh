#!/bin/bash

f=$1
d=$(dirname $f)
b=$(basename $f .gz)

odgi draw -i <(zcat $f) -c $d/$b.lay -p $d/$b.draw.simple.png
