#!/bin/bash
#SBATCH --job-name='GATK call variants C albicans'
#SBATCH --time=18:00:00
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=20
#SBATCH --mail-type=ALL
#SBATCH --mail-user=duncan.carrutherslay@mail.utoronto.ca
#SBATCH --output=./logs/gatk.out.log
#SBATCH --error=./logs/gatk.err.log


module load CCEnv
module load StdEnv/2020
module load gcc/9.3.0
module load picard/2.26.3
module load samtools/1.17
module load gatk/4.2.5.0
module load bwa/0.7.17
module load bcftools/1.11
module load htslib/1.11
module load java/1.8.0_192
module load fastp/0.23.4

HOSTS=$(scontrol show hostnames $SLURM_NODELIST | tr '\n' ,)
NCORES=4

unset JAVA_TOOL_OPTIONS
export JAVA_TOOL_OPTIONS="-Xms30g -Xmx30g"

mkdir gatk_out
mkdir gatk_out/unmapped
mkdir gatk_out/aligned
mkdir gatk_out/merged
mkdir gatk_out/markedDups
mkdir gatk_out/filtered_vcf
mkdir gatk_out/raw_vcf
mkdir gatk_out/BQSR
mkdir gatk_out/BQSR_vcf

echo $HOSTS

parallel --joblog slurm-$SLURM_JOBID.log -a Calb_remaining.txt --env PATH,EBVERSIONJAVA,EBROOTPICARD,HELLBENDER_TEST_PROJECT,HELLBENDER_JSON_SERVICE_ACCOUNT_KEY,LD_LIBRARY_PATH -S $HOSTS -j $NCORES --wd $PWD ~/Emily_candida/GATK_variantcalling.sh {}