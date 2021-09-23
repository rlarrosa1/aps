#!/usr/bin/env bash

# This script will create a directory per sample in addition to other directories for unification phase.
# Inside of that directories we will find other scripts needed for the program created by the templates
# specified by the user in JOB_SOURCE enviroment variable.


# Definition of LOG variables
export DIRS=`echo "${BASH_SOURCE%/*}/"`
export LOG=$PWD/works.log
export LOGERR=$PWD/works_trace.err

echo `date` to create files in `pwd` >> $LOG

# The next function is used to show a menu of the different options to the user in case it is needed

function show_help
{
        echo "-s script         Only copy given script, it can contain wildchars."
        echo "-d directory      Only create files in given directory."
        echo "-i outfile        Writes in outfile info from the output of the scripts, using job.info to extract it."
}

# Initializing some variables

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh*"
export INFO=false
export VERBOSE=false
export MEASURE=false
export NUM_CPU=0
export NUM_TASK=0
export NUM_MEM=0

# This loop will read the input parameters in the screen and it will perform the right acction depending on the parameters

while getopts "h?vd:s:i:oc:t:m:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    v)  VERBOSE=true
        ;;
    d)  l1=$OPTARG
        unset l2
        ;;
    o)  MEASURE=true
        ;;
    s)  FILTER_SCRIPTS=$OPTARG
        ;;
    c)  NUM_CPU=$OPTARG
        ;;
    t)  NUM_TASK=$OPTARG
        ;;
    m)  NUM_MEM=$OPTARG
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# With the next command, helper.hs is executed and all the validations, fuctions and other features allocated in that script
# will be executed

. ${DIRS}/helper.sh

# Checking the enviroment variable $EXPERIMENT and if it is properly populated. If not the flow will end.

if ! grep -w "${EXPERIMENT}" ini*.sh |grep " EXPERIMENT=" ; then
	echo ERROR : current dir does not contain an init file for experiment ${EXPERIMENT}
	exit 2
fi

# aps_flow_check.sh is other script which will do some validations and, in case of error, a message will appear in the terminal with
# the details and the process will end.

if ! aps_flow_check.sh ; then 
  echo Please, correct the errors before creating the flow files.
  exit 1
fi

# If optimization option has been selected it is needed to validate the input parameters

if [ $MEASURE == "true" ] && [[ $NUM_CPU -eq 0 && $NUM_TASK -eq 0 && $NUM_MEM -eq 0 ]] ; then
  echo Please, if you are going to use optimization option ensure that the parameters are correct.
  exit 1
fi

let npac=1

pushd .

# The next loop checks the number of colums in our input data file

let index=1
for i in `head -1 $INPUTFILE` ; do 
  arr[${index}]=$i
  let index=${index}+1
done

# In the next variable will save the list of template scripts allocated in the variable $JOB_SOURCE

