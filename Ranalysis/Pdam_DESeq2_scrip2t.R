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
install.packages("pheatmap")
library(pheatmap)
install.packages("RColorBrewer")
library(RColorBrewer)
library(limma)
library(spdep) 
library(adegenet)
biocLite("GSEABase")
library(GSEABase)
biocLite("pathview")
library("pathview")
biocLite("goseq")
library("goseq")
library("GO.db")
library("UpSetR")
library("reshape2")
library(lattice)
library(latticeExtra)

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
#Pdam_sample_ColData$Released <- factor(Pdam_sample_ColData$Released)
#levels(Pdam_sample_ColData$Released) #check to see that it has levels 

#give the treatment column levels
Pdam_sample_ColData$Treatment <- factor(Pdam_sample_ColData$Treatment)
levels(Pdam_sample_ColData$Treatment)

###construct DESeq dataset from matrix
# DESeqDataSet from count matrix and labels, separate into resistant and susceptible 
#add an interaction term to compare treatment between two conditions 
#layout used for interactions: https://support.bioconductor.org/p/58162/

ddsS4 <- DESeqDataSetFromMatrix(countData = counts.5x, 
                                colData = Pdam_sample_ColData, 
                                design =  ~ Treatment)

# Expression Visualization
rld <- rlog(ddsS4, blind=FALSE) #apply a regularized log transformation to minimize effects of small counts and normalize wrt library size
head(assay(rld), 3) #view data
sampleDists <- dist(t(assay(rld))) #calculate distance matix
sampleDistMatrix <- as.matrix(sampleDists) #distance matrix
rownames(sampleDistMatrix) <- colnames(rld) #assign row names
colnames(sampleDistMatrix) <- NULL #assign col names
colors <- colorRampPalette( rev(brewer.pal(9, "Blues")) )(255) #assign colors
pheatmap(sampleDistMatrix, #plot matrix of expression similarity
         clustering_distance_rows=sampleDists, #cluster rows
         clustering_distance_cols=sampleDists, #cluster columns
         col=colors) #set colors

plotPCA(rld, intgroup = c("Treatment")) #plot PCA of samples with all data

# Differential Gene Expression Analysis
#Interaction Test: test of the factor of "group" with all combinations of the original factors as groups
DEG.int <- DESeq(ddsS4) #run differential expression test by group using the wald test 
DEG.int.res <- results(DEG.int) #save DE results
resultsNames(DEG.int) #view DE results
sig.num <- sum(DEG.int.res$padj <0.05, na.rm=T) #identify the number of significant p values with 5%FDR (padj<0.05)
sig <- subset(DEG.int.res, padj<0.05,) #identify signficant pvalues with 5%FDR
sig.list <- ddsS4[which(rownames(ddsS4) %in% rownames(sig)),] #subset list of sig transcripts from original count data
rsig <- rlog(sig.list, blind=FALSE) #apply a regularized log transformation to minimize effects of small counts and normalize wrt library size
write.csv(counts(sig.list), file="DEG_5FDR.all.csv")

head(sig.list)

##### View DEG Data Heatmap and PCA #####
PCA.plot <- plotPCA(rsig, intgroup = c("Treatment")) #Plot PCA of all samples for DEG only
PCA.plot #view plot
PC.info <-PCA.plot$data #extract plotting data
pdf(file="PCA.DEG.pdf")
plot(PC.info$PC1, PC.info$PC2, xlim=c(-30,30), ylim=c(-16, 10), xlab="PC1 86%", ylab="PC2 5%", col = c("lightpink2", "steelblue1","yellow3")[as.numeric(PC.info$Treatment)], pch=c(16, 17)[as.numeric(PC.info$Released)], cex=1.3)
legend(x="top", 
       bty="n",
       legend = c("Ambient", "High", "No Release", "Released"),
       text.col = c("lightpink2","steelblue1","yellow3", "black", "black"),
       pch = c(15, 15, 16, 17),
       col = c("white","white", "black", "black"),
       cex=1)
#dev.off()

topVarGenes <- head(order(rowVars(assay(rsig)),decreasing=TRUE),sig.num) #sort by decreasing sig
mat <- assay(rsig)[ topVarGenes, ] #make an expression object
mat <- mat - rowMeans(mat) #difference in expression compared to average across all samples

df <- as.data.frame(colData(rsig)[c("Treatment")]) #make dataframe
df <- df[order(df$Treatment),]
df <- df[[1]]
#pdf(file="DEG_Heatmap.pdf")
pheatmap(mat, annotation_col = df, clustering_method = "average", 
         clustering_distance_rows="euclidean", show_rownames =FALSE, cluster_cols=TRUE,
         show_colnames =FALSE) #plot heatmap of all DEG by group
#dev.off()