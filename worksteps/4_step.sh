#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 4_step_SAMPLE.sh 

#Number of desired cpus: 
#SBATCH --ntasks=1


#Amount of RAM needed for this job: 
#SBATCH --mem=1gb 

#The time the job will be running: 
#SBATCH --time=10:00

#To use GPUs you have to request them:
##SBATCH --gres=gpu:1


#If you need nodes with special features uncomment the desired constraint line: 
#SBATCH --constraint=cal


#Set output and error files 
#SBATCH --error=job.step4.SAMPLE.%J.err 
#SBATCH --output=job.step4.SAMPLE.%J.out
#CHECK ls TEMPORAL_DIR/SAMPLE_st/output_files/*.fastq* 
#CHECK grep "exit 0" job.step4.*.out


let j=$RANDOM%100 
echo sleeping for $j seconds 
sleep $j 
step3=`grep sum job*step3*out |awk '{print $2}'` 
echo step 4 for SAMPLE step 3 outcome: $step3 
sub=`echo SAMPLE-${step3}|bc -l` 
echo subtraction SAMPLE $sub 
date 
echo res 0 
#echo `date` init $0 >> $LOG
