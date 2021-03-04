library(tidyverse)

args <- commandArgs(T)

file_rpkm = args[1]
file_deseq = args[2]
filesample = args[3]
filecondition = args[4]
filepair =  args[5]
fileout =  args[6]

#file_rpkm <- "RNA/gene.rpkm.txt"
#file_deseq <- "RNA/deseq2.results.txt"
#filecondition <- "config/condition.txt"
#filepair <- "config/condition_pair.txt"
#fileout <- "RNA/deseq2.rpkm.txt"

rpkm <- read_tsv(file_rpkm)
deseq_results <- read_tsv(file_deseq)
data <- inner_join(rpkm, deseq_results, by="id")

condition_data = read_tsv(filesample)
condition_data$group[is.na(condition_data$group)] <- ""

conditions = unique(read_tsv(filecondition, col_names="group")$group)
conditions = conditions[conditions != ""]

for (condition in conditions){
  data[condition] = rowMeans(data[condition_data$sample[condition_data$group==condition]])
}


pair_conditions = read_tsv(filepair, col_names=FALSE)
if (ncol(pair_conditions) == 3) {
  pair_conditions = pair_conditions[pair_conditions[,3] ==1, ]
}
pair_conditions = t(pair_conditions[, 1:2])

pair_conditions

for (i in 1:ncol(pair_conditions)){
  cond1 = pair_conditions[1,i]
  cond2 = pair_conditions[2,i]
  log_column_name = paste("log2_",cond1, "_VS_", cond2,sep="")
  data[log_column_name] = log2(data[,cond1]+1) - log2(data[,cond2]+1)
}

for (i in 1:ncol(pair_conditions)){
  cond1 = pair_conditions[1,i]
  cond2 = pair_conditions[2,i]
  deseq_column_name = paste(cond1, "_VS_", cond2,"_padj", sep="")
  log_column_name = paste("log2_",cond1, "_VS_", cond2,sep="")
  diff_column_name = paste(cond1, "_VS_", cond2, "_flag", sep="")
  value = rep(0, nrow(data))
  diff_flag = data[,deseq_column_name]<=0.05
  value[diff_flag & data[,log_column_name] >= 1 ] <- 1
  value[diff_flag & data[,log_column_name] <= -1 ] <- 2
  data[diff_column_name] = value
}

write_tsv(data, fileout)
