#!/bin/bash
#SBATCH --job-name='GATK call variants C albicans'
#SBATCH --time=18:00:00
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=20
#SBATCH --mail-type=ALL
#SBATCH --mail-user=duncan.carrutherslay@mail.utoronto.ca
#SBATCH --output=./logs/mutect2.out.log
#SBATCH --error=./logs/mutect2.err.log

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

unset JAVA_TOOL_OPTIONS
export JAVA_TOOL_OPTIONS="-Xms30g -Xmx30g"

mkdir gatk_out/mutect2

parallel -j 4 -a comp_list.txt ~/Emily_candida/mutect2.sh {}
