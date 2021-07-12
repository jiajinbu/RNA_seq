# RNA-seq analysis

a

Jia Jinbu in 2021.3.4

## 1. Input

fastq or compressed fastq file. For pair-end sequencing, each sample has two fastq file, one for read1, one for read2. 

```
sample1.read1.fastq.gz
sample1.read2.fastq.gz
```

## 2. Mapped the raw reads stored in fastq files to genome by hisat2

### 2.1 Download genome fasta file and annotation gtf file

For beginer, you can try to download these files from [Tair](https://www.arabidopsis.org).

```
genome.fa
gene.gtf
```

### 2.2 Build the hisat2 index


First install hisat2.

```
hisat2_extract_exons.py gene.gtf > exon.txt
hisat2_extract_splice_sites.py gene.gtf > ss.txt
hisat2-build -p 4 --exon exon.txt --ss ss.txt genome.fa genome
```

This will generetaed multiple files names as `genome.1.ht2`, `genome.2.ht2`, ..., `genome.8.ht2`. You can just use `genome` to indicate the index path.

### 2.3 Mapped the reads to genome

```
hisat2 -x hisat2_lib/genome \
       -p 10  --min-intronlen 20  --max-intronlen 12000  --dta  --time  \
       -1 sample1.read2.fastq.gz -2 sample1.read2.fastq.gz \
       -S sample1.sam 2> sample1.hisat2.log.txt

samtools sort -@ 10 -o sample1.bam sample1.sam

samtools index sample1.bam

rm sample1.sam
```

Note: You need to set promper `max-intronlen` value for different organism. 

## 3. (Optinonal) Remove PCR duplicate reads

Install picard.

```
java -jar picard.jar MarkDuplicates \ 
     REMOVE_DUPLICATES=true SORTING_COLLECTION_SIZE_RATIO=0.01 \
     I=sample1.bam \
     O=sample1.markdump.bam
     M=sample1.markdump.log.txt
     
samtools index sample1.markdump.bam
```

## 4. Calcualte gene expression levels

Install stringtie.

You need to creat a directory named as `stringtie`, and for each sample, creat a directory names as sample name in the directory `stringtie`.
```
mkdir -p stringtie/sample1
stringtie -e --rf -B -p 4  -G gene.gtf -o stringtie/sample1/sample1.gtf sample1.markdump.bam
```

Note: set `--rf` for fr-firststrand stranded library. set --fr for fr-secondstrand stranded library. Don't set `--rf` and `--fr` for non-stranded library. 

extract count from stringtie results:
You need to download the script `preDE.py`, `extract_rpkm_from_ballgown.R` and `rpkm_merge.py` from bin directory.

```
python preDE.py \ 
      -g gene_count_matrix.csv -t mRNA_count_matrix.csv -i stringtie
```

Note: the `gene_count_matrix.csv` is a csv file seperated by `,`:
```
,sample1,sample2
AT1G01010,660,809
AT1G01020,3328,5872
...
ATMG01400,0,3
```

Extract FPKM values from stringtie results:
```
Rscript extract_rpkm_from_ballgown.R sample1 stringite/sample1 sample1.mRNA.rpkm.txt sample1.gene.rpkm.txt
```

As weipeng's suggested, you can try use `-A` paramter in `stringtie` to generate a gene accumulation table (including FPKM and TPM). But the FPKM values calcualted by `-A` are slightly different with those in gtf output and those extracted by ballgown. 

If you have multiple samples, and generated multiple fpkm files, one for one sample, you can merge them using the script:
(The first file is the output file, followed by the input files.)
```
python rpkm_merge.py all_sample.gene.rpkm.txt sample1.gene.rpkm.txt sample2.gene.rpkm.txt
```

Note: the format of `sample1.gene.rpkm.txt` (tab seperated file) (the column name must be `id` and the sample name):
```
id     sample1
AT1G01010 2.08
AT1G01020 11.79
....
ATMG09980 0
```

The format of `all_sample.gene.rpkm.txt` is tab seperated file:
```
id            sample1       sample2
AT1G01010       2.08         3.07
AT1G01020       11.79        12.28
....
ATMG09980         0            0
```

## 5. Identify differential expressed genes

1. Download the script `deseq2.R` and `merge_deseq2_rpkm.R` from bin directory.

2. Install `DESeq2` R package. 

3. Prepare `sample.group.txt` and `compar_group.list.txt` file. 

Suppose you have nine sample, sample1 ~ 3 are three biological replicates of control, sample4 ~ 6 are three biological replicates of cold treatment, sample7 ~ 9 are three biological replicates of heat treatment: you need to create `sample.group.txt` as described below:

`sample.group.txt`:
```
group         sample 
control       sample1
control       sample2
control       sample3
cold          sample4
cold          sample5
cold          sample6
heat          sample7
heat          sample8
heat          sample9
```

The `sample.group.txt` must contain `group` and `sample` column, the order of column is not cared about by `deseq.R` script.

If you want to compaire `cold` with `control` and `heat` with `control`. You need to create `compar_group.list.txt` as described below:

`compar_group.list.txt`:
```
control cold
control heat
```

`compar_group.list.txt` didn't contail column name. Each row contains one pair of group used for identification of differential genes.

If you also want to compaire `cold` and `heat`, you can create `compar_group.list.txt` as described below:
`compar_group.list.txt`:
```
control cold
control heat
cold heat
```

4. run deseq2.R to identify differentially expressed genes.

```
Rscript deseq2.R gene_count_matrix.csv sample.group.txt compar_group.list.txt deseq2.result.txt
```

The `gene_count_matrix.csv` is a csv file generated by preDE.py as described above, the format is like this:
```
,sample1,sample2
AT1G01010,660,809
AT1G01020,3328,5872
...
ATMG01400,0,3
```

The output of deseq2.result.txt is a tab seperated file like this:
```
id        control_VS_cold_padj control_VS_heat_padj  cold_VS_head_padj
AT1G01010        0.18                0.01                   0.02
AT1G01020        0.98                0.56                   0.43
...
ATMG01400        1                    1                       1
```
The padj means the adjusted p-value calcuated by `DESeq2`.

5. Merge rpkm and deseq2 results

You need to create a `group.txt` to indicate all group name as described below (one group one row):
```
control
cold
heat
```

```
Rscript merge_deseq2_rpkm.R gene.rpkm.txt deseq2.result.txt sample.group.txt group.txt compar_group.list.txt deseq2.fpkm.txt
```

`gene.rpkm.txt` is generated by `rpkm_merge.py`, `deseq2.result.txt` is genereted by `deseq2.R`, `sample.group.tx` and `compar_group.list.txt` are the same files used for `deseq2.R`, `group.txt` is created by yourself.

`deseq2.fpkm.txt` is the output file (tab-sepereted):
```
id         sample1 sample2 ... sample9 control_VS_cold_padj control_VS_heat_padj cold_VS_heat_padj control cold heat log2_control_VS_cold log2_control_VS_heat log2_cold_VS_heat  control_VS_cold_flag control_VS_heat_flag cold_VS_heat_flag
AT1G01010       2.08         3.07        ...      
AT1G01020       11.79        12.28       ...  
...
ATMG09980         0            0         ...       
```

The column `sample1` to `sample9` is the fpkm value of each smaple, and `control`, `cold` and `heat` is the average FPKM value of eahc group. `control_VS_cold_padj` is the adjusted value calcualted by `DESeq2`, `log2_control_VS_cold` is the value of `log2((control + 1)/(cold + 1))`. 

`control_VS_cold_flag` indicates whether the genes are differentially expressed in `cold`: 
- 0: no
- 1: down-regualted in `cold`. That means `control_VS_cold_padj <= 0.05` and `log2_control_VS_cold >= 1`.
- 2: up-regulated in `cold`. That means `control_VS_cold_padj <= 0.05` and `log2_control_VS_cold <= -1`.

