#!/bin/bash

# exit when any command fails
set -eo pipefail

input=$1
workdir=$2
outdir=$3

prefix=$(basename $input .gfa.gz)
echo input is $input
mkdir -p /scratch/$workdir
cd /scratch/$workdir
echo unzipping
zcat $input >$prefix.gfa
grep ^P $prefix.gfa | cut -f 2 | grep ^Consensus >cons_names.txt
smoothxg -t 48 -F $prefix.gfa -H cons_names.txt -C $prefix.consensus,100,1000,10000
echo moving files
pigz *.consensus*.gfa
mkdir -p $outdir
mv *.consensus*.gfa.gz $outdir/
cd ../
rm -rf /scratch/$workdir
