#!/bin/bash

# exit when any command fails
set -eo pipefail

in=$1
vcf=$(basename $in .vcf.gz).sites.vcf
zcat $in | cut -f -8 | vcflength >$vcf
q=$vcf.length.tsv
( echo chr pos length length.ref length.alt | tr ' ' '\t'
  bio-vcf --eval 'x = rec.alt.map { |v| [(rec.ref.length - v.length).abs, rec.ref.length, v.length] }.sort_by { |a| -a[0] }; y=x[0]; print([rec.chr, rec.pos, y[1]-y[2], y[1], y[2]].join("\t"), "\n")' <$vcf | grep -v '^#' ) >$q

Rscript -e 'require(tidyverse); x <- read.delim("'$q'"); ggplot(x, aes(x=length.alt, y=length.ref)) + geom_jitter(size=0.1) + scale_y_log10() + scale_x_log10(); ggsave("'$q'.png")'
