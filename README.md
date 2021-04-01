# build log

Get the URLs of the assemblies:

```
</lizardfs/erikg/HPRC/HPP_Year1_Assemblies/assembly_index/Year1_assemblies_v2.index grep 'chm13\|h38' | awk '{ print $2 }' | sed 's%s3://human-pangenomics/working/%https://s3-us-west-2.amazonaws.com/human-pangenomics/working/%g' >refs.urls

</lizardfs/erikg/HPRC/HPP_Year1_Assemblies/assembly_index/Year1_assemblies_v2.index grep -v 'chm13\|h38' | awk '{ print $2; print $3 }' | sed 's%s3://human-pangenomics/working/%https://s3-us-west-2.amazonaws.com/human-pangenomics/working/%g' >samples.urls
```

Download them:

```
mkdir assemblies
cd assemblies
cat ../refs.urls ../samples.urls | parallel -j 4 'wget -q {} && echo got {}'
```

Add a prefix to the reference sequences:

```
( fastix -p 'grch38#' <(zcat GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz) | bgzip >grch38.fna.gz && samtools faidx grch38.fna.gz ) &
( fastix -p 'chm13#' <(zcat chm13.draft_v1.0.fasta.gz) | bgzip >chm13.fa.gz && samtools faidx chm13.fa.gz ) &
```

Combine them into a single reference for competitive assignment of sample contigs to chromosome bins:

```
zcat chm13.fa.gz grch38.fna.gz >chm13+grch38.pan.fa && samtools faidx chm13+grch38.pan.fa
```

Partition the assembly contigs by chromosome by mapping each assembly against the scaffolded references, and then subsetting the graph. Here we use [wfmash](https://github.com/ekg/wfmash) for the mapping:

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

Subset by chromosome:

```
mkdir parts
( seq 22; echo X; echo Y; echo M ) | while read i; do awk '$6 ~ "chr'$i'$"' $(ls HPRCy1v2_wfmash-m.1/*.vs.ref.paf | sort) | cut -f 1 | sort >parts/chr$i.contigs; done
( seq 22; echo X; echo Y ) | while read i; do sbatch -p lowmem -c 16 --wrap './collect.sh '$i' >parts/chr'$i'.pan.fa && samtools faidx parts/chr'$i'.pan.fa' ; done >parts.jobids
# special handling of chrM
( samtools faidx assemblies/chm13.fa chm13#chrM; samtools faidx assemblies/grch38.fa grch38#chrM; cat haps.list | grep -v HG002 | grep -v HG005 | grep -v NA19240 | cut -f 1 -d . | sort | uniq  | while read f; do samtools faidx $(ls assemblies/*maternal*fa | grep $f) $f
#2#MT; done) >parts/chrM.pan.fa && samtools faidx parts/chrM.pan.fa
# make a combined X+Y
cat parts/chrX.pan.fa parts/chrY.pan.fa >parts/chrXY.pan.fa && samtools index parts/chrXY.pan.fa
```

This results in chromosome-specific FASTAs in `parts/chr*.pan.fa`.

We now apply [pggb](https://github.com/pangenome/pggb:

```
( echo 16; seq 1 5; echo 8; echo 20; echo 9; echo 6; echo 17; echo 7; seq 10 15; echo X; seq 18 19; seq 21 22; echo XY; echo Y; echo M ) | while read i; do sbatch -p debug -c 48 --wrap 'cd /scratch && pggb -t 48 -i /lizardfs/erikg/HPRC/year1v2/parts/chr'$i'.pan.fa -Y "#" -p 98 -s 100000 -l 300000 -n 20 -k 127 -B 20000000 -w 200000 -j 100 -e 100000 -I 0.95 -R 0.05 --poa-params 1,7,11,2,33,1 -v -C 100,1000,10000 -Q Consensus_chr'$i'_ -o chr'$i'.pan -Z ; mv /scratch/chr'$i'.pan '$(pwd); done >pggb.jobids
```
