#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 1_step_SAMPLE.sh 

#Number of desired cpus: 
#SBATCH --ntasks=1

# Amount of RAM needed for this job: 
#SBATCH --mem=1gb
 
#The time the job will be running: SBATCH 
#--time=10:00

# To use GPUs you have to request them:
##SBATCH --gres=gpu:1

# If you need nodes with special features uncomment the desired constraint line: 
#SBATCH --constraint=cal

# Set output and error files 
#SBATCH --error=job.step1.SAMPLE.%J.err 
#SBATCH --output=job.step1.SAMPLE.%J.out
#CHECK ls TEMPORAL_DIR/SAMPLE_st/output_files/*.fastq* 
#CHECK grep "exit 0" job.step1.SAMPLE.*.out

let j=$RANDOM%200
#echo sleeping for $j seconds
sleep $j
echo SAMPLE 
date 
echo I´ve sleeped for $j seconds 
echo exit 0
echo `date` init $0 >> $LOG
