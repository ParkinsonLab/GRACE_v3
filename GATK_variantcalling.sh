#!/bin/bash

sample=$1

echo "Starting run with $sample"

#fastp trimming
fastp \
		--in1 raw_fastq/${sample}_R1.fastq \
    --in2 raw_fastq/${sample}_R2.fastq \
    --out1 trim/${sample}_1.fastq \
    --out2 trim/${sample}_2.fastq \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --cut_mean_quality 20 \
    --cut_window_size 5 \
    --cut_front \
    --cut_tail \
    --correction \
    --thread 4 \
    --html report/html/${sample}.html \
    --json report/json/${sample}.json 

#fastq to SAM
java -jar $EBROOTPICARD/picard.jar FastqToSam \
			    -FASTQ trim/${sample}_1.fastq \
			    -FASTQ2 trim/${sample}_2.fastq \
			    -OUTPUT gatk_out/unmapped/${sample}.unmap.sam \
			    -READ_GROUP_NAME $sample \
			    -SAMPLE_NAME $sample \
			    -LIBRARY_NAME $sample \
			    -PLATFORM "illumina" \
			    -VERBOSITY 'ERROR' \
			    -SORT_ORDER "queryname"

#map to reference
bwa mem -t 4 reference/Calbicans_ref.fasta \
			trim/${sample}_1.fastq \
			trim/${sample}_2.fastq \
     -v 1 \
			-o gatk_out/aligned/${sample}.align.sam
#merge with unmapped
java -jar $EBROOTPICARD/picard.jar MergeBamAlignment \
			-ALIGNED gatk_out/aligned/${sample}.align.sam \
			-UNMAPPED gatk_out/unmapped/${sample}.unmap.sam \
			-O gatk_out/merged/${sample}.merged.bam \
			-R reference/Calbicans_ref.fasta

#De-duplicate  
gatk MarkDuplicatesSpark \
			-I gatk_out/merged/${sample}.merged.bam \
			-O gatk_out/markedDups/${sample}.mark.bam \
			--verbosity 'ERROR'  \
			--conf "spark.executor.cores=2" \
      --conf 'spark.executor.memory=4G' \
      --spark-runner LOCAL \
      --spark-master 'local[4]'

#Call initial variants
gatk HaplotypeCaller \
      -ploidy 1 \
      -R reference/Calbicans_ref.fasta \
      -I gatk_out/markedDups/${sample}.mark.bam \
      -O gatk_out/raw_vcf/${sample}.raw.vcf \
      --min-base-quality-score 20 \
      --minimum-mapping-quality 25

#Filter variants for BQSR
#Seperate SNPs and INDELs
gatk SelectVariants \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/raw_vcf/${sample}.raw.vcf \
      --select-type SNP \
      -O gatk_out/raw_vcf/${sample}_SNP.raw.vcf
gatk SelectVariants \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/raw_vcf/${sample}.raw.vcf \
      --select-type INDEL \
      -O gatk_out/raw_vcf/${sample}_INDEL.raw.vcf
      
#Initial filtering of called SNPs and INDELs
gatk VariantFiltration \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/raw_vcf/${sample}_SNP.raw.vcf \
      -O gatk_out/raw_vcf/${sample}_SNP.filter.vcf \
      -filter-name "QD_filter" -filter "QD < 2.0" \
      -filter-name "FS_filter" -filter "FS > 60.0" \
      -filter-name "MQ_filter" -filter "MQ < 40.0" \
      -filter-name "SOR_filter" -filter "SOR > 4.0" \
      -filter-name "MQRankSum_filter" -filter "MQRankSum < -12.5" \
      -filter-name "ReadPosRankSum_filter" -filter "ReadPosRankSum < -8.0"
gatk VariantFiltration \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/raw_vcf/${sample}_INDEL.raw.vcf \
      -O gatk_out/raw_vcf/${sample}_INDEL.filter.vcf \
      -filter-name "QD_filter" -filter "QD < 2.0" \
      -filter-name "FS_filter" -filter "FS > 200.0" \
      -filter-name "SOR_filter" -filter "SOR > 10.0"

#Apply BQSR
#remove filtered variants from files
gatk SelectVariants \
      --exclude-filtered \
      -V gatk_out/raw_vcf/${sample}_SNP.filter.vcf \
      -O gatk_out/BQSR/${sample}_SNP.filter.vcf
gatk SelectVariants \
      --exclude-filtered \
      -V gatk_out/raw_vcf/${sample}_INDEL.filter.vcf \
      -O gatk_out/BQSR/${sample}_INDEL.filter.vcf

#Create table for BQSR (BaseRecalibrator)
gatk BaseRecalibrator \
      -R reference/Calbicans_ref.fasta \
	    -I gatk_out/markedDups/${sample}.mark.bam \
      --known-sites gatk_out/BQSR/${sample}_SNP.filter.vcf \
      --known-sites gatk_out/BQSR/${sample}_INDEL.filter.vcf \
      -O gatk_out/BQSR/${sample}_recal_data.table
gatk ApplyBQSR \
      -R reference/Calbicans_ref.fasta \
      -I gatk_out/markedDups/${sample}.mark.bam \
      -bqsr gatk_out/BQSR/${sample}_recal_data.table \
      -O gatk_out/BQSR/${sample}.recal.bam

#Call SNPs and INDELs again with recalibrated BAM
gatk HaplotypeCaller \
      -ploidy 2 \
      -R reference/Calbicans_ref.fasta \
      -I gatk_out/BQSR/${sample}.recal.bam \
      -O gatk_out/BQSR_vcf/${sample}.raw.vcf \
      --min-base-quality-score 20 \
      --minimum-mapping-quality 25

#Filter variants
#Seperate SNPs and INDELs
gatk SelectVariants \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/BQSR_vcf/${sample}.raw.vcf \
      --select-type SNP \
      -O gatk_out/BQSR_vcf/${sample}_SNP.raw.vcf
gatk SelectVariants \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/BQSR_vcf/${sample}.raw.vcf \
      --select-type INDEL \
      -O gatk_out/BQSR_vcf/${sample}_INDEL.raw.vcf
      
#Filtering of called SNPs and INDELs
gatk VariantFiltration \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/BQSR_vcf/${sample}_SNP.raw.vcf \
      -O gatk_out/filtered_vcf/${sample}_SNP.filter.vcf \
      -filter-name "QD_filter" -filter "QD < 2.0" \
      -filter-name "FS_filter" -filter "FS > 60.0" \
      -filter-name "MQ_filter" -filter "MQ < 40.0" \
      -filter-name "SOR_filter" -filter "SOR > 4.0" \
      -filter-name "MQRankSum_filter" -filter "MQRankSum < -12.5" \
      -filter-name "ReadPosRankSum_filter" -filter "ReadPosRankSum < -8.0"
gatk VariantFiltration \
      -R reference/Calbicans_ref.fasta \
      -V gatk_out/BQSR_vcf/${sample}_INDEL.raw.vcf \
      -O gatk_out/filtered_vcf/${sample}_INDEL.filter.vcf \
      -filter-name "QD_filter" -filter "QD < 2.0" \
      -filter-name "FS_filter" -filter "FS > 200.0" \
      -filter-name "SOR_filter" -filter "SOR > 10.0"
  
#remove some temporary files
#rm -f gatk_out/unmapped/${sample}.unmap.sam
#rm -f gatk_out/aligned/${sample}.align.sam
#rm -f gatk_out/merged/${sample}.merged.bam
#rm -f gatk_out/raw_vcf/${sample}.*

echo "Finished processing $sample" 