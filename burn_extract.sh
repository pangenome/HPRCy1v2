#!/bin/bash

set -eo pipefail

f=$1
ref=$2
threads=$3
# 100:0:1
lowcov_spec=$4
# 10000
min_lowcov=$5
# 100000:1000:100000000
highcov_spec=$6
# 100000
min_highcov=$7
# 10000:100:100000000
highdeg_spec=$8

echo "extracting low-coverage regions in $f"
time odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w $lowcov_spec -t $threads >$f.lowcov.bed

echo "extracting high-coverage regions in $f"
time odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w $highcov_spec -t $threads >$f.highcov.bed

echo "burning low/high regions from $f"
nolowhigh=$(basename $f .og).nolowhigh.og
time odgi extract -i $f -t $threads -P \
     --inverse \
     -b <(awk '$3 - $2 > '$min_lowcov $f.lowcov.bed ; \
          awk '$3 - $2 > '$min_highcov $f.highcov.bed ) \
     -R <(odgi paths -i $f -L | grep '^'$ref) \
     -o - | odgi sort -O -i - -o $nolowhigh

echo "extracting high-degree regions in $nolowhigh"
time odgi degree -i $nolowhigh \
     -w $highdeg_spec -t $threads >$f.highdeg.bed

echo "burning high-degree regions from $f"
burned=$(basename $f .og).burn.og
time odgi extract -i $nolowhigh -t $threads -P \
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
TEMPDIR=$(pwd) vg convert -t $threads -g -x $burned_gfa >$burned_xg

echo "building VCF from $burned_xg"
burned_vcf=$(basename $burned .og).vcf
vg deconstruct -P $ref \
   $(for i in $(odgi paths -i $f -L | grep -v Cons | cut -f 1 -d '#' | sort | uniq ); \
     do echo -n ' -A '$i; done) \
   -e -a -t $threads $burned_xg >$burned_vcf
