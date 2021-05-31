#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 6_step_last_SAMPLE.sh 

#Number of desired cpus: 
#SBATCH --ntasks=1


# Amount of RAM needed for this job: 
#SBATCH --mem=1gb 

#The time the job will be running: SBATCH 
#--time=10:00

# To use GPUs you have to request them:
#SBATCH --cpus-per-task=52


# If you need nodes with special features uncomment the desired constraint line: 
#SBATCH --constraint=sd

# Set output and error files 
#SBATCH --error=job.step6.SAMPLE.%J.err 
#SBATCH --output=job.step6.SAMPLE.%J.out
 
#CHECK grep "6exit 0" job.step6.SAMPLE.*.out

echo `date` init $0 >> $LOG 
echo SAMPLE 
let j=$RANDOM%100 
echo sleeping for $j seconds 
echo SAMPLE
date 
echo 6exit 0 
echo `date` init $0 >> $LOG
