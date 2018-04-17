# *P. damicornis* TGA transcriptome analysis
## Author: Kevin Wong
## Last updated: April 12, 2018

Data uploaded and analyzed on KITT (add in KITT description)

### Uploading raw data to KITT
```
scp -r -P 2292 /Volumes/NGS_DATA/Hawaii_Pdam/Pdam_Summer_2011/Pdam_2011_Raw/ kwong@kitt.uri.edu:/home/kwong/Final_Project/raw
```

### Uploading reference P.dam transcriptome to KITT
```
scp -P 2292 P_damicornis_transcriptome_Seneca2015.fasta kwong@kitt.uri.edu:Final_Project/raw
```

### Getting all files into one directory
```
cd raw
mkdir allraw
cd Pdam_2011_Raw/
grep -rl --null --include '*.fastq.gz' . | xargs -0r cp -t ../allraw
```

### Checking the files downloaded correctly (cksum)
```
scp -P 2292 Hawaii_Pacuta_checksum.md5 kwong@kitt.uri.edu:Final_Project/raw/allraw
md5sum *.fastq.gz > Hawaii_Pacuta_checksum2.md5
cksum Hawaii_Pacuta_checksum.md5 Hawaii_Pacuta_checksum2.md5
```

49167847 4879 Hawaii_Pacuta_checksum.md5
485158896 4880 Hawaii_Pacuta_checksum2.md5


### Concatenating extended files
```
e.g.
cat 1026_CGATGT_L003_R1_001.fastq.gz 1026_CGATGT_L003_R1_002.fastq.gz > 1026_CGATGT_L003_R1_003.fastq.gz` #combining files that were split during sequencing
```
`wc -l 1026_CGATGT_L003_R1_001.fastq.gz` #checking lengths of files to make sure they added correctly
**1830499** 1026_CGATGT_L003_R1_001.fastq.gz
`wc -l 1026_CGATGT_L003_R1_002.fastq.gz`
**237763** 1026_CGATGT_L003_R1_002.fastq.gz
`1026_CGATGT_L003_R1_003.fastq.gz`
**2068262** 1026_CGATGT_L003_R1_003.fastq.gz  #it all adds up!

### Moving full reads to a different folder
```
mkdir fullreads
cp *3.fastq.gz fullreads/
cp 1030_ACAGTG_L003_R1_001.fastq.gz 1030_ACAGTG_L003_R2_001.fastq.gz 1032_GCCAAT_L003_R1_001.fastq.gz 1032_GCCAAT_L003_R2_001.fastq.gz 1034_CAGATC_L003_R1_001.fastq.gz 1034_CAGATC_L003_R2_001.fastq.gz 1042_ATGTCA_L003_R1_001.fastq.gz 1042_ATGTCA_L003_R2_001.fastq.gz 1044_CCGTCC_L003_R1_001.fastq.gz 1044_CCGTCC_L003_R2_001.fastq.gz H12_GTGAAA_L003_R1_001.fastq.gz H12_GTGAAA_L003_R2_001.fastq.gz H8_AGTTCC_L003_R1_001.fastq.gz H8_AGTTCC_L003_R2_001.fastq.gz fullreads/
```

### Quality control of raw sequencing reads (FASTQC)
```
mkdir fastqc_results
conda install -c bioconda fastqc
```
