#!/bin/bash

# exit when any command fails
set -eo pipefail

input=$1
ref=$2
workdir=$3
threads=$4

prefix=$(basename $input .gfa.gz)
echo "input is $input"
mkdir -p $workdir
cd $workdir

echo "unzipping $input to $gfa"
gfa=$prefix.gfa
zcat $input >$gfa

echo "building the .vg for $gfa"
vg=$prefix.vg
xg=$prefix.xg
TEMPDIR=$(pwd) vg convert -t $threads -g $gfa >$vg
echo "building the XG index for $gfa"
TEMPDIR=$(pwd) vg convert -t $threads -x $vg >$xg

echo "building VCF from $out_xg"
vcf=$prefix.vcf
TEMPDIR=$(pwd) vg deconstruct -P $ref \
   $(for i in $(<$gfa | awk '$1 == "P" { print $2 }' | grep -v Cons | cut -f 1 -d '#' | sort | uniq ); \
     do echo -n ' -A '$i; done) \
   -e -a -t $threads $xg >$vcf

echo "gzipping"
pigz *.xg *.gfa *.vcf

echo "done"
