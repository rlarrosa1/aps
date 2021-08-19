#!/usr/bin/env bash
# The name to show in queue lists for this job: 
#SBATCH -J 3_unify_step.sh 

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
#SBATCH --error=job.unify.step3.%J.err 
#SBATCH --output=job.unify.step3.%J.out
 
#CHECK grep "exit 0" job*step3*.out

let sum=0 
let total=0 
for i in ../* ; do
  if test -s $i/job*step2*out ; then
    ele=`basename $i`
    let sum=$sum+`head -1 $i/job*step2*out`
    let total=${total}+${ele}
  fi 
done 
echo sum: $sum 
let j=$RANDOM%100 
echo sleeping for $j seconds 
sleep $j 
date 
if test $sum -eq $total ; 
then
  echo exit 0 
else
  echo exit 1 error sum : $sum and total : $total 
fi 
echo `date` init $0 >> $LOG
