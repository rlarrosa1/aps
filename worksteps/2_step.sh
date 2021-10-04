#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 2_step_SAMPLE.sh 

#Number of desired cpus: 
#SBATCH --ntasks=1

# Amount of RAM needed for this job: 
#SBATCH --mem=1gb 

#The time the job will be running: 
#SBATCH --time=10:00

# To use GPUs you have to request them:
#SBATCH --cpus-per-task=52

# If you need nodes with special features uncomment the desired constraint line: 
#SBATCH --constraint=sd
# Set output and error files 
#SBATCH --error=job.step2.SAMPLE.%J.err 
#SBATCH --output=job.step2.SAMPLE.%J.out
 
#CHECK grep "exit 0" job.step2.SAMPLE.*.out

let j=$RANDOM%200 
sleep $j 
echo SAMPLE 
 
one=`awk '{print $1}' ../samples_to_process.lis | tail -1` 
two=$(( $one + 2 )) 
three=$(( $two + 2 ))

echo $one+$two+$three 
date 
echo sleeping for $j seconds 
echo exit 0 
echo `date` init $0 >> $LOG
