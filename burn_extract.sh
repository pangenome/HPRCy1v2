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
hap_names=$9

echo "extracting low-coverage regions in $f"
odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w $lowcov_spec -t $threads >$f.lowcov.bed

echo "extracting high-coverage regions in $f"
odgi depth -i $f -s <(odgi paths -i $f -L | grep -v Cons) \
     -w $highcov_spec -t $threads >$f.highcov.bed

echo "extracting high-degree regions in $f"
odgi degree -i $f \
     -w $highdeg_spec -t $threads >$f.highdeg.bed

echo "burning low/high regions from $f"
burned=$(basename $f .og).burn.og
odgi extract -i $f -t $threads -P \
     --inverse \
     -b <((awk '$3 - $2 > '$min_lowcov $f.lowcov.bed ; \
           awk '$3 - $2 > '$min_highcov $f.highcov.bed ;
           awk 'NR > 1' $f.highdeg.bed ) | \
              bedtools sort | bedtools merge) \
     -R <(odgi paths -i $f -L | grep '^'$ref) -o - | \
     odgi sort -i - -o - -O | \
     odgi explode -i - -p $burned.exp -b 1 -s P -O
odgi sort -p Y -i $burned.exp.0.og -o $burned -t $threads -P
rm -f $burned.exp.0.og

echo "primary stats for $burned"
odgi stats -i $burned -S | column -t

echo "depth stats for $burned"
odgi depth -i $burned -S | column -t

echo "degree stats for $burned"
odgi degree -i $burned -S | column -t

echo "generating odgi viz for $burned"
odgi viz -i $burned -x 1500 -y 500 -o $burned.viz.png \
     -p <(odgi paths -i $burned -L | grep -v Cons) -M $hap_names

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