script_list=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|sort -n`

PROCESS_LINE_JOBS=`echo $script_list|grep $PROCESS_LINE`

# The next loop will create the jobs, folders and necesary files to execute the experiment

for job in $script_list ; do
  # checks if this script process all the line at the same time
  if echo $job| grep $PROCESS_LINE > /dev/null ; then
    if ! [ $MEASURE == "true" ] ; then
    cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | while read i2 ; do 
     let index=1
     for sam in `echo $i2|tr "·" " "` ; do
      sample[${index}]=$sam
      let index=${index}+1
     done
     export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
     export i=`echo ${tmp}_${PROCESS_LINE}`
     pushd . > /dev/null
     mkdir $i > /dev/null 2> /dev/null
     cd $i
     export order="-"
     export suborder="-"
     export DEPEND=""
     export act_order=`echo $job|tr "_" " "|awk '{print $1}'`
     export act_suborder=`echo $job|tr "_" " "|awk '{print $2}'`
     cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g |sed s#DATA_ORIGIN#${DATA_ORIGIN}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
      # changes the strings that are the names of the columns of the input file for their samples
     for idx in `seq 1 ${#arr[@]}` ; do
      sed -i s#${arr[${idx}]}#${sample[${idx}]}#g ${job}
     done
     echo `date` multisample job file for $job in $i created >> $LOG
     echo `date` multisample job file for $job in $i created 
     chmod +x ${job}
     let npac=${npac}+1
     popd > /dev/null
    done
    fi
  # checks if this script process all the data at the same time, so it needs the output of all previous jobs
  elif echo $job| grep $SYNC_JOB > /dev/null ; then
    if ! [ $MEASURE == "true" ] ; then
    pushd . > /dev/null
    i=`echo $job|sed s/.sh//`
    mkdir $i > /dev/null 2> /dev/null
    cd $i
    cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g |sed s#DATA_ORIGIN#${DATA_ORIGIN}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
    echo `date` sync job file for $job in $i created >> $LOG
    echo `date` sync job file for $job in $i created 
    chmod +x ${job}
    let npac=${npac}+1
    popd > /dev/null
    if echo $script_list | grep PROCESS_LINE; then
     while read i2 ; do
      export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
      export i=`echo ${tmp}_${PROCESS_LINE}`
      export l2=`echo $l2 $i`
     done < <(cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"|grep - )
    else
     unset l2
    fi
    for i in `cat $INPUTFILE|tr -s "\t" " "|sed 's/[ \t]*$//'|tail -n +2` $l2 ; do
      pushd . > /dev/null
      mkdir $i > /dev/null 2> /dev/null
      cd $i
      echo "job sync is needed at this point" > ${job}
      echo " SBATCH needed for detecting it is an script " >> ${job}
      grep CHECK ${REAL_JOB_SOURCE}/$job >> ${job}
      popd > /dev/null
    done
    fi
   else
    count=1
    task_counter=1
    break_task=false
    break_cpu=false
    for i in `cat $INPUTFILE|tr -s "\t" " "|sed 's/[ \t]*$//'|tail -n +2` ; do
      if [ $MEASURE == "true" ] ; then
       if [ -z `echo $NUM_CPU | grep ","` ] ; then
         NUM_CPU+=","
       fi
       if [ -z `echo $NUM_TASK | grep ","` ] ; then
         NUM_TASK+=","
       fi     

       cpu_option=`echo $NUM_CPU | cut -d ',' -f $count`
       task_option=`echo $NUM_TASK | cut -d ',' -f $task_counter`      

       if [ $MEASURE == "true" ] && ! [ -z $cpu_option ]; then                  
        (( count++ ))  
       else
        break_cpu=true      
       fi

       if [ $MEASURE == "true" ] && ! [ -z $task_option ]; then                  
        (( task_counter++ ))
       else
        break_task=true
       fi
      
       if [ $break_task == "true" ] && [ $break_cpu == "true" ] ; then
        break
       fi
      fi 
      pushd . > /dev/null
      mkdir $i > /dev/null 2> /dev/null
      cd $i
      export order="-"
      export suborder="-"
      export DEPEND=""
      export act_order=`echo $job|tr "_" " "|awk '{print $1}'`
      export act_suborder=`echo $job|tr "_" " "|awk '{print $2}'`                
      cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g | sed s#DATA_ORIGIN#${DATA_ORIGIN}#g | sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}                  
      if [ $MEASURE == "true" ] && ! [ -z $cpu_option ] && ! [ $cpu_option -eq 0 ]; then sed -i 's/.*--cpus-per-task.*/#SBATCH --cpus-per-task='$cpu_option'/' $job; fi
      if [ $MEASURE == "true" ] && [ $NUM_MEM != 0 ] ; then sed -i 's/.*--mem.*/#SBATCH --mem='$NUM_MEM'/' $job; fi
      if [ $MEASURE == "true" ] && ! [ -z $task_option ] && ! [ $task_option -eq 0 ]; then sed -i 's/.*--ntasks.*/#SBATCH --ntasks='$task_option'/' $job; fi      
      for idx in `seq 1 ${#arr[@]}` ; do
        sed -i s#${arr[${idx}]}#${sample[${idx}]}#g ${job}
      done
      echo `date` file for $job in $i created >> $LOG
      echo `date` file for $job in $i created       
      chmod +x ${job}
      let npac=${npac}+1
      popd > /dev/null
    done
  fi
done

popd
echo `date` $npac files created >> $LOG
