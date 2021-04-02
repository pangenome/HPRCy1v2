#!/bin/bash

# exit when any command fails
set -eo pipefail

input=$1
cons100bpgz=$2
cons1000bpgz=$3
cons10000bpgz=$4
refname=$5
workdir=$6
outdir=$7
threads=$8

prefix=$(basename $input .gfa.gz)
cons100bp=$(basename $cons100bpgz .gfa.gz)
cons1000bp=$(basename $cons1000bpgz .gfa.gz)
cons10000bp=$(basename $cons10000bpgz .gfa.gz)
echo input is $input
mkdir -p /scratch/$workdir
cd /scratch/$workdir
echo unzipping


zcat $input >$prefix.gfa
zcat $cons100bpgz >$cons100bp.gfa
zcat $cons1000bpgz >$cons1000bp.gfa
zcat $cons10000bpgz >$cons10000bp.gfa

burng $prefix.gfa $prefix.gfa 2 10000000 $refname full $threads
burng $prefix.gfa $cons100bp.gfa 2 10000000 $refname consensus $threads
burng $prefix.gfa $cons1000bp.gfa 2 10000000 $refname consensus $threads
burng $prefix.gfa $cons10000bp.gfa 2 10000000 $refname consensus $threads

echo moving files
pigz *.burned.gfa
mkdir -p $outdir
mv *.burned.gfa.gz $outdir/
cd ../
rm -rf /scratch/$workdir
