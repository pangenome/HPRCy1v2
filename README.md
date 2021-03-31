# build log

get the urls of the assemblies

```
</lizardfs/erikg/HPRC/HPP_Year1_Assemblies/assembly_index/Year1_assemblies_v2.index grep 'chm13\|h38' | awk '{ print $2 }' | sed 's%s3://human-pangenomics/working/%https://s3-us-west-2.amazonaws.com/human-pangenomics/working/%g' >refs.urls

</lizardfs/erikg/HPRC/HPP_Year1_Assemblies/assembly_index/Year1_assemblies_v2.index grep -v 'chm13\|h38' | awk '{ print $2; print $3 }' | sed 's%s3://human-pangenomics/working/%https://s3-us-west-2.amazonaws.com/human-pangenomics/working/%g' >samples.urls
```

download them

```
mkdir assemblien
cd assemblies
cat ../refs.urls ../samples.urls | parallel -j 4 'wget -q {} && echo got {}'
```

add prefix to ref seqs

```
( fastix -p 'grch38#' <(zcat GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz) | bgzip >grch38.fna.gz && samtools faidx grch38.fna.gz ) &
( fastix -p 'chm13#' <(zcat chm13.draft_v1.0.fasta.gz) | bgzip >chm13.fa.gz && samtools faidx chm13.fa.gz ) &
```

Combine them into a single reference for competitive assignment of sample contigs to chromosome bins.

```
zcat chm13.fa.gz grch38.fna.gz >chm13+grch38.pan.fa && samtools faidx chm13+grch38.pan.fa
```

Partition the assembly contigs by chromosome by mapping each assembly against the scaffolded references, and then subsetting the graph. Here we use wfmash for the mapping.

```
cd ..
mkdir HPRCy1v2_wfmash-m.1
ref=assemblies/chm13+grch38.pan.fa
aligner=/gnu/store/lkdmq6mgqv3hmg4l1nmad34c536y2ga8-wfmash-0.3.1+e89867d-15/bin/wfmash
for hap in $(cat haps.list);
do
    in=assemblies/$(ls assemblies | grep $hap | grep .fa$)                  
    out=HPRCy1v2_wfmash-m.1/$hap.vs.ref.paf
    sbatch -p lowmem -c 16 --wrap "$aligner -t 16 -m -N -p 90 $ref $in >$out" >>partition.jobids
done
```

Subset by chromosome.

```
mkdir parts
( seq 22; echo X; echo Y; echo M ) | while read i; do awk '$6 ~ "chr'$i'$"' $(ls HPRCy1v2_wfmash-m.1/*.vs.ref.paf | sort -V) | cut -f 1 | sort -V >parts/chr$i.contigs; done
( seq 22; echo X; echo Y; echo M ) | while read i; do sbatch -p lowmem -c 16 --wrap './collect.sh '$i' >parts/chr'$i'.pan.fa && samtools faidx parts/chr'$i'.pan.fa' ; done >parts.jobids
```

This results in chromosome-specific FASTAs in `parts/chr*.pan.fa`.

We additionally combine chrX and chrY into `chrXY.pan.fa`, as these contain homologous recombining regions.