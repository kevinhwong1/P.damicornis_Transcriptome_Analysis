# P. acuta differential expression analysis using P. acuta reference genome

This analysis is running in parallel with P.dam_DE_Analysis.md. I am using the same cleaned reads from the prior analysis, but now using the P. acuta reference genome from Bali (more info to come)

### Uploading reference genome to KITT

`scp -P 2292 ./Pocillopora_acuta_genome_v1.fasta kwong@kitt.uri.edu:Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis`

### Aligning reads to reference transcriptome (Script from E. Roberts)
https://github.com/erinroberts/apoptosis_data_pipeline/blob/master/Streamlined%20Pipeline%20Tutorial/Apoptosis_Pipeline_Tutorial_with_Reduced_Dataset.Rmd
* used reference P. damicornis transcriptome from Maui 2015

`conda install -c bioconda hisat2`  
`nano HISAT2-2.sh`
```
#!/bin/bash

#Specify working directory
F=/home/kwong/Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis

hisat2-build -f $F/Pocillopora_acuta_genome_v1.fasta $F/Pocillopora_acuta_genome_v1_edited
#-f indicates that the reference input files are FASTA files

#Aligning paired end reads
array1=($(ls $F/*_R1_cleaned.fastq.gz))

for i in ${array1[@]}; do
	hisat2 --dta -x $F/Pocillopora_acuta_genome_v1_edited  -1 ${i} -2 $(echo ${i}|sed s/_R1_cleaned/_R2_cleaned/) -S ${i}.sam
	echo "HISAT2 PE ${i}" $(date)
done
```
`bash HISAT2-2.sh`

output
```
4134422 reads; of these:
  4134422 (100.00%) were paired; of these:
    1779923 (43.05%) aligned concordantly 0 times
    2339375 (56.58%) aligned concordantly exactly 1 time
    15124 (0.37%) aligned concordantly >1 times
    ----
    1779923 pairs aligned concordantly 0 times; of these:
      41496 (2.33%) aligned discordantly 1 time
    ----
    1738427 pairs aligned 0 times concordantly or discordantly; of these:
      3476854 mates make up the pairs; of these:
        2734462 (78.65%) aligned 0 times
        710174 (20.43%) aligned exactly 1 time
        32218 (0.93%) aligned >1 times
66.93% overall alignment rate
HISAT2 PE /home/kwong/Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis/1026_CGATGT_L003_R1_cleaned.fastq.gz Wed Feb 20 18:51:53 EST 2019
```

## Convert SAM to BAM using SAMTools (Script from E. Roberts)
https://github.com/erinroberts/apoptosis_data_pipeline/blob/master/Streamlined%20Pipeline%20Tutorial/Apoptosis_Pipeline_Tutorial_with_Reduced_Dataset.Rmd

`conda install samtools`

`nano sambam-2.sh`

```
#!/bin/bash

#SAMTOOLS sort to convert the SAM file into a BAM file to be used with StringTie
#SHOULD NOT PERFORM FILTERING ON HISAT2 OUTPUT
F=/home/kwong/Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis

array3=($(ls $F/*.sam))
        for i in ${array3[@]}; do
                /usr/local/bin/samtools sort ${i} > ${i}.bam #Stringtie takes as input only sorted bam files
                echo "${i}_bam"
        done

#Get bam file statistics for percentage aligned with flagstat
# to get more detailed statistics use $ samtools stats ${i}
array4=($(ls $F/*.bam))
        for i in ${array4[@]}; do
                /usr/local/bin/samtools flagstat ${i} > ${i}.bam.stats #get % mapped
        #to extract more detailed summary numbers
                /usr/local/bin/samtools stats ${i} | grep ^SN | cut -f 2- > ${i}.bam.fullstat
                echo "STATS DONE" $(date)
        done
```
`bash sambam-2.sh`


### Assemble reads to reference using Stringtie (Script from E. Roberts)
https://github.com/erinroberts/apoptosis_data_pipeline/blob/master/Streamlined%20Pipeline%20Tutorial/Apoptosis_Pipeline_Tutorial_with_Reduced_Dataset.Rmd

`conda install -c bioconda stringtie`

`nano stringtie-2.sh`

```
#!/bin/bash

#This script takes bam files from HISAT (processed by SAMtools) and performs StringTie assembly and quantification and converts
# data into a format that is readable as count tables for DESeq2 usage

F=/home/kwong/Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis

# StringTie to assemble transcripts for each sample with the GFF3 annotation file
array1=($(ls $F/*.bam))

for i in ${array1[@]}; do
	stringtie -o ${i}.gtf -l $(echo ${i}|sed "s/\..*//") ${i}
	echo "${i}"
done
	# command structure: $ stringtie <options> -G <reference.gtf or .gff> -o outputname.gtf -l prefix_for_transcripts input_filename.bam
	# -o specifies the output name
	# -G specifies you are aligning with an option GFF or GTF file as well to perform novel transcript discovery
	# -l Sets <label> as the prefix for the name of the output transcripts. Default: STRG
	# don't use -e here if you want it to assemble any novel transcripts

#StringTie Merge, will merge all GFF files and assemble transcripts into a non-redundant set of transcripts, after which re-run StringTie with -e
#create mergelist.txt in nano, names of all the GTF files created in the last step with each on its own line
ls *.gtf > P_dam_mergelist.txt

#check to sure one file per line
cat P_dam_mergelist.txt

#Run StringTie merge, merge transcripts from all samples (across all experiments, not just for a single experiment)

stringtie --merge -o $F/P_dam_stringtie_merged.gtf $F/P_dam_mergelist.txt
#-A here creates a gene table output with genomic locations and compiled information that I will need later to fetch gene sequences (need annotation file)
#FROM MANUAL: "If StringTie is run with the -A <gene_abund.tab> option, it returns a file containing gene abundances. "
#-G is a flag saying to use the .gff annotation file

#Re-estimate transcript abundance after merge step
	for i in ${array1[@]}; do
		stringtie -e -G $F/P_dam_stringtie_merged.gtf -o $(echo ${i}|sed "s/\..*//").merge.gtf ${i}
		echo "${i}"
	done
	# input here is the original set of alignment files
	# here -G refers to the merged GTF files
	# -e creates more accurate abundance estimations with input transcripts, needed when converting to DESeq2 tables

echo "DONE" $(date)
```

`bash stringtie-2.sh`

### Prepare StringTie output for DESeq2

`wget https://ccb.jhu.edu/software/stringtie/dl/prepDE.py`  
`conda install python=2.7`

`nano prepDESeq2-2.sh`

```
#!/bin/bash

F=/home/kwong/Final_Project/raw/allraw/fullreads/cleaned_reads/P.acuta_genome_analysis

array2=($(ls *R1_cleaned.merge.gtf))

for i in ${array2[@]}; do
	echo "$(echo ${i}|sed "s/\_R1_cleaned..*//") $F/${i}" >> $F/Pdam_sample_list.txt
done

python $F/prepDE.py -i $F/Pdam_sample_list.txt

echo "STOP" $(date)
```

`bash prepDESeq2-2.sh`
