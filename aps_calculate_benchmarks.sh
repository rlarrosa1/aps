#!/bin/bash

mkdir -p $INPUTDIR/measurement

if [ -z "`find $INPUTDIR -maxdepth 2 -name "*.out" -print`" ] ; then
 echo No output files has been detected, please ensure that queue system has finished with the jobs ;
fi

for f in `find $INPUTDIR -maxdepth 2 -name "*.out" -print | awk -F 'job.' '{print $2}' | cut -d'.' -f -3` ; do
 jobid=`echo $f | cut -d'.' -f 3`
 seff $jobid > $INPUTDIR/measurement/$f.txt
done

echo Starting the analysis to get the best performance

declare -A steps_array=()

for item in `ls $INPUTDIR/measurement` ; do
 step=`echo $item | cut -d'.' -f 1`
 step+=".sh"
 sample=`echo $item | cut -d'.' -f 2`

 if ! [ -n "${steps_array[$step]}" ] ; then

 num_nodes=`grep "Nodes:" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}'`
 cores_per_node=`grep "Cores per node" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}'`
 mem=`grep "Memory Efficiency:" $INPUTDIR/measurement/$s | awk -F 'of ' '{print $2}' | cut -d'%' -f 1 | sed 's/\.\b.*\ \b//g' | tr [:upper:] [:lower:]`
 num_task=`grep "SBATCH --ntask" $INPUTDIR/$sample/$step | cut -d'=' -f 2`

 cpu_utilized=`grep "CPU Utilized" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}'`
 cpu_time=`date -d $cpu_utilized +%H%M%S`
 cpu_efficiency=`grep "CPU Efficiency" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}' | cut -d'%' -f 1`
 memory_utilized=`grep "Memory Utilized" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}' | cut -d' ' -f 1`
 memory_efficiency=`grep "Memory Efficiency" $INPUTDIR/measurement/$item | awk -F ': ' '{print $2}' | cut -d'%' -f 1`
  
  for s in `find $INPUTDIR/measurement -name "*$step*" -print | awk -F ''/measurement'.' '{print $2}'`; do
   if ! [ $s == $INPUTDIR/measurement/$item ] && ! [ -z "`grep "COMPLETED" $s`" ] ; then
   	current_sample=`echo $INPUTDIR/measurement/$s | cut -d'.' -f 2`
   	current_step=`echo $s | cut -d'.' -f 1`
   	current_step+=".sh"
   	possible_cpu_utilized=`grep "CPU Utilized:" $INPUTDIR/measurement/$s | awk -F ': ' '{print $2}' | cut -d'%' -f 1`
   	cpu_time_utilized=`date -d $possible_cpu_utilized +%H%M%S`
   	possible_memory_utilized=`grep "Memory Utilized:" $INPUTDIR/measurement/$s | awk -F ': ' '{print $2}' | cut -d' ' -f 1 | cut -d' ' -f 1`
   	possible_memory_efficiency=`grep "Memory Efficiency:" $INPUTDIR/measurement/$s | awk -F ': ' '{print $2}' | cut -d'%' -f 1`
   	possible_cpu_efficiency=`grep "CPU Efficiency:" $INPUTDIR/measurement/$s | awk -F ': ' '{print $2}' | cut -d'%' -f 1`

   	if [ 1 -eq "$(echo "${cpu_efficiency} < ${possible_cpu_efficiendcy}" | bc)" ] && [ 1 -eq "$(echo "${memory_efficiency} < ${possible_memory_efficiency}" | bc)" ] ; then   		
   		$cores_per_node=`grep "Cores per node" $s | awk -F ': ' '{print $2}'`
   		mem=`grep "Memory Efficiency:" $INPUTDIR/measurement/$s | awk -F 'of ' '{print $2}' | cut -d'%' -f 1 | sed 's/\.\b.*\ \b//g' | tr [:upper:] [:lower:]`
   		if ! [ $num_task -eq `grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2` ] ; then
   			num_task=`grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2`
   		fi   		   		
   	elif [ 1 -eq "$(echo "${possible_cpu_efficiency} < ${cpu_efficiendcy}" | bc)" ] && [ 1 -eq "$(echo "${cpu_time_utilized} < ${cpu_time}" | bc)" ] ; then
   		num_nodes=`grep "Nodes:" $INPUTDIR/measurement/$s | awk -F ': ' '{print $2}'` 	
   		if ! [ $num_task -eq `grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2` ] ; then
   			num_task=`grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2`
   		fi
   	elif [ 1 -eq "$(echo "${memory_efficiency} < ${possible_memory_efficiency}" | bc)" ] && [ 1 -eq "$(echo "${memory_utilized} < ${possible_memory_utilized}" | bc)" ] ; then
   		mem=`grep "Memory Efficiency:" $INPUTDIR/measurement/$s | awk -F 'of ' '{print $2}' | cut -d'%' -f 1 | sed 's/\.\b.*\ \b//g' | tr [:upper:] [:lower:]`
   		if ! [ $num_task -eq `grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2` ] ; then
   			num_task=`grep "SBATCH --ntask" $INPUTDIR/$current_sample/$current_step | cut -d'=' -f 2`
   		fi
   	fi
   fi
  done

  sed -i 's/.*--cpus-per-task.*/#SBATCH --cpus-per-task='$cores_per_node'/' $INPUTDIR/measurement/$item
  sed -i 's/.*--mem.*/#SBATCH --mem='$NUM_MEM'/' $INPUTDIR/measurement/$item
  echo $step has been updated with the best options to optimize the resources
  steps_array+=([$step]=1)

  fi
done