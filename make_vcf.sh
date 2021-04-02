#!/bin/bash

# exit when any command fails
set -eo pipefail

input=$1
refname=$2
workdir=$3
outdir=$4
threads=$5

prefix=$(basename $input .gfa.gz)
echo input is $input
mkdir -p /scratch/$workdir
cd /scratch/$workdir
echo unzipping
zcat $input | grep -v Consensus >$prefix.gfa
echo making xg file
TMPDIR=/scratch vg convert -t $threads -x -g $prefix.gfa >$prefix.xg
echo deconstructing sites
vg deconstruct -t $threads -p $refname $prefix.xg | pigz >$prefix.$refname.site.vcf.gz
#vg deconstruct -a -p $refname $prefix.xg | pigz >$prefix.$refname.site-a.vcf
echo deconstructing haps
vg deconstruct -t $threads -e -p $refname $prefix.xg | pigz >$prefix.$refname.hap.vcf.gz
echo moving files
mv $prefix.$refname.site.vcf.gz $prefix.$refname.hap.vcf.gz $outdir/
cd ../
rm -rf /scratch/$workdir
