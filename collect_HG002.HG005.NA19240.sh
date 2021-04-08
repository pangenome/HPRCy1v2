#!/bin/bash

i=$1
grep -Ff <(</lizardfs/erikg/HPRC/year1v2/parts/chr"$i".contigs grep -e "HG002\|HG005\|NA19240" ) /lizardfs/erikg/HPRC/year1v2/assemblies/*.fai \
    | sed s/.fai// \
    | tr ":" " " \
    | awk '{ if (last != $1 && NR > 1) { print last, line; line=$2; } else { line=line" "$2; } last=$1; } END { print last, line; }' \
    | while read f; do samtools faidx $f; done
    