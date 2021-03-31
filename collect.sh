#!/bin/bash

i=$1
samtools=/gnu/store/ky1ndl1gj0pqk0alhvmps2xdrf347aqh-samtools-1.11/bin/samtools
$samtools faidx assemblies/chm13.fa chm13#chr$i
$samtools faidx assemblies/grch38.fa grch38#chr$i
grep -Ff <(<parts/chr$i.contigs grep -v HG002 | grep -v HG005 | grep -v NA19240 | grep -v MT$) assemblies/*.fai \
     | sed s/.fai// \
     | tr ":" " " \
     | awk '{ if (last != $1 && NR > 1) { print "'$samtools' faidx", last, line; line = ""; } else { line = line" "$2; } last = $1; } END { print "'$samtools' faidx", last, line; }' \
     | parallel --tmpdir /scratch -k -j 16 '{}'
