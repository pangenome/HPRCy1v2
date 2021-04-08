#!/bin/bash

i=$1
samtools faidx /lizardfs/erikg/HPRC/year1v2/assemblies/chm13.fa chm13#chr"$i"
grep -Ff <(</lizardfs/erikg/HPRC/year1v2/parts/chr"$i".contigs grep -e "HG02630\|HG02080\|HG02486" ) /lizardfs/erikg/HPRC/year1v2/assemblies/*.fai \
    | sed s/.fai// \
    | tr ":" " " \
    | awk '{ if (last != $1 && NR > 1) { print last, line; line=$2; } else { line=line" "$2; } last=$1; } END { print last, line; }' \
    | while read f; do samtools faidx $f; done
    