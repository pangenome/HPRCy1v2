#!/bin/bash

i=$1
samtools faidx assemblies/chm13.fa chm13#chr$i
samtools faidx assemblies/grch38.fa grch38#chr$i
grep -Ff <(<parts/chr$i.contigs grep -v HG002 | grep -v HG005 | grep -v NA19240 | grep -v MT$) assemblies/*.fai \
     | sed s/.fai// \
     | tr ":" " " \
     | awk '{ if (last != $1 && NR > 1) { print last, line; line = ""; } else { line = line" "$2; } last = $1; } END { print last, line; }' \
     | while read f; do samtools faidx $f; done
