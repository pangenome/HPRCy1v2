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
( fastix -p 'chm13#' <(zcat chm13.draft_v1.1.fasta.gz) | bgzip >chm13.fa.gz && samtools faidx chm13.fa.gz ) &
```

Combine them into a single reference for competitive assignment of sample contigs to chromosome bins:

```
zcat chm13.fa.gz grch38.fna.gz >chm13+grch38_full.pan.fa && samtools faidx chm13+grch38_full.pan.fa
```

Remove unplaced contigs from grch38 that are (hopefully) represented in chm13:

```
samtools faidx chm13+grch38_full.pan.fa $(cat chm13+grch38_full.pan.fa.fai | cut -f 1 | grep -v _ ) >chm13+grch38.pan.fa && samtools faidx chm13+grch38.pan.fa
cd ..
```

Partition the assembly contigs by chromosome by mapping each assembly against the scaffolded references, and then subsetting the graph. Here we use [wfmash](https://github.com/ekg/wfmash) for the mapping:

```
dir=HPRCy1v2_wfmash-m
mkdir -p $dir
ref=assemblies/chm13+grch38.pan.fa
aligner=/gnu/store/8zs480nglbdcfl86prj5innnhlc1cvl1-wfmash-0.5.0+37b9e71-1/bin/wfmash
for hap in $(cat haps.list);
do
    in=assemblies/$(ls assemblies | grep $hap | grep .fa$)
    out=$dir/$hap.vs.ref.paf
    sbatch -c 16 --wrap "$aligner -t 16 -m -N -s 50000 -p 90 $ref $in >$out" >>partition.jobids
done
```

Collect unmapped contigs and remap them in split mode:

```
dir=HPRCy1v2_wfmash-m
ref=assemblies/chm13+grch38.pan.fa
aligner=/gnu/store/8zs480nglbdcfl86prj5innnhlc1cvl1-wfmash-0.5.0+37b9e71-1/bin/wfmash
for hap in $(cat haps.list);
do
    in=assemblies/$(ls assemblies | grep $hap | grep .fa$)
    paf=$dir/$hap.vs.ref.paf
    out=$dir/$hap.unaligned
    comm -23 <(cut -f 1 $in.fai | sort) <(cut -f 1 $paf | sort) >$out.txt
    samtools faidx $in $(tr '\n' ' ' <$out.txt) >$out.fa
    samtools faidx $out.fa
    sbatch -c 16 --wrap "$aligner -t 16 -m -s 50000 -p 90 $ref $out.fa >$out.split.vs.ref.paf" >>partition.jobids
    echo $hap
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

We now apply [pggb](https://github.com/pangenome/pggb):

```
( echo 16; seq 1 5; echo 8; echo 20; echo 9; echo 6; echo 17; echo 7; seq 10 15; echo X; seq 18 19; seq 21 22; echo XY; echo Y; echo M ) | while read i; do sbatch -p debug -c 48 --wrap 'cd /scratch && pggb -t 48 -i /lizardfs/erikg/HPRC/year1v2/parts/chr'$i'.pan.fa -Y "#" -p 98 -s 100000 -l 300000 -n 20 -k 127 -B 20000000 -w 200000 -j 100 -e 100000 -I 0.95 -R 0.05 --poa-params 1,7,11,2,33,1 -v -C 100,1000,10000 -Q Consensus_chr'$i'_ -o chr'$i'.pan -Z ; mv /scratch/chr'$i'.pan '$(pwd); done >pggb.jobids
```

# evaluation log

:information_source: We want to measure the reconstruction accuracy of the built pangenome graph using [pgge](https://github.com/pangenome/pgge). Therefore, we align the sequences of samples to the built pangenome graph. Samples `HG002, HG005, NA19240` were left out during pangenome graph construction. Samples `chm13, HG02630, HG02080, HG02486` were part of the building process.

Fetch sequences of samples HG002, HG005, NA19240:

```
( seq 22; echo X; echo Y; echo M ) | while read i; do ./collect_HG002.HG005.NA19240.sh "$i" > parts_eval/chr"$i".HG002.HG005.NA19240.fa && samtools faidx parts_eval/chr"$i".HG002.HG005.NA19240.fa ; done
```
This results in chromosome-specific FASTAs in `parts_eval/chr*.HG002.HG005.NA19240.fa`.

Combine into pangenome sequence:
```
cat parts_eval/*.fa > parts_eval/pan.HG002.HG005.NA19240.fa && samtools faidx parts_eval/pan.HG002.HG005.NA19240.fa
```
Move into its own folder:
```
mkdir parts_eval/HG002.HG005.NA19240
mv parts_eval/* parts_eval/HG002.HG005.NA19240/
```

We now apply [pgge](https://github.com/pangenome/pgge):
```
pgge -g "*.consensus*.gfa" -f ../../parts_eval/HG002.HG005.NA19240/chr8.HG002.HG005.NA19240.fa -o pgge_out.37_chr8_HG002.HG005.NA19240_vg -r ~/software/pgge/git/master/scripts/beehave.R -l 100000 -s 100000 -t 28
```

Fetch sequences of samples chm13, HG02630, HG02080, HG02486:

```
( seq 22; echo X; echo Y; echo M ) | while read i; do ./collect_chm13.HG02630.HG02080.HG02486.sh "$i" > parts_eval/chr"$i".chm13.HG02630.HG02080.HG02486.fa && samtools faidx parts_eval/chr"$i".chm13.HG02630.HG02080.HG02486.fa ; done
```
This results in chromosome-specific FASTAs in `parts_eval/chr*.chm13.HG02630.HG02080.HG02486.fa`.

Combine into pangenome sequence:
```
cat parts_eval/*.fa > parts_eval/pan.chm13.HG02630.HG02080.HG02486.fa && samtools faidx parts_eval/pan.chm13.HG02630.HG02080.HG02486.fa
```
Move into its own folder:
```
mkdir parts_eval/chm13.HG02630.HG02080.HG02486
mv parts_eval/* parts_eval/chm13.HG02630.HG02080.HG02486/
mv parts_eval/chm13.HG02630.HG02080.HG02486/HG002.HG005.NA19240/ parts_eval/
```

We now apply [pgge](https://github.com/pangenome/pgge):
```
pgge -g "*.consensus*.gfa" -f ../../parts_eval/chm13.HG02630.HG02080.HG02486/chr8.chm13.HG02630.HG02080.HG02486.fa -o pgge_out.39_chr8_chm13.HG02630.HG02080.HG02486 -r /home/ubuntu/sh/git/pgge/scripts/beehave.R -t 28 -s 100000 -l 100000
```
