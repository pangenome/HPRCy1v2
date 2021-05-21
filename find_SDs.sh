#!/bin/bash

in=$1
ref=$2
spec=$3
out=$4
threads=$5

odgi depth -t $threads -i <(zcat $in) -s <(echo $ref) -w $spec >$out.dups.bed
odgi depth -t $threads -i <(zcat $in) -b $out.dups.bed -s <(echo $ref) >$out.dups_selfcov.bed

