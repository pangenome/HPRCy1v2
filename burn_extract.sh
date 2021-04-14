#!/bin/bash

set -eo pipefail

f=$1

echo "extracting low-coverage regions in $f"
time odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w 100:0:1 -t 48 >$f.lowcov.bed

echo "extracting high-coverage regions in $f"
time odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w 100000:1000:100000000 -t 48 >$f.highcov.bed

echo "burning low/high regions from $f"
nolowhigh=$(basename $f .og).nolowhigh.og
time odgi extract -i $f -t 48 -P \
     --inverse \
     -b <(awk '$3 - $2 > 10000' $f.lowcov.bed ; \
          awk '$3 - $2 > 100000' $f.highcov.bed ) \
     -R <(odgi paths -i $f -L | grep '^chm13') \
     -o - | odgi sort -O -i - -o $nolowhigh

echo "extracting high-degree regions in $nolowhigh"
time odgi degree -i $nolowhigh \
     -w 10000:100:100000000 -t 48 >$f.highdeg.bed

echo "burning high-degree regions from $f"
burned=$(basename $f .og).burn.og
time odgi extract -i $nolowhigh -t 48 -P \
     --inverse \
     -b $f.highdeg.bed \
     -R <(odgi paths -i $nolowhigh -L ) \
     -o - | odgi sort -O -i - -o $burned

echo "primary stats for $burned"
odgi stats -i $burned -S | column -t

echo "depth stats for $burned"
odgi depth -i $burned -S | column -t

echo "degree stats for $burned"
odgi degree -i $burned -S | column -t

echo "generating GFA for $burned"
burned_gfa=$(basename $burned .og).gfa
odgi view -i $burned -g >$burned_gfa

echo "building the XG index for $burned_gfa"
burned_xg=$(basename $burned .og).xg
TEMPDIR=$(pwd) vg convert -t 48 -g -x $burned_gfa >$burned_xg

echo "building VCF from $burned_xg"
burned_xg=$(basename $burned .og).vcf
vg deconstruct -P chm13 \
   $(for i in $(odgi paths -i $f -L | grep -v Cons | cut -f 1 -d '#' | sort | uniq ); do echo -n ' -A '$i; done) \
   -e -a -t 48 $burned_xg >$burned_vcf
