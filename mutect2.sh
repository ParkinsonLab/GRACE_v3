#!/bin/bash

sample=$1

gatk Mutect2 -R reference/Calbicans_ref.fasta \
  -I gatk_out/markedDups/2_C610c_Null_S40_L008.mark.bam \
  -I gatk_out/markedDups/$sample.mark.bam \
  -normal 2_C610c_Null_S40_L008 \
  -O gatk_out/mutect2/2v$sample.vcf\
  --native-pair-hmm-threads 20

gatk FilterMutectCalls -R reference/Calbicans_ref.fasta \
  -V gatk_out/mutect2/2v$sample.vcf \
  -O gatk_out/mutect2/2v$sample.filter.vcf
