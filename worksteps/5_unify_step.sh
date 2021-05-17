#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 5_unify_step.sh 

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
#SBATCH --error=job.unify.step5.%J.err 
#SBATCH --output=job.unify.step5.%J.out
#CHECK ls TEMPORAL_DIR/SAMPLE_st/output_files/*.fastq* 
#CHECK grep "st5 exit 0" job.*step5.*.out
let sum=0 
for i in `ls -d ../*` ; do
  if test -s $i/job.step4*out ; then
    let ele=`grep sub $i/job.*step4*out|awk '{print $2}'`
    let sum=${sum}+${ele}
    echo sum $sum + $ele
  else
    echo ele in $i has no number : $ele
  fi 
done 
echo step 5 outcome : $sum 
let j=$RANDOM%100 
echo sleeping for $j seconds
echo SAMPLE 
date 
echo st5 exit 0 
echo `date` init $0 >> $LOG
