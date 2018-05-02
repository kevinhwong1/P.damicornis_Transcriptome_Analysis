#call the DESeq2 library 
source("http://bioconductor.org/biocLite.R")
biocLite("BiocUpgrade") 
biocLite("DESeq2")
library("DESeq2")
install.packages("fdrtool")
library(fdrtool)
source("https://bioconductor.org/biocLite.R")
install.packages("dplyr")
library(dplyr)
install.packages("tidyr")
library(tidyr)
install.packages("reshape2")
library(reshape2)
library(ggplot2)
install.packages("tm")
library(tm)
library(genefilter)

#Read in stringtie merged file
Pdam_stringtie <- read.csv(file= "../P_dam_stringtie_merged.gtf", sep="\t", header = FALSE)

#set colnames for the attributes
colnames(Pdam_stringtie) <- c('seqname', 'source', 'feature','start','end','score','strand','frame', 'attribute')

#subset for just transcript lines
Pdam_stringtie_transcripts <- Pdam_stringtie %>% filter(feature =="transcript")


####DEG Analysis with TRANSCRIPT Count Matrix ####
#load transcript count matrix and labels
#Pdam_2011_sample_info.csv file contains metadata on the count table's samples
###Make sure excel sample info is in the same order or these commands will change data to be wrong!!!!###

#Extract correct rows and columns from the PHENO DATA and transcript data
Pdam_TranscriptCountData <- as.data.frame(read.csv("../transcript_count_matrix.csv", row.names="transcript_id"))
head(Pdam_TranscriptCountData)

#filtering values for PoverA
filt <- filterfun(pOverA(0.25,5)) #set filter values for PoverA, P percent of the samples have counts over A
tfil <- genefilter(Pdam_TranscriptCountData, filt) #create filter for the counts data
keep <- Pdam_TranscriptCountData[tfil,] #identify transcripts to keep by count filter
gn.keep <- rownames(keep) #identify transcript list
counts.5x <- as.matrix(Pdam_TranscriptCountData[which(rownames(Pdam_TranscriptCountData) %in% gn.keep),]) #data filtered in PoverA, P percent of the samples have counts over A
write.csv(counts.5x, file="filtered_counts.csv")

head(counts.5x)

#load Phenotype data with addded column for extra control
#upload pheno data in the correct order with the controls of A and B listed first
#then change the order of the TranscriptCountData to match this order 
Pdam_sample_ColData <- read.csv("Pdam_2011_sample_info.csv", header=TRUE, sep=",")
print(Pdam_sample_ColData)

#change rownames to match
rownames(Pdam_sample_ColData) <- Pdam_sample_ColData$Sample.ID
colnames(counts.5x) <- Pdam_sample_ColData$Sample.ID
head(Pdam_sample_ColData)
head(counts.5x)

# Check all sample IDs in Pdam_sample_ColData are also in Pdam_TranscriptCountData and match their orders
all(rownames(Pdam_sample_ColData) %in% colnames(counts.5x))  #Should return TRUE
# returns TRUE
all(rownames(Pdam_sample_ColData) == colnames(counts.5x))    # should return TRUE
#returns TRUE

###relevelling variables
#Give the released column levels
Pdam_sample_ColData$Released <- factor(Pdam_sample_ColData$Released)
levels(Pdam_sample_ColData$Released) #check to see that it has levels 

#give the treatment column levels
Pdam_sample_ColData$Treatment <- factor(Pdam_sample_ColData$Treatment)
levels(Pdam_sample_ColData$Treatment)

###construct DESeq dataset from matrix
# DESeqDataSet from count matrix and labels, separate into resistant and susceptible 
#add an interaction term to compare treatment between two conditions 
#layout used for interactions: https://support.bioconductor.org/p/58162/

ddsS4 <- DESeqDataSetFromMatrix(countData = counts.5x, 
                                colData = Pdam_sample_ColData, 
                                design =  ~ Released + Treatment + Released:Treatment)

ddsS4<- ddsS4[ rowSums(counts(ddsS4)) > 1, ]

# review how the data set looks
head(ddsS4)

#Relevel each to make sure that control is the first level in the treatment factor for each
ddsS4$Released <- relevel(ddsS4$Released, "Yes")

#Check we're looking at the right samples
as.data.frame( colData(ddsS4) )

###Differential Gene Expression Analysis
#Running the DEG pipeline
ddsddsS4<- DESeq(ddsS4, betaPrior = FALSE) #for designs with interactions, recommends setting betaPrior=FALSE

#Inspect results
#extract contrasts between control and treatment values for interaction
resS4<- results(ddsddsS4)
head(resS4)

###Preliminary Analysis and Exploring Results
#summary is just printing a table for you, you need to tell it what threshold you want
help("summary",package="DESeq2")
alpha <- 0.05 #set alpha to 0.05, this will control FDR
summary(resS4) #default FDR is still 0.1
summary(resS4, alpha) #no showing all genes with FRD < 0.05

#To get the significant genes
#The independent filtering in results() has an argument 'alpha'
#which is used to optimize a cutoff on mean normalized count
#to maximize the number of genes with padj < alpha
resS4_05 <- results(ddsddsS4, alpha= alpha) #set FDR to 0.05 now
resS4_05_Sig <- ddsddsS4[which(ddsddsS4$padj < alpha),]
summary(resS4_05) #this is all the genes
summary(resS4_05_Sig) #this is the significant ones!

sum(resRODTran_05$padj < 0.05, na.rm=TRUE) #4121 tells you how many genes have expected FDR ≤ 0.05
sum(resS4_05_Sig$padj < 0.05, na.rm=TRUE) #4102, differ by 19 genes only 
sig="significant"
resS4_05_Sig$Significance <- sig
resS4_05_nonSig <- resS4[which(resS4$padj > alpha),] #create list of nonsig
nonsig <- "non-significant"
