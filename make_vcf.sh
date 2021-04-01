#!/bin/bash

# exit when any command fails
set -eo pipefail

input=$1
refname=$2
workdir=$3
outdir=$4

prefix=$(basename $input .gfa.gz)
echo input is $input
mkdir -p /scratch/$workdir
cd /scratch/$workdir
echo unzipping
zcat $input >$prefix.gfa
echo making xg file
vg convert -t 16 -x -g $prefix.gfa >$prefix.xg
echo deconstructing sites
vg deconstruct -t 16 -p $refname $prefix.xg | pigz >$prefix.$refname.site.vcf.gz
#vg deconstruct -a -p $refname $prefix.xg | pigz >$prefix.$refname.site-a.vcf
echo deconstructing haps
vg deconstruct -t 16 -e -p $refname $prefix.xg | pigz >$prefix.$refname.hap.vcf.gz
echo moving files
mv $prefix.xg $prefix.$refname.site.vcf.gz $prefix.$refname.hap.vcf.gz $outdir/
cd ../
rm -rf /scratch/$workdir
