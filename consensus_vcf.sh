#!/bin/bash

#bgzip, index and list filtered vcf files
parallel bgzip {} ::: gatk_out/filtered_vcf/*.vcf
parallel bcftools index {} ::: gatk_out/filtered_vcf/*.vcf.gz

#Concatenate SNP and INDEL files, index and make a list for merging
parallel -a Calb_input.txt bcftools concat -O z -o gatk_out/filtered_vcf/{}_concat.filter.vcf.gz -d all -a gatk_out/filtered_vcf/{}_SNP.filter.vcf.gz  gatk_out/filtered_vcf/{}_INDEL.filter.vcf.gz
parallel bcftools index {} ::: gatk_out/filtered_vcf/*.vcf.gz

ls gatk_out/filtered_vcf/*_concat.filter.vcf.gz > Calbicans_vcfs.txt

#merge files with bcftools only keeping PASS on filtering
bcftools merge -O z -o Calbicans_vcf.vcf.gz -f PASS -m all --threads 80 -l Calbicans_vcfs.txt

#Index vcf for gatk
gatk IndexFeatureFile -I Calbicans_vcf.vcf.gz

#make tsv table of variants
gatk VariantsToTable \
  -V Calbicans_vcf.vcf.gz \
  -F CHROM -F POS -F REF -GF GT \
  -O Calbicans_vt.tsv